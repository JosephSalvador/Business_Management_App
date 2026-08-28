using System.Security.Claims;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Users.Commands;
using BusinessOS.Application.Features.Users.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared;
using BusinessOS.Tests.Support;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Tests.Integration;

public sealed class UserManagementApplicationTests : IClassFixture<BusinessOsApiFactory>
{
    private readonly BusinessOsApiFactory _factory;

    public UserManagementApplicationTests(BusinessOsApiFactory factory) => _factory = factory;

    private sealed record SeededWorld(
        Guid TenantId,
        IReadOnlyList<Guid> BranchIds,
        IReadOnlyList<Guid> AdminUserIds,
        Guid AdminRoleId);

    private async Task<SeededWorld> SeedWorldAsync(string label, int adminCount = 1)
    {
        using var db = CreateDbContext();
        var tenantId = Guid.NewGuid();
        db.Tenants.Add(Tenant.Create(tenantId, $"{label} {Guid.NewGuid():N}"));

        var branch = Branch.Create(tenantId, "HQ", "HQ", "TZS");
        db.Branches.Add(branch);

        var adminRole = Role.Create(tenantId, SystemRoles.Administrator, isSystem: true);
        var permissions = await db.Permissions.ToListAsync();
        adminRole.Grant(permissions);
        db.Roles.Add(adminRole);

        var adminUserIds = new List<Guid>();
        for (var i = 0; i < adminCount; i++)
        {
            var email = $"{label}-admin-{i}-{Guid.NewGuid():N}@test.local";
            var admin = User.CreateManaged(Guid.NewGuid(), tenantId, email, "hash", $"Admin {i}", null);
            admin.AssignRole(adminRole);
            admin.AssignBranches(
                new[] { new UserBranchAssignment(branch.Id, IsDefault: true) },
                assignedBy: admin.Id,
                assignedAt: DateTime.UtcNow);
            db.Users.Add(admin);
            adminUserIds.Add(admin.Id);
        }

        await db.SaveChangesAsync();
        return new SeededWorld(tenantId, new[] { branch.Id }, adminUserIds, adminRole.Id);
    }

    private BusinessDbContext CreateDbContext()
        => new(new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options);

    private IServiceScope CreateAuthenticatedScope(Guid tenantId, Guid userId)
    {
        var scope = _factory.Services.CreateScope();
        var accessor = scope.ServiceProvider.GetRequiredService<IHttpContextAccessor>();
        accessor.HttpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                new[]
                {
                    new Claim("tenant_id", tenantId.ToString()),
                    new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
                },
                authenticationType: "TestAuth")),
        };
        var requestContext = scope.ServiceProvider.GetRequiredService<RequestContext>();
        requestContext.UserId = userId;
        requestContext.TenantId = tenantId;
        return scope;
    }

    [Fact]
    public async Task CreateUser_AssignsRolesAndBranches_HashesPassword_AndWritesOutbox()
    {
        var world = await SeedWorldAsync("create");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserIds[0]);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var email = $"new-{Guid.NewGuid():N}@test.local";
        var phone = TestPhones.Next();
        var result = await sender.Send(new CreateUserCommand(
            email,
            "Passw0rd!",
            "New User",
            Phone: phone,
            new[] { world.AdminRoleId },
            world.BranchIds,
            world.BranchIds[0]));

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(email, result.Value.Email);
        Assert.Equal("+" + phone, result.Value.Phone);
        Assert.Equal(new[] { world.AdminRoleId }, result.Value.RoleIds);
        Assert.Equal(world.BranchIds, result.Value.BranchIds);
        Assert.Equal(world.BranchIds[0], result.Value.DefaultBranchId);
        Assert.False(result.Value.EmailVerified);

        using var db = CreateDbContext();
        var persisted = await db.Users
            .Include(u => u.Roles)
            .Include(u => u.Branches)
            .SingleAsync(u => u.Id == result.Value.Id);
        Assert.NotEqual("Passw0rd!", persisted.PasswordHash);
        Assert.Equal(world.AdminRoleId, Assert.Single(persisted.Roles).Id);
        Assert.Equal(world.BranchIds[0], Assert.Single(persisted.Branches).BranchId);

        var recent = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Domain.Events.UserCreatedEvent")
            .OrderByDescending(o => o.OccurredAt)
            .Take(20)
            .ToListAsync();
        var outbox = recent.FirstOrDefault(o => o.Payload.Contains(persisted.Id.ToString()));
        Assert.NotNull(outbox);
        Assert.NotNull(outbox!.ProcessedAt);
    }

    [Fact]
    public async Task CreateUser_DuplicateEmail_ReturnsConflict()
    {
        var world = await SeedWorldAsync("dupe");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserIds[0]);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var email = $"dupe-{Guid.NewGuid():N}@test.local";
        var first = await sender.Send(new CreateUserCommand(
            email, "Passw0rd!", "First", null, new[] { world.AdminRoleId }, Array.Empty<Guid>(), null));
        Assert.True(first.IsSuccess);

        var second = await sender.Send(new CreateUserCommand(
            email, "Passw0rd!", "Second", null, new[] { world.AdminRoleId }, Array.Empty<Guid>(), null));
        Assert.True(second.IsFailure);
        Assert.Equal("Conflict", second.Error.Code);
    }

    [Fact]
    public async Task UpdateUser_ChangesProfile()
    {
        var world = await SeedWorldAsync("update");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserIds[0]);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        // Local Tanzanian form must be normalized to E.164 before storage.
        var localPhone = "0" + TestPhones.Next()[3..];
        var result = await sender.Send(new UpdateUserCommand(world.AdminUserIds[0], "Renamed User", localPhone));

        Assert.True(result.IsSuccess);
        Assert.Equal("Renamed User", result.Value.FullName);
        Assert.Equal("+255" + localPhone[1..], result.Value.Phone);
    }

    [Fact]
    public async Task ListAndGet_ReturnDtoWithRoleAndBranchIds()
    {
        var world = await SeedWorldAsync("listget");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserIds[0]);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var list = await sender.Send(new ListUsersQuery(Page: 1, PageSize: 10));
        Assert.True(list.IsSuccess);
        Assert.Equal(1, list.Value.Total);
        var listed = Assert.Single(list.Value.Items);
        Assert.Contains(world.AdminRoleId, listed.RoleIds);
        Assert.Contains(world.BranchIds[0], listed.BranchIds);

        var get = await sender.Send(new GetUserQuery(world.AdminUserIds[0]));
        Assert.True(get.IsSuccess);
        Assert.Equal(world.AdminUserIds[0], get.Value.Id);
        Assert.Equal(world.BranchIds[0], get.Value.DefaultBranchId);
    }

    [Fact]
    public async Task SetUserStatus_DeactivateSelf_ReturnsConflict()
    {
        var world = await SeedWorldAsync("self");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserIds[0]);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var result = await sender.Send(new SetUserStatusCommand(world.AdminUserIds[0], IsActive: false));

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task SetUserStatus_DeactivateLastActiveAdministrator_ReturnsConflict()
    {
        var world = await SeedWorldAsync("lastadmin");

        using (var db = CreateDbContext())
        {
            var managerRole = Role.Create(world.TenantId, "Manager");
            db.Roles.Add(managerRole);
            var manager = User.CreateManaged(
                Guid.NewGuid(), world.TenantId, $"manager-{Guid.NewGuid():N}@test.local", "hash", "Manager", null);
            manager.AssignRole(managerRole);
            db.Users.Add(manager);
            await db.SaveChangesAsync();
        }

        var managerId = await GetUserIdByEmailAsync($"manager");
        using var scope = CreateAuthenticatedScope(world.TenantId, managerId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var result = await sender.Send(new SetUserStatusCommand(world.AdminUserIds[0], IsActive: false));

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task Deactivate_KeepsRefreshTokensActive_DeleteRevokesThem()
    {
        var world = await SeedWorldAsync("lifecycle", adminCount: 3);
        var (admin0, admin1, admin2) = (world.AdminUserIds[0], world.AdminUserIds[1], world.AdminUserIds[2]);

        using (var db = CreateDbContext())
        {
            db.RefreshTokens.Add(RefreshToken.Create(admin1, world.TenantId, $"rt-{Guid.NewGuid():N}", DateTime.UtcNow.AddDays(30)));
            db.RefreshTokens.Add(RefreshToken.Create(admin2, world.TenantId, $"rt-{Guid.NewGuid():N}", DateTime.UtcNow.AddDays(30)));
            await db.SaveChangesAsync();
        }

        using var scope = CreateAuthenticatedScope(world.TenantId, admin0);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var deactivated = await sender.Send(new SetUserStatusCommand(admin1, IsActive: false));
        Assert.True(deactivated.IsSuccess, deactivated.Error.Message);
        Assert.False(deactivated.Value.IsActive);

        var deleted = await sender.Send(new DeleteUserCommand(admin2));
        Assert.True(deleted.IsSuccess, deleted.Error.Message);

        using var verifyDb = CreateDbContext();
        Assert.False((await verifyDb.Users.SingleAsync(u => u.Id == admin1)).IsActive);
        Assert.False((await verifyDb.Users.SingleAsync(u => u.Id == admin2)).IsActive);
        Assert.True(await verifyDb.RefreshTokens
            .Where(t => t.UserId == admin1)
            .AllAsync(t => t.RevokedAt == null));
        Assert.True(await verifyDb.RefreshTokens
            .Where(t => t.UserId == admin2)
            .AllAsync(t => t.RevokedAt != null));
    }

    [Fact]
    public async Task ConcurrentDeactivationOfTwoLastAdmins_ExactlyOneSucceeds()
    {
        var world = await SeedWorldAsync("race", adminCount: 2);
        var (adminA, adminB) = (world.AdminUserIds[0], world.AdminUserIds[1]);

        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        async Task<(bool IsSuccess, string? Code)> DeactivateAsync(Guid actorId, Guid targetId)
        {
            using var scope = CreateAuthenticatedScope(world.TenantId, actorId);
            var sender = scope.ServiceProvider.GetRequiredService<ISender>();
            await gate.Task;
            var result = await sender.Send(new SetUserStatusCommand(targetId, IsActive: false));
            return (result.IsSuccess, result.IsFailure ? result.Error.Code : null);
        }

        var taskA = Task.Run(() => DeactivateAsync(adminA, adminB));
        var taskB = Task.Run(() => DeactivateAsync(adminB, adminA));
        gate.SetResult();
        var results = await Task.WhenAll(taskA, taskB);

        var succeeded = results.Count(r => r.IsSuccess);
        var conflicted = results.Count(r => r.Code == "Conflict");
        Assert.Equal(1, succeeded);
        Assert.Equal(1, conflicted);

        using var db = CreateDbContext();
        var states = await db.Users
            .Where(u => u.Id == adminA || u.Id == adminB)
            .Select(u => new { u.Id, u.IsActive })
            .ToListAsync();
        Assert.Equal(1, states.Count(s => s.IsActive));
        Assert.Equal(1, states.Count(s => !s.IsActive));
    }

    [Fact]
    public async Task CrossTenant_GetAndDeactivate_ReturnNotFound()
    {
        var worldA = await SeedWorldAsync("iso-a");
        var worldB = await SeedWorldAsync("iso-b");
        using var scope = CreateAuthenticatedScope(worldB.TenantId, worldB.AdminUserIds[0]);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var get = await sender.Send(new GetUserQuery(worldA.AdminUserIds[0]));
        Assert.True(get.IsFailure);
        Assert.Equal("NotFound", get.Error.Code);

        var deactivate = await sender.Send(new SetUserStatusCommand(worldA.AdminUserIds[0], IsActive: false));
        Assert.True(deactivate.IsFailure);
        Assert.Equal("NotFound", deactivate.Error.Code);
    }

    [Fact]
    public async Task SetUserBranches_ReplaceAll_ClearsPriorAssignments()
    {
        var world = await SeedWorldAsync("branchreplace");
        var (tenantId, hq, targetId) = (world.TenantId, world.BranchIds[0], world.AdminUserIds[0]);

        Guid second;
        using (var db = CreateDbContext())
        {
            var branch = Branch.Create(tenantId, "Second", "SEC", "TZS");
            db.Branches.Add(branch);
            await db.SaveChangesAsync();
            second = branch.Id;
        }

        using var scope = CreateAuthenticatedScope(tenantId, targetId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var result = await sender.Send(new SetUserBranchesCommand(targetId, new[] { second }, second));

        Assert.True(result.IsSuccess, result.Error.Message);
        var dto = Assert.Single(result.Value);
        Assert.Equal(second, dto.BranchId);
        Assert.True(dto.IsDefault);

        using var verify = CreateDbContext();
        var persisted = await verify.Users
            .Include(u => u.Branches)
            .SingleAsync(u => u.Id == targetId);
        Assert.Single(persisted.Branches);
        Assert.Equal(second, Assert.Single(persisted.Branches).BranchId);
        Assert.Equal(second, persisted.DefaultBranchId);
        Assert.NotEqual(hq, persisted.DefaultBranchId);
    }

    [Fact]
    public async Task UserMutations_WriteAuditRows()
    {
        var world = await SeedWorldAsync("useraudit");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserIds[0]);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var email = $"audited-{Guid.NewGuid():N}@test.local";
        var created = await sender.Send(new CreateUserCommand(
            email, "Passw0rd!", "Audited", null,
            new[] { world.AdminRoleId }, world.BranchIds, world.BranchIds[0]));
        Assert.True(created.IsSuccess, created.Error.Message);
        var userId = created.Value.Id;

        Assert.True((await sender.Send(
            new UpdateUserCommand(userId, "Audited 2", TestPhones.Next()))).IsSuccess);
        Assert.True((await sender.Send(new SetUserRolesCommand(userId, Array.Empty<Guid>()))).IsSuccess);
        Assert.True((await sender.Send(new SetUserBranchesCommand(userId, world.BranchIds, world.BranchIds[0]))).IsSuccess);
        Assert.True((await sender.Send(new SetUserStatusCommand(userId, IsActive: false))).IsSuccess);
        Assert.True((await sender.Send(new DeleteUserCommand(userId))).IsSuccess);

        using var db = CreateDbContext();
        foreach (var action in new[]
                 {
                     "CreateUserCommand",
                     "UpdateUserCommand",
                     "SetUserRolesCommand",
                     "SetUserBranchesCommand",
                     "SetUserStatusCommand",
                     "DeleteUserCommand",
                 })
        {
            var log = await db.AuditLogs.FirstOrDefaultAsync(
                l => l.Action == action && l.TenantId == world.TenantId);
            Assert.NotNull(log);
            Assert.Equal(world.AdminUserIds[0], log!.UserId);
        }
    }

    private async Task<Guid> GetUserIdByEmailAsync(string prefix)
    {
        using var db = CreateDbContext();
        var user = await db.Users
            .Where(u => u.Email.StartsWith(prefix + "-"))
            .OrderByDescending(u => u.CreatedAt)
            .FirstAsync();
        return user.Id;
    }
}

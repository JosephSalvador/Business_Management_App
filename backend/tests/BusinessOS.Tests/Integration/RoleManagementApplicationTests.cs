using System.Security.Claims;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Roles.Commands;
using BusinessOS.Application.Features.Roles.Queries;
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

public sealed class RoleManagementApplicationTests : IClassFixture<BusinessOsApiFactory>
{
    private readonly BusinessOsApiFactory _factory;

    public RoleManagementApplicationTests(BusinessOsApiFactory factory) => _factory = factory;

    private sealed record SeededWorld(
        Guid TenantId,
        Guid AdminRoleId,
        Guid AdminUserId);

    private async Task<SeededWorld> SeedWorldAsync(string label)
    {
        using var db = CreateDbContext();
        var tenantId = Guid.NewGuid();
        db.Tenants.Add(Tenant.Create(tenantId, $"{label} {Guid.NewGuid():N}"));

        var adminRole = Role.Create(tenantId, SystemRoles.Administrator, isSystem: true);
        adminRole.Grant(await db.Permissions.ToListAsync());
        db.Roles.Add(adminRole);

        var admin = User.CreateManaged(
            Guid.NewGuid(), tenantId, $"admin-{label}-{Guid.NewGuid():N}@test.local", "hash", "Admin", null);
        admin.AssignRole(adminRole);
        db.Users.Add(admin);

        await db.SaveChangesAsync();
        return new SeededWorld(tenantId, adminRole.Id, admin.Id);
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
    public async Task CreateRole_Success_RoundTripsAndWritesOutbox()
    {
        var world = await SeedWorldAsync("create");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var result = await sender.Send(new CreateRoleCommand("Manager", "Manages staff"));

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(world.TenantId, result.Value.TenantId);
        Assert.False(result.Value.IsSystem);
        Assert.Equal("Manages staff", result.Value.Description);
        Assert.Empty(result.Value.PermissionNames);

        var list = await sender.Send(new ListRolesQuery());
        Assert.True(list.IsSuccess);
        Assert.Contains(list.Value, r => r.Id == result.Value.Id);

        var get = await sender.Send(new GetRoleQuery(result.Value.Id));
        Assert.True(get.IsSuccess);
        Assert.Equal(result.Value.Id, get.Value.Id);

        using var db = CreateDbContext();
        var recent = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Domain.Events.RoleCreatedEvent")
            .OrderByDescending(o => o.OccurredAt)
            .Take(20)
            .ToListAsync();
        var outbox = recent.FirstOrDefault(o => o.Payload.Contains(result.Value.Id.ToString()));
        Assert.NotNull(outbox);
        Assert.NotNull(outbox!.ProcessedAt);
    }

    [Fact]
    public async Task CreateRole_DuplicateName_ReturnsConflict()
    {
        var world = await SeedWorldAsync("dupe");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var first = await sender.Send(new CreateRoleCommand("Manager", null));
        Assert.True(first.IsSuccess);

        var second = await sender.Send(new CreateRoleCommand("Manager", null));
        Assert.True(second.IsFailure);
        Assert.Equal("Conflict", second.Error.Code);
    }

    [Fact]
    public async Task UpdateRole_SystemRole_ReturnsConflict()
    {
        var world = await SeedWorldAsync("sysupdate");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var result = await sender.Send(new UpdateRoleCommand(world.AdminRoleId, "Renamed", null));

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task UpdateRole_DuplicateName_ReturnsConflict()
    {
        var world = await SeedWorldAsync("renamedupe");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        await sender.Send(new CreateRoleCommand("Manager", null));
        var cashier = await sender.Send(new CreateRoleCommand("Cashier", null));
        Assert.True(cashier.IsSuccess);

        var result = await sender.Send(new UpdateRoleCommand(cashier.Value.Id, "Manager", null));

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task UpdateRole_Success_RenamesAndUpdatesDescription()
    {
        var world = await SeedWorldAsync("rename");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var created = await sender.Send(new CreateRoleCommand("Cashier", "Old"));
        Assert.True(created.IsSuccess);

        var result = await sender.Send(new UpdateRoleCommand(created.Value.Id, "Senior Cashier", "New description"));

        Assert.True(result.IsSuccess);
        Assert.Equal("Senior Cashier", result.Value.Name);
        Assert.Equal("New description", result.Value.Description);
    }

    [Fact]
    public async Task DeleteRole_SystemRole_ReturnsConflict()
    {
        var world = await SeedWorldAsync("sysdelete");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var result = await sender.Send(new DeleteRoleCommand(world.AdminRoleId));

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task DeleteRole_InUse_RemovesGrantsButKeepsUser()
    {
        var world = await SeedWorldAsync("deleteinuse");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var created = await sender.Send(new CreateRoleCommand("Manager", null));
        Assert.True(created.IsSuccess);

        var deleted = await sender.Send(new DeleteRoleCommand(created.Value.Id));
        Assert.True(deleted.IsSuccess);

        using var db = CreateDbContext();
        Assert.False(await db.Roles.AnyAsync(r => r.Id == created.Value.Id));
        Assert.True(await db.Users.AnyAsync(u => u.Id == world.AdminUserId));
    }

    [Fact]
    public async Task SetRolePermissions_UnknownPermission_ReturnsValidation()
    {
        var world = await SeedWorldAsync("badperm");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var created = await sender.Send(new CreateRoleCommand("Cashier", null));
        Assert.True(created.IsSuccess);

        var result = await sender.Send(new SetRolePermissionsCommand(
            created.Value.Id, new[] { "Users.View", "Bogus.View" }));

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task SetRolePermissions_RoundTrip_ReplacesAndWritesOutbox()
    {
        var world = await SeedWorldAsync("perms");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var created = await sender.Send(new CreateRoleCommand("Cashier", null));
        Assert.True(created.IsSuccess);

        var result = await sender.Send(new SetRolePermissionsCommand(
            created.Value.Id, new[] { "Sales.Create", "Users.View" }));
        Assert.True(result.IsSuccess);
        Assert.Equal(new[] { "Sales.Create", "Users.View" }, result.Value.PermissionNames);

        var getPermissions = await sender.Send(new GetRolePermissionsQuery(created.Value.Id));
        Assert.True(getPermissions.IsSuccess);
        Assert.Equal(new[] { "Sales.Create", "Users.View" }, getPermissions.Value);

        var replaced = await sender.Send(new SetRolePermissionsCommand(
            created.Value.Id, new[] { "Inventory.View" }));
        Assert.True(replaced.IsSuccess);
        Assert.Equal(new[] { "Inventory.View" }, replaced.Value.PermissionNames);

        using var db = CreateDbContext();
        var recent = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Domain.Events.RolePermissionsChangedEvent")
            .OrderByDescending(o => o.OccurredAt)
            .Take(20)
            .ToListAsync();
        var outbox = recent.FirstOrDefault(o => o.Payload.Contains(created.Value.Id.ToString()));
        Assert.NotNull(outbox);
        Assert.NotNull(outbox!.ProcessedAt);
    }

    [Fact]
    public async Task RoleMutations_WriteAuditRows()
    {
        var world = await SeedWorldAsync("roleaudit");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var created = await sender.Send(new CreateRoleCommand("Audited", "First"));
        Assert.True(created.IsSuccess, created.Error.Message);
        var roleId = created.Value.Id;

        Assert.True((await sender.Send(new UpdateRoleCommand(roleId, "Audited 2", "Second"))).IsSuccess);
        Assert.True((await sender.Send(new SetRolePermissionsCommand(roleId, new[] { "Users.View" }))).IsSuccess);
        Assert.True((await sender.Send(new DeleteRoleCommand(roleId))).IsSuccess);

        using var db = CreateDbContext();
        foreach (var action in new[]
                 {
                     "CreateRoleCommand",
                     "UpdateRoleCommand",
                     "SetRolePermissionsCommand",
                     "DeleteRoleCommand",
                 })
        {
            var log = await db.AuditLogs.FirstOrDefaultAsync(
                l => l.Action == action && l.TenantId == world.TenantId);
            Assert.NotNull(log);
            Assert.Equal(world.AdminUserId, log!.UserId);
        }
    }

    [Fact]
    public async Task GetPermissionsQuery_ReturnsSeededCatalog()
    {
        var world = await SeedWorldAsync("catalog");
        using var scope = CreateAuthenticatedScope(world.TenantId, world.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var result = await sender.Send(new GetPermissionsQuery());

        Assert.True(result.IsSuccess);
        Assert.Contains(result.Value, p => p.Name == "Users.View");
        Assert.Contains(result.Value, p => p.Name == "Roles.Manage");
    }

    [Fact]
    public async Task CrossTenant_GetAndUpdateAndDelete_ReturnNotFound()
    {
        var worldA = await SeedWorldAsync("iso-a");
        var worldB = await SeedWorldAsync("iso-b");
        using var scope = CreateAuthenticatedScope(worldB.TenantId, worldB.AdminUserId);
        var sender = scope.ServiceProvider.GetRequiredService<ISender>();

        var get = await sender.Send(new GetRoleQuery(worldA.AdminRoleId));
        Assert.True(get.IsFailure);
        Assert.Equal("NotFound", get.Error.Code);

        var update = await sender.Send(new UpdateRoleCommand(worldA.AdminRoleId, "Renamed", null));
        Assert.True(update.IsFailure);
        Assert.Equal("NotFound", update.Error.Code);

        var delete = await sender.Send(new DeleteRoleCommand(worldA.AdminRoleId));
        Assert.True(delete.IsFailure);
        Assert.Equal("NotFound", delete.Error.Code);
    }
}

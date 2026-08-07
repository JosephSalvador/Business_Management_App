using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Tests.Integration;

public sealed class IdentityRepositoryTests : IClassFixture<BusinessOsApiFactory>
{
    private readonly BusinessOsApiFactory _factory;

    public IdentityRepositoryTests(BusinessOsApiFactory factory) => _factory = factory;

    private sealed record SeededWorld(
        Guid TenantId,
        IReadOnlyList<Guid> BranchIds,
        Guid AdminUserId,
        Guid AdminRoleId,
        string AdminEmail);

    private async Task<SeededWorld> SeedWorldAsync(string label, int branchCount = 1)
    {
        using var db = CreateDbContext();
        var tenantId = Guid.NewGuid();
        db.Tenants.Add(Tenant.Create(tenantId, $"{label} {Guid.NewGuid():N}"));

        var branchIds = new List<Guid>();
        for (var i = 0; i < branchCount; i++)
        {
            var branch = Branch.Create(tenantId, $"Branch {i + 1}", $"B{i + 1:D2}", "TZS");
            db.Branches.Add(branch);
            branchIds.Add(branch.Id);
        }

        var adminRole = Role.Create(tenantId, SystemRoles.Administrator, isSystem: true);
        var permissions = await db.Permissions
            .Where(p => p.Name == PermissionNames.UsersView || p.Name == PermissionNames.SalesCreate)
            .ToListAsync();
        adminRole.Grant(permissions);
        db.Roles.Add(adminRole);

        var email = $"{label}-{Guid.NewGuid():N}@test.local";
        var admin = User.CreateManaged(Guid.NewGuid(), tenantId, email, "hash", "Test Admin", phone: null);
        admin.AssignRole(adminRole);
        admin.AssignBranches(
            new[] { new UserBranchAssignment(branchIds[0], IsDefault: true) },
            assignedBy: admin.Id,
            assignedAt: DateTime.UtcNow);
        db.Users.Add(admin);

        await db.SaveChangesAsync();
        return new SeededWorld(tenantId, branchIds, admin.Id, adminRole.Id, email);
    }

    private BusinessDbContext CreateDbContext()
        => new(new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options);

    [Fact]
    public async Task UserRepository_GetById_IsTenantScoped_AndLoadsRolesAndBranches()
    {
        var world = await SeedWorldAsync("getbyid");

        using var scope = _factory.Services.CreateScope();
        var users = scope.ServiceProvider.GetRequiredService<IUserRepository>();

        var found = await users.GetByIdAsync(world.TenantId, world.AdminUserId);
        Assert.NotNull(found);
        Assert.Equal(world.AdminRoleId, Assert.Single(found!.Roles).Id);
        Assert.Equal(world.BranchIds[0], Assert.Single(found.Branches).BranchId);
        Assert.Equal(world.BranchIds[0], found.DefaultBranchId);

        var foreign = await users.GetByIdAsync(Guid.NewGuid(), world.AdminUserId);
        Assert.Null(foreign);
    }

    [Fact]
    public async Task UserRepository_GetByIdWithRoles_IsTenantScoped_AndDoesNotLoadBranches()
    {
        var world = await SeedWorldAsync("rolesonly");

        using var scope = _factory.Services.CreateScope();
        var users = scope.ServiceProvider.GetRequiredService<IUserRepository>();

        var found = await users.GetByIdWithRolesAsync(world.TenantId, world.AdminUserId);
        Assert.NotNull(found);
        Assert.Equal(world.AdminRoleId, Assert.Single(found!.Roles).Id);
        Assert.Empty(found.Branches);

        var foreign = await users.GetByIdWithRolesAsync(Guid.NewGuid(), world.AdminUserId);
        Assert.Null(foreign);
    }

    [Fact]
    public async Task UserRepository_GetByEmail_FindsUserWithRoles()
    {
        var world = await SeedWorldAsync("byemail");

        using var scope = _factory.Services.CreateScope();
        var users = scope.ServiceProvider.GetRequiredService<IUserRepository>();

        var found = await users.GetByEmailAsync(world.AdminEmail);
        Assert.NotNull(found);
        Assert.Equal(world.TenantId, found!.TenantId);
        Assert.Equal(world.AdminRoleId, Assert.Single(found.Roles).Id);
    }

    [Fact]
    public async Task UserRepository_ListAndCount_AreTenantScoped_AndDeterministicallyPaged()
    {
        var world = await SeedWorldAsync("paging");

        using (var db = CreateDbContext())
        {
            var adminRole = await db.Roles.SingleAsync(r => r.Id == world.AdminRoleId);
            for (var i = 0; i < 2; i++)
            {
                var user = User.CreateManaged(
                    Guid.NewGuid(),
                    world.TenantId,
                    $"paging-extra-{i}-{Guid.NewGuid():N}@test.local",
                    "hash",
                    $"Extra {i}",
                    phone: null);
                user.AssignRole(adminRole);
                db.Users.Add(user);
            }

            var foreignTenant = Guid.NewGuid();
            db.Tenants.Add(Tenant.Create(foreignTenant, $"paging-other-{Guid.NewGuid():N}"));
            var foreignUser = User.CreateManaged(
                Guid.NewGuid(), foreignTenant, $"paging-foreign-{Guid.NewGuid():N}@test.local", "hash", "Foreign", null);
            db.Users.Add(foreignUser);
            await db.SaveChangesAsync();

            var expected = await db.Users
                .Where(u => u.TenantId == world.TenantId)
                .OrderBy(u => u.Email)
                .Select(u => u.Email)
                .ToListAsync();

            using var scope = _factory.Services.CreateScope();
            var users = scope.ServiceProvider.GetRequiredService<IUserRepository>();

            var page1 = await users.ListAsync(world.TenantId, page: 1, pageSize: 2);
            var page2 = await users.ListAsync(world.TenantId, page: 2, pageSize: 2);

            Assert.Equal(expected.Take(2), page1.Select(u => u.Email));
            Assert.Equal(expected.Skip(2), page2.Select(u => u.Email));
            Assert.Equal(expected.Count, await users.CountAsync(world.TenantId));
            Assert.Equal(1, await users.CountAsync(foreignTenant));
        }
    }

    [Fact]
    public async Task UserRepository_CountActiveAdministrators_CountsActiveSystemAdmins_ExcludingSelf()
    {
        var world = await SeedWorldAsync("countadmins");

        using (var db = CreateDbContext())
        {
            var adminRole = await db.Roles.SingleAsync(r => r.Id == world.AdminRoleId);

            var secondAdmin = User.CreateManaged(
                Guid.NewGuid(), world.TenantId, $"countadmins-2-{Guid.NewGuid():N}@test.local", "hash", "Admin Two", null);
            secondAdmin.AssignRole(adminRole);

            var deactivatedAdmin = User.CreateManaged(
                Guid.NewGuid(), world.TenantId, $"countadmins-3-{Guid.NewGuid():N}@test.local", "hash", "Admin Three", null);
            deactivatedAdmin.AssignRole(adminRole);
            deactivatedAdmin.Deactivate();

            var cashierRole = Role.Create(world.TenantId, "Cashier");
            db.Roles.Add(cashierRole);
            var cashier = User.CreateManaged(
                Guid.NewGuid(), world.TenantId, $"countadmins-4-{Guid.NewGuid():N}@test.local", "hash", "Cashier", null);
            cashier.AssignRole(cashierRole);

            db.Users.AddRange(secondAdmin, deactivatedAdmin, cashier);
            await db.SaveChangesAsync();

            using var scope = _factory.Services.CreateScope();
            var users = scope.ServiceProvider.GetRequiredService<IUserRepository>();

            Assert.Equal(1, await users.CountActiveAdministratorsAsync(world.TenantId, world.AdminUserId));
            Assert.Equal(1, await users.CountActiveAdministratorsAsync(world.TenantId, secondAdmin.Id));
            Assert.Equal(2, await users.CountActiveAdministratorsAsync(world.TenantId, cashier.Id));
            Assert.Equal(0, await users.CountActiveAdministratorsAsync(Guid.NewGuid(), world.AdminUserId));
        }
    }

    [Fact]
    public async Task UserRepository_AssignBranches_ReplacementPersists_AndRestoresDefaultBranch()
    {
        var world = await SeedWorldAsync("replace", branchCount: 2);

        using (var scope = _factory.Services.CreateScope())
        {
            var users = scope.ServiceProvider.GetRequiredService<IUserRepository>();
            var uow = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            var user = await users.GetByIdAsync(world.TenantId, world.AdminUserId);
            user!.AssignBranches(
                new[] { new UserBranchAssignment(world.BranchIds[1], IsDefault: true) },
                assignedBy: world.AdminUserId,
                assignedAt: DateTime.UtcNow);
            await uow.SaveChangesAsync();
        }

        using var db = CreateDbContext();
        var rows = await db.UserBranches
            .Where(ub => ub.UserId == world.AdminUserId)
            .OrderBy(ub => ub.BranchId)
            .ToListAsync();
        var branchId = Assert.Single(rows).BranchId;
        Assert.Equal(world.BranchIds[1], branchId);
        Assert.True(Assert.Single(rows).IsDefault);

        using var reloadScope = _factory.Services.CreateScope();
        var reloadUsers = reloadScope.ServiceProvider.GetRequiredService<IUserRepository>();
        var reloaded = await reloadUsers.GetByIdAsync(world.TenantId, world.AdminUserId);
        Assert.Equal(world.BranchIds[1], reloaded!.DefaultBranchId);
    }

    [Fact]
    public async Task UserRepository_AssignBranches_RemovingAssignment_DoesNotDeleteBranchRows()
    {
        var world = await SeedWorldAsync("nodelete", branchCount: 2);

        using (var setupDb = CreateDbContext())
        {
            var user = await setupDb.Users.Include(u => u.Branches)
                .SingleAsync(u => u.Id == world.AdminUserId);
            user.AssignBranches(
                new[]
                {
                    new UserBranchAssignment(world.BranchIds[0], IsDefault: true),
                    new UserBranchAssignment(world.BranchIds[1], IsDefault: false),
                },
                assignedBy: world.AdminUserId,
                assignedAt: DateTime.UtcNow);
            await setupDb.SaveChangesAsync();
        }

        using (var scope = _factory.Services.CreateScope())
        {
            var users = scope.ServiceProvider.GetRequiredService<IUserRepository>();
            var uow = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            var user = await users.GetByIdAsync(world.TenantId, world.AdminUserId);
            user!.AssignBranches(
                new[] { new UserBranchAssignment(world.BranchIds[0], IsDefault: true) },
                assignedBy: world.AdminUserId,
                assignedAt: DateTime.UtcNow);
            await uow.SaveChangesAsync();
        }

        using var db = CreateDbContext();
        Assert.Equal(1, await db.UserBranches.CountAsync(ub => ub.UserId == world.AdminUserId));
        Assert.Equal(2, await db.Branches.CountAsync(b => b.TenantId == world.TenantId));
    }

    [Fact]
    public async Task UserRepository_GlobalUniqueEmail_IsEnforcedByDatabase()
    {
        var worldA = await SeedWorldAsync("unique-a");
        using var db = CreateDbContext();

        var otherTenant = Guid.NewGuid();
        db.Tenants.Add(Tenant.Create(otherTenant, $"unique-b-{Guid.NewGuid():N}"));
        var duplicate = User.CreateManaged(
            Guid.NewGuid(), otherTenant, worldA.AdminEmail, "hash", "Duplicate", phone: null);
        db.Users.Add(duplicate);

        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task RoleRepository_GetById_IsTenantScoped_AndLoadsPermissions()
    {
        var world = await SeedWorldAsync("roleget");

        using var scope = _factory.Services.CreateScope();
        var roles = scope.ServiceProvider.GetRequiredService<IRoleRepository>();

        var found = await roles.GetByIdAsync(world.TenantId, world.AdminRoleId);
        Assert.NotNull(found);
        Assert.True(found!.IsSystem);
        Assert.Equal(new[] { PermissionNames.SalesCreate, PermissionNames.UsersView },
            found.Permissions.Select(p => p.Name).OrderBy(n => n));

        var foreign = await roles.GetByIdAsync(Guid.NewGuid(), world.AdminRoleId);
        Assert.Null(foreign);
    }

    [Fact]
    public async Task RoleRepository_GetByName_IsTenantScoped()
    {
        var worldA = await SeedWorldAsync("byname-a");
        var worldB = await SeedWorldAsync("byname-b");

        using var scope = _factory.Services.CreateScope();
        var roles = scope.ServiceProvider.GetRequiredService<IRoleRepository>();

        var found = await roles.GetByNameAsync(worldA.TenantId, SystemRoles.Administrator);
        Assert.Equal(worldA.AdminRoleId, found!.Id);
        Assert.Equal(worldA.TenantId, found.TenantId);
    }

    [Fact]
    public async Task RoleRepository_List_IsTenantScoped_AndOrdersByName()
    {
        var world = await SeedWorldAsync("rolelist");

        using (var db = CreateDbContext())
        {
            db.Roles.Add(Role.Create(world.TenantId, "Zulu"));
            db.Roles.Add(Role.Create(world.TenantId, "Alpha"));
            var otherTenant = Guid.NewGuid();
            db.Tenants.Add(Tenant.Create(otherTenant, $"rolelist-other-{Guid.NewGuid():N}"));
            db.Roles.Add(Role.Create(otherTenant, "Foreign Role"));
            await db.SaveChangesAsync();

            using var scope = _factory.Services.CreateScope();
            var roles = scope.ServiceProvider.GetRequiredService<IRoleRepository>();

            var listed = await roles.ListAsync(world.TenantId);
            Assert.Equal(new[] { SystemRoles.Administrator, "Alpha", "Zulu" }, listed.Select(r => r.Name).ToArray());
            Assert.DoesNotContain(listed, r => r.Name == "Foreign Role");
        }
    }

    [Fact]
    public async Task RoleRepository_GetPermissions_IsTenantScoped_AndOrdersNames()
    {
        var world = await SeedWorldAsync("roleperms");

        using var scope = _factory.Services.CreateScope();
        var roles = scope.ServiceProvider.GetRequiredService<IRoleRepository>();

        var own = await roles.GetPermissionsAsync(world.TenantId, world.AdminRoleId);
        Assert.Equal(new[] { PermissionNames.SalesCreate, PermissionNames.UsersView }, own.ToArray());

        var foreign = await roles.GetPermissionsAsync(Guid.NewGuid(), world.AdminRoleId);
        Assert.Empty(foreign);
    }

    [Fact]
    public async Task RoleRepository_Remove_DeletesRoleAndJoinRows_ButKeepsPermissionCatalog()
    {
        var world = await SeedWorldAsync("roledelete");

        using (var scope = _factory.Services.CreateScope())
        {
            var roles = scope.ServiceProvider.GetRequiredService<IRoleRepository>();
            var uow = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            var role = await roles.GetByIdAsync(world.TenantId, world.AdminRoleId);
            await roles.RemoveAsync(role!);
            await uow.SaveChangesAsync();
        }

        using var db = CreateDbContext();
        Assert.Null(await db.Roles.FirstOrDefaultAsync(r => r.Id == world.AdminRoleId));

        var joinCount = await db.Database.SqlQueryRaw<int>(
            $"SELECT COUNT(*)::int AS \"Value\" FROM {Schemas.Identity}.\"{Tables.Identity.RolePermissions}\" WHERE \"RoleId\" = {{0}}",
            world.AdminRoleId)
            .SingleAsync();
        Assert.Equal(0, joinCount);

        Assert.NotNull(await db.Permissions.FirstOrDefaultAsync(p => p.Name == PermissionNames.UsersView));
        Assert.NotNull(await db.Permissions.FirstOrDefaultAsync(p => p.Name == PermissionNames.SalesCreate));
    }

    [Fact]
    public async Task RoleRepository_DuplicateName_IsRejectedWithinTenant_ButAllowedAcrossTenants()
    {
        using (var db = CreateDbContext())
        {
            var tenantId = Guid.NewGuid();
            db.Tenants.Add(Tenant.Create(tenantId, $"dup-same-{Guid.NewGuid():N}"));
            db.Roles.Add(Role.Create(tenantId, "Cashier"));
            db.Roles.Add(Role.Create(tenantId, "Cashier"));

            await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        }

        using (var db = CreateDbContext())
        {
            var tenantA = Guid.NewGuid();
            var tenantB = Guid.NewGuid();
            db.Tenants.Add(Tenant.Create(tenantA, $"dup-a-{Guid.NewGuid():N}"));
            db.Tenants.Add(Tenant.Create(tenantB, $"dup-b-{Guid.NewGuid():N}"));
            db.Roles.Add(Role.Create(tenantA, "Cashier"));
            db.Roles.Add(Role.Create(tenantB, "Cashier"));

            await db.SaveChangesAsync();
        }
    }

    [Fact]
    public async Task PermissionRepository_List_ReturnsOrderedCatalog()
    {
        using var scope = _factory.Services.CreateScope();
        var permissions = scope.ServiceProvider.GetRequiredService<IPermissionRepository>();

        var catalog = await permissions.ListAsync();
        Assert.Equal(PermissionNames.All.OrderBy(n => n), catalog.Select(p => p.Name));
    }

    [Fact]
    public async Task PermissionRepository_ResolveByNames_ReturnsCanonicalRecords_IgnoringUnknown()
    {
        using var scope = _factory.Services.CreateScope();
        var permissions = scope.ServiceProvider.GetRequiredService<IPermissionRepository>();

        var resolved = await permissions.ResolveByNamesAsync(new[]
        {
            PermissionNames.SalesView,
            "Roles.DoesNotExist",
            PermissionNames.UsersView,
            PermissionNames.UsersView,
        });

        Assert.Equal(new[] { PermissionNames.SalesView, PermissionNames.UsersView },
            resolved.Select(p => p.Name).OrderBy(n => n));

        var single = await permissions.GetByNameAsync(PermissionNames.AuditView);
        Assert.Equal(PermissionNames.AuditView, single!.Name);
        Assert.Null(await permissions.GetByNameAsync("Permissions.DoesNotExist"));
    }
}

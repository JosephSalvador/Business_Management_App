using BusinessOS.Application.Features.Roles.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class RoleManagementCommandTests
{
    private sealed class StubTenantContext : ITenantContext
    {
        public Guid TenantId { get; init; }
        public Guid? UserId { get; init; }
        public string? IpAddress => null;
        public string? UserAgent => null;
        public string? CurrentRefreshToken => null;
    }

    private sealed class StubRoleRepository : IRoleRepository
    {
        public Role? Existing { get; set; }
        public Role? ByName { get; set; }
        public Role? Removed { get; private set; }

        public Task<Role?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default) => Task.FromResult(Existing);
        public Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default) => Task.FromResult(ByName);
        public Task<IReadOnlyList<Role>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Role>>(Existing is null ? Array.Empty<Role>() : new[] { Existing });
        public Task<IReadOnlyList<Role>> GetManyByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Role>>(Existing is null ? Array.Empty<Role>() : new[] { Existing });
        public Task<IReadOnlyList<string>> GetPermissionsAsync(Guid tenantId, Guid roleId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());
        public Task AddAsync(Role role, CancellationToken ct = default) => Task.CompletedTask;
        public Task AddRangeAsync(IEnumerable<Role> roles, CancellationToken ct = default) => Task.CompletedTask;

        public Task RemoveAsync(Role role, CancellationToken ct = default)
        {
            Removed = role;
            return Task.CompletedTask;
        }
    }

    private sealed class StubPermissionRepository : IPermissionRepository
    {
        public IReadOnlyList<Permission> Resolved { get; set; } = Array.Empty<Permission>();

        public Task<IReadOnlyList<Permission>> ListAsync(CancellationToken ct = default) => Task.FromResult(Resolved);
        public Task<Permission?> GetByNameAsync(string name, CancellationToken ct = default)
            => Task.FromResult(Resolved.FirstOrDefault(p => p.Name == name));
        public Task<IReadOnlyList<Permission>> ResolveByNamesAsync(IEnumerable<string> names, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Permission>>(
                Resolved.Where(p => names.Contains(p.Name)).ToArray());
    }

    private static Permission MakePermission(string name) => Permission.Seed(name);

    [Fact]
    public async Task CreateRole_DuplicateName_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var roles = new StubRoleRepository { ByName = Role.Create(tenantId, "Manager") };
        var handler = new CreateRoleCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles);

        var result = await handler.Handle(new CreateRoleCommand("Manager", null), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task CreateRole_Success_CreatesNonSystemRole()
    {
        var tenantId = Guid.NewGuid();
        var handler = new CreateRoleCommandHandler(
            new StubTenantContext { TenantId = tenantId }, new StubRoleRepository());

        var result = await handler.Handle(new CreateRoleCommand("Manager", "Manages staff"), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(tenantId, result.Value.TenantId);
        Assert.Equal("Manager", result.Value.Name);
        Assert.Equal("Manages staff", result.Value.Description);
        Assert.False(result.Value.IsSystem);
        Assert.Empty(result.Value.PermissionNames);
    }

    [Fact]
    public async Task UpdateRole_SystemRole_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var adminRole = Role.Create(tenantId, SystemRoles.Administrator, isSystem: true);
        var roles = new StubRoleRepository { Existing = adminRole };
        var handler = new UpdateRoleCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles);

        var result = await handler.Handle(new UpdateRoleCommand(adminRole.Id, "Renamed", null), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task UpdateRole_DuplicateName_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var role = Role.Create(tenantId, "Cashier");
        var other = Role.Create(tenantId, "Manager");
        var roles = new StubRoleRepository { Existing = role, ByName = other };
        var handler = new UpdateRoleCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles);

        var result = await handler.Handle(new UpdateRoleCommand(role.Id, "Manager", null), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task UpdateRole_RenamingToItsOwnName_Succeeds()
    {
        var tenantId = Guid.NewGuid();
        var role = Role.Create(tenantId, "Cashier");
        var roles = new StubRoleRepository { Existing = role, ByName = role };
        var handler = new UpdateRoleCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles);

        var result = await handler.Handle(new UpdateRoleCommand(role.Id, "Cashier", "Updated"), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("Updated", result.Value.Description);
    }

    [Fact]
    public async Task DeleteRole_SystemRole_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var adminRole = Role.Create(tenantId, SystemRoles.Administrator, isSystem: true);
        var roles = new StubRoleRepository { Existing = adminRole };
        var handler = new DeleteRoleCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles);

        var result = await handler.Handle(new DeleteRoleCommand(adminRole.Id), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
        Assert.Null(roles.Removed);
    }

    [Fact]
    public async Task DeleteRole_Success_RemovesRole()
    {
        var tenantId = Guid.NewGuid();
        var role = Role.Create(tenantId, "Cashier");
        var roles = new StubRoleRepository { Existing = role };
        var handler = new DeleteRoleCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles);

        var result = await handler.Handle(new DeleteRoleCommand(role.Id), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(role, roles.Removed);
    }

    [Fact]
    public async Task SetRolePermissions_UnknownPermission_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var role = Role.Create(tenantId, "Cashier");
        var permissions = new StubPermissionRepository
        {
            Resolved = new[] { MakePermission("Users.View") },
        };
        var roles = new StubRoleRepository { Existing = role };
        var handler = new SetRolePermissionsCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles, permissions);

        var result = await handler.Handle(
            new SetRolePermissionsCommand(role.Id, new[] { "Users.View", "Bogus.View" }),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task SetRolePermissions_Success_ReplacesPermissionsDeduplicatingInput()
    {
        var tenantId = Guid.NewGuid();
        var role = Role.Create(tenantId, "Cashier");
        role.Grant(new[] { MakePermission("Inventory.View") });
        var permissions = new StubPermissionRepository
        {
            Resolved = new[] { MakePermission("Users.View"), MakePermission("Sales.View") },
        };
        var roles = new StubRoleRepository { Existing = role };
        var handler = new SetRolePermissionsCommandHandler(
            new StubTenantContext { TenantId = tenantId }, roles, permissions);

        var result = await handler.Handle(
            new SetRolePermissionsCommand(role.Id, new[] { "Users.View", "Sales.View", "Users.View" }),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(new[] { "Sales.View", "Users.View" }, result.Value.PermissionNames);
    }
}

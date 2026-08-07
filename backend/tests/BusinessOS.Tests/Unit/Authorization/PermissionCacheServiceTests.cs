using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Authorization;

namespace BusinessOS.Tests.Unit.Authorization;

public sealed class PermissionCacheServiceTests
{
    private sealed class StubTimeProvider : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

        public override DateTimeOffset GetUtcNow() => Now;
    }

    private sealed class StubUserRepository : IUserRepository
    {
        public User? User { get; set; }
        public int GetByIdCalls { get; private set; }

        public Task<User?> GetByEmailAsync(string email, CancellationToken ct = default) => Task.FromResult(User);
        public Task<User?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        {
            GetByIdCalls++;
            return Task.FromResult(User);
        }

        public Task<User?> GetByIdWithRolesAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        {
            GetByIdCalls++;
            return Task.FromResult(User);
        }

        public Task<IReadOnlyList<User>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<User>>(User is null ? Array.Empty<User>() : new[] { User });

        public Task<int> CountAsync(Guid tenantId, CancellationToken ct = default) => Task.FromResult(0);

        public Task<int> CountActiveAdministratorsAsync(Guid tenantId, Guid excludeUserId, CancellationToken ct = default)
            => Task.FromResult(0);

        public Task AddAsync(User user, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubRoleRepository : IRoleRepository
    {
        private readonly Dictionary<Guid, string[]> _permissions = new();

        public int GetPermissionsCalls { get; private set; }

        public void SetPermissions(Guid roleId, params string[] permissions) => _permissions[roleId] = permissions;

        public Task<Role?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult<Role?>(null);

        public Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default)
            => Task.FromResult<Role?>(null);

        public Task<IReadOnlyList<Role>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Role>>(Array.Empty<Role>());

        public Task AddAsync(Role role, CancellationToken ct = default) => Task.CompletedTask;

        public Task RemoveAsync(Role role, CancellationToken ct = default) => Task.CompletedTask;

        public Task<IReadOnlyList<string>> GetPermissionsAsync(
            Guid tenantId, Guid roleId, CancellationToken ct = default)
        {
            GetPermissionsCalls++;
            IReadOnlyList<string> result = _permissions.TryGetValue(roleId, out var permissions)
                ? permissions
                : Array.Empty<string>();
            return Task.FromResult(result);
        }
    }

    private static (User User, StubUserRepository Users, StubRoleRepository Roles) CreateWorld(
        params (string Name, string[] Permissions)[] roleDefinitions)
    {
        var tenantId = Guid.NewGuid();
        var rolePermissions = new List<Role>();

        var users = new StubUserRepository();
        var roles = new StubRoleRepository();

        foreach (var (name, permissions) in roleDefinitions)
        {
            var role = Role.Create(tenantId, name);
            rolePermissions.Add(role);
            roles.SetPermissions(role.Id, permissions);
        }

        var user = User.Create(Guid.NewGuid(), tenantId, "dev@acme.local", "hash", "Dev", null);
        foreach (var role in rolePermissions)
        {
            user.AssignRole(role);
        }

        users.User = user;
        return (user, users, roles);
    }

    [Fact]
    public async Task FirstCall_LoadsPermissions_SecondCallWithinTtl_DoesNotRequery()
    {
        var (user, users, roles) = CreateWorld(("Admin", new[] { "Users.View", "Sales.Create" }));
        var service = new PermissionCacheService(users, roles);

        var first = await service.GetPermissionsAsync(user.Id, user.TenantId);
        var second = await service.GetPermissionsAsync(user.Id, user.TenantId);

        Assert.Equal(new[] { "Sales.Create", "Users.View" }, first.OrderBy(p => p));
        Assert.Equal(first, second);
        Assert.Equal(1, users.GetByIdCalls);
        Assert.Equal(1, roles.GetPermissionsCalls);
    }

    [Fact]
    public async Task InvalidateAsync_ForcesReload()
    {
        var (user, users, roles) = CreateWorld(("Admin", new[] { "Users.View" }));
        var service = new PermissionCacheService(users, roles);

        await service.GetPermissionsAsync(user.Id, user.TenantId);
        await service.InvalidateAsync(user.Id, user.TenantId);
        await service.GetPermissionsAsync(user.Id, user.TenantId);

        Assert.Equal(2, users.GetByIdCalls);
        Assert.Equal(2, roles.GetPermissionsCalls);
    }

    [Fact]
    public async Task Permissions_FromMultipleRoles_AreDeduplicated()
    {
        var (user, users, roles) = CreateWorld(
            ("Admin", new[] { "Users.View", "Users.Create" }),
            ("Sales", new[] { "Sales.View", "Users.View" }));
        var service = new PermissionCacheService(users, roles);

        var permissions = await service.GetPermissionsAsync(user.Id, user.TenantId);

        Assert.Equal(new[] { "Sales.View", "Users.Create", "Users.View" }, permissions.OrderBy(p => p));
        Assert.Equal(permissions.Distinct().Count(), permissions.Count);
    }

    [Fact]
    public async Task ExpiredEntry_IsReloaded()
    {
        var time = new StubTimeProvider();
        var (user, users, roles) = CreateWorld(("Admin", new[] { "Users.View" }));
        var service = new PermissionCacheService(users, roles, time);

        await service.GetPermissionsAsync(user.Id, user.TenantId);
        Assert.Equal(1, users.GetByIdCalls);

        time.Now = time.Now.AddMinutes(6);
        await service.GetPermissionsAsync(user.Id, user.TenantId);

        Assert.Equal(2, users.GetByIdCalls);
    }

    [Fact]
    public async Task UnknownUser_ReturnsEmptyPermissions_AndCachesThem()
    {
        var users = new StubUserRepository { User = null };
        var roles = new StubRoleRepository();
        var service = new PermissionCacheService(users, roles);
        var userId = Guid.NewGuid();
        var tenantId = Guid.NewGuid();

        var first = await service.GetPermissionsAsync(userId, tenantId);
        var second = await service.GetPermissionsAsync(userId, tenantId);

        Assert.Empty(first);
        Assert.Empty(second);
        Assert.Equal(1, users.GetByIdCalls);
    }
}

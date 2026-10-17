using BusinessOS.Application.Features.Users.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class UserManagementCommandTests
{
    private sealed class StubTenantContext : ITenantContext
    {
        public Guid TenantId { get; init; }
        public Guid? UserId { get; init; }
        public string? IpAddress => null;
        public string? UserAgent => null;
        public string? CurrentRefreshToken => null;
    }

    private sealed class StubUserRepository : IUserRepository
    {
        public User? User { get; set; }
        public int ActiveAdministrators { get; set; }
        public User? DeactivatedUser { get; private set; }

        public Task<User?> GetByEmailAsync(string email, CancellationToken ct = default) => Task.FromResult(User);
        public Task<User?> GetByPhoneAsync(string phone, CancellationToken ct = default) => Task.FromResult<User?>(null);
        public Task<User?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default) => Task.FromResult(User);
        public Task<User?> GetByIdWithRolesAsync(Guid tenantId, Guid id, CancellationToken ct = default) => Task.FromResult(User);

        public Task<IReadOnlyList<User>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<User>>(User is null ? Array.Empty<User>() : new[] { User });

        public Task<int> CountAsync(Guid tenantId, CancellationToken ct = default) => Task.FromResult(1);

        public Task<int> CountActiveAdministratorsAsync(
            Guid tenantId, Guid excludeUserId, CancellationToken ct = default)
            => Task.FromResult(ActiveAdministrators);

        public Task AddAsync(User user, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubRoleRepository : IRoleRepository
    {
        public IReadOnlyList<Role> Resolved { get; set; } = Array.Empty<Role>();

        public Task<Role?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default) => Task.FromResult<Role?>(null);
        public Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default) => Task.FromResult<Role?>(null);
        public Task<IReadOnlyList<Role>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult(Resolved);
        public Task<IReadOnlyList<Role>> GetManyByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken ct = default)
            => Task.FromResult(Resolved);
        public Task<IReadOnlyList<string>> GetPermissionsAsync(Guid tenantId, Guid roleId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());
        public Task AddAsync(Role role, CancellationToken ct = default) => Task.CompletedTask;
        public Task AddRangeAsync(IEnumerable<Role> roles, CancellationToken ct = default) => Task.CompletedTask;
        public Task RemoveAsync(Role role, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubPermissionService : IPermissionService
    {
        public List<(Guid UserId, Guid TenantId)> Invalidated { get; } = new();

        public Task<IReadOnlyCollection<string>> GetPermissionsAsync(Guid userId, Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyCollection<string>>(Array.Empty<string>());

        public Task InvalidateAsync(Guid userId, Guid tenantId, CancellationToken ct = default)
        {
            Invalidated.Add((userId, tenantId));
            return Task.CompletedTask;
        }
    }

    private sealed class StubRefreshTokenRepository : IRefreshTokenRepository
    {
        public List<Guid> RevokedForUsers { get; } = new();

        public Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken ct = default)
            => Task.FromResult<RefreshToken?>(null);
        public Task AddAsync(RefreshToken refreshToken, CancellationToken ct = default) => Task.CompletedTask;
        public Task RevokeFamilyAsync(Guid familyId, Guid revokedByTokenId, CancellationToken ct = default) => Task.CompletedTask;
        public Task RevokeAllForUserAsync(Guid tenantId, Guid userId, CancellationToken ct = default)
        {
            RevokedForUsers.Add(userId);
            return Task.CompletedTask;
        }
        public Task<int> DeleteExpiredAsync(DateTime cutoff, CancellationToken ct = default) => Task.FromResult(0);
        public Task<IReadOnlyList<RefreshToken>> ListActiveByUserAsync(Guid tenantId, Guid userId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<RefreshToken>>(Array.Empty<RefreshToken>());
    }

    private static (User User, Role AdminRole, Role CashierRole) CreateWorld(Guid tenantId, out Guid adminUserId)
    {
        var adminRole = Role.Create(tenantId, SystemRoles.Administrator, isSystem: true);
        var cashierRole = Role.Create(tenantId, "Cashier");
        var user = User.CreateManaged(Guid.NewGuid(), tenantId, "target@test.local", "hash", "Target", null);
        user.AssignRole(adminRole);
        adminUserId = user.Id;
        return (user, adminRole, cashierRole);
    }

    [Fact]
    public async Task Deactivate_WhenTargetIsLastActiveAdministrator_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, _) = CreateWorld(tenantId, out _);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 0 };
        var handler = new SetUserStatusCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = Guid.NewGuid() },
            users,
            new StubPermissionService());

        var result = await handler.Handle(new SetUserStatusCommand(user.Id, IsActive: false), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task Deactivate_WhenAnotherAdministratorExists_Succeeds()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, _) = CreateWorld(tenantId, out _);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 1 };
        var handler = new SetUserStatusCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = Guid.NewGuid() },
            users,
            new StubPermissionService());

        var result = await handler.Handle(new SetUserStatusCommand(user.Id, IsActive: false), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(result.Value.IsActive);
    }

    [Fact]
    public async Task Deactivate_Self_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, _) = CreateWorld(tenantId, out var adminUserId);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 5 };
        var handler = new SetUserStatusCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = adminUserId },
            users,
            new StubPermissionService());

        var result = await handler.Handle(new SetUserStatusCommand(user.Id, IsActive: false), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task Delete_WhenTargetIsLastActiveAdministrator_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, _) = CreateWorld(tenantId, out _);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 0 };
        var handler = new DeleteUserCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = Guid.NewGuid() },
            users,
            new StubRefreshTokenRepository(),
            new StubPermissionService());

        var result = await handler.Handle(new DeleteUserCommand(user.Id), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task Delete_Self_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, _) = CreateWorld(tenantId, out var adminUserId);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 5 };
        var handler = new DeleteUserCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = adminUserId },
            users,
            new StubRefreshTokenRepository(),
            new StubPermissionService());

        var result = await handler.Handle(new DeleteUserCommand(user.Id), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task Delete_Succeeds_DeactivatesAndRevokesAllRefreshTokens()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, _) = CreateWorld(tenantId, out _);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 1 };
        var tokens = new StubRefreshTokenRepository();
        var permissions = new StubPermissionService();
        var handler = new DeleteUserCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = Guid.NewGuid() },
            users,
            tokens,
            permissions);

        var result = await handler.Handle(new DeleteUserCommand(user.Id), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(user.IsActive);
        Assert.Equal(user.Id, Assert.Single(tokens.RevokedForUsers));
        Assert.Equal(user.Id, Assert.Single(permissions.Invalidated).UserId);
    }

    [Fact]
    public async Task SetRoles_RemovingAdministratorFromLastActiveAdministrator_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, cashierRole) = CreateWorld(tenantId, out _);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 0 };
        var roles = new StubRoleRepository { Resolved = new[] { cashierRole } };
        var handler = new SetUserRolesCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = Guid.NewGuid() },
            users,
            roles,
            new StubPermissionService());

        var result = await handler.Handle(new SetUserRolesCommand(user.Id, new[] { cashierRole.Id }), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task SetRoles_RemovingAdministratorWhenAnotherExists_SucceedsAndReplacesRoles()
    {
        var tenantId = Guid.NewGuid();
        var (user, _, cashierRole) = CreateWorld(tenantId, out _);
        var users = new StubUserRepository { User = user, ActiveAdministrators = 1 };
        var roles = new StubRoleRepository { Resolved = new[] { cashierRole } };
        var handler = new SetUserRolesCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = Guid.NewGuid() },
            users,
            roles,
            new StubPermissionService());

        var result = await handler.Handle(new SetUserRolesCommand(user.Id, new[] { cashierRole.Id }), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(new[] { cashierRole.Id }, result.Value.RoleIds);
        Assert.Equal(new[] { cashierRole.Id }, user.Roles.Select(r => r.Id).ToArray());
    }
}

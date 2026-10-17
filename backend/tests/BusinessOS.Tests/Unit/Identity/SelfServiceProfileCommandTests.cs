using BusinessOS.Application.Features.Users.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class SelfServiceProfileCommandTests
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
        public User? PhoneConflict { get; set; }

        public Task<User?> GetByEmailAsync(string email, CancellationToken ct = default) => Task.FromResult(User);
        public Task<User?> GetByPhoneAsync(string phone, CancellationToken ct = default) => Task.FromResult(PhoneConflict);
        public Task<User?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default) => Task.FromResult(User);
        public Task<User?> GetByIdWithRolesAsync(Guid tenantId, Guid id, CancellationToken ct = default) => Task.FromResult(User);
        public Task<IReadOnlyList<User>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<User>>(User is null ? Array.Empty<User>() : new[] { User });
        public Task<int> CountAsync(Guid tenantId, CancellationToken ct = default) => Task.FromResult(1);
        public Task<int> CountActiveAdministratorsAsync(Guid tenantId, Guid excludeUserId, CancellationToken ct = default) => Task.FromResult(1);
        public Task AddAsync(User user, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubRefreshTokenRepository : IRefreshTokenRepository
    {
        public List<Guid> RevokedForUsers { get; } = new();

        public Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken ct = default) => Task.FromResult<RefreshToken?>(null);
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

    private sealed class StubPasswordHasher : IPasswordHasher
    {
        public string Hash(string password) => $"hashed_{password}";
        public bool Verify(string password, string hash) => hash == $"hashed_{password}";
    }

    private sealed class StubAuditLogRepository : IAuditLogRepository
    {
        public List<AuditLog> Logs { get; } = new();
        public Task AddAsync(AuditLog auditLog, CancellationToken ct = default)
        {
            Logs.Add(auditLog);
            return Task.CompletedTask;
        }
    }

    private sealed class StubRoleRepository : IRoleRepository
    {
        public Task<Role?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default) => Task.FromResult<Role?>(null);
        public Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default) => Task.FromResult<Role?>(null);
        public Task<IReadOnlyList<Role>> ListAsync(Guid tenantId, CancellationToken ct = default) => Task.FromResult<IReadOnlyList<Role>>(Array.Empty<Role>());
        public Task<IReadOnlyList<Role>> GetManyByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken ct = default) => Task.FromResult<IReadOnlyList<Role>>(Array.Empty<Role>());
        public Task<IReadOnlyList<string>> GetPermissionsAsync(Guid tenantId, Guid roleId, CancellationToken ct = default) => Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());
        public Task AddAsync(Role role, CancellationToken ct = default) => Task.CompletedTask;
        public Task AddRangeAsync(IEnumerable<Role> roles, CancellationToken ct = default) => Task.CompletedTask;
        public Task RemoveAsync(Role role, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubTenantRepository : ITenantRepository
    {
        public Task<Tenant?> GetByIdAsync(Guid id, CancellationToken ct = default) => Task.FromResult<Tenant?>(null);
        public Task<Tenant?> GetByNameAsync(string name, CancellationToken ct = default) => Task.FromResult<Tenant?>(null);
        public Task AddAsync(Tenant tenant, CancellationToken ct = default) => Task.CompletedTask;
        public Task UpdateAsync(Tenant tenant, CancellationToken ct = default) => Task.CompletedTask;
    }

    // --- UpdateMyProfileCommand Tests ---

    [Fact]
    public async Task UpdateMyProfile_UpdatesFullNameAndPhone()
    {
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var user = User.CreateManaged(userId, tenantId, "test@test.local", "hash", "Old Name", null);

        var handler = new UpdateMyProfileCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = userId },
            new StubUserRepository { User = user });

        var result = await handler.Handle(
            new UpdateMyProfileCommand("New Name", "0712345678"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("New Name", user.FullName);
    }

    [Fact]
    public async Task UpdateMyProfile_DuplicatePhone_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var user = User.CreateManaged(userId, tenantId, "test@test.local", "hash", "Name", null);
        var conflict = User.CreateManaged(Guid.NewGuid(), tenantId, "other@test.local", "hash", "Other", "+255712345678");

        var handler = new UpdateMyProfileCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = userId },
            new StubUserRepository { User = user, PhoneConflict = conflict });

        var result = await handler.Handle(
            new UpdateMyProfileCommand("Name", "0712345678"),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task UpdateMyProfile_InvalidPhone_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var user = User.CreateManaged(userId, tenantId, "test@test.local", "hash", "Name", null);

        var handler = new UpdateMyProfileCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = userId },
            new StubUserRepository { User = user });

        var result = await handler.Handle(
            new UpdateMyProfileCommand("Name", "not-a-phone"),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task UpdateMyProfile_NotAuthenticated_ReturnsUnauthorized()
    {
        var handler = new UpdateMyProfileCommandHandler(
            new StubTenantContext { TenantId = Guid.NewGuid(), UserId = null },
            new StubUserRepository());

        var result = await handler.Handle(
            new UpdateMyProfileCommand("Name", null),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Unauthorized", result.Error.Code);
    }

    // --- ChangeMyPasswordCommand Tests ---

    [Fact]
    public async Task ChangeMyPassword_CorrectCurrentPassword_Succeeds()
    {
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var user = User.CreateManaged(userId, tenantId, "test@test.local", "hashed_oldpass", "Name", null);
        var tokens = new StubRefreshTokenRepository();
        var hasher = new StubPasswordHasher();

        var handler = new ChangeMyPasswordCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = userId },
            new StubUserRepository { User = user },
            hasher,
            tokens,
            new StubAuditLogRepository());

        var result = await handler.Handle(
            new ChangeMyPasswordCommand("oldpass", "NewPass123!"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("hashed_NewPass123!", user.PasswordHash);
        Assert.Single(tokens.RevokedForUsers);
        Assert.Equal(userId, tokens.RevokedForUsers[0]);
    }

    [Fact]
    public async Task ChangeMyPassword_WrongCurrentPassword_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var user = User.CreateManaged(userId, tenantId, "test@test.local", "hashed_correct", "Name", null);

        var handler = new ChangeMyPasswordCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = userId },
            new StubUserRepository { User = user },
            new StubPasswordHasher(),
            new StubRefreshTokenRepository(),
            new StubAuditLogRepository());

        var result = await handler.Handle(
            new ChangeMyPasswordCommand("wrongpass", "NewPass123!"),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task ChangeMyPassword_InactiveUser_ReturnsUnauthorized()
    {
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var user = User.CreateManaged(userId, tenantId, "test@test.local", "hashed_pass", "Name", null);
        user.Deactivate();

        var handler = new ChangeMyPasswordCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = userId },
            new StubUserRepository { User = user },
            new StubPasswordHasher(),
            new StubRefreshTokenRepository(),
            new StubAuditLogRepository());

        var result = await handler.Handle(
            new ChangeMyPasswordCommand("pass", "NewPass123!"),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Unauthorized", result.Error.Code);
    }

    [Fact]
    public async Task ChangeMyPassword_NotAuthenticated_ReturnsUnauthorized()
    {
        var handler = new ChangeMyPasswordCommandHandler(
            new StubTenantContext { TenantId = Guid.NewGuid(), UserId = null },
            new StubUserRepository(),
            new StubPasswordHasher(),
            new StubRefreshTokenRepository(),
            new StubAuditLogRepository());

        var result = await handler.Handle(
            new ChangeMyPasswordCommand("pass", "NewPass123!"),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Unauthorized", result.Error.Code);
    }

    [Fact]
    public async Task ChangeMyPassword_CreatesAuditLog()
    {
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var user = User.CreateManaged(userId, tenantId, "test@test.local", "hashed_pass", "Name", null);
        var audit = new StubAuditLogRepository();

        var handler = new ChangeMyPasswordCommandHandler(
            new StubTenantContext { TenantId = tenantId, UserId = userId },
            new StubUserRepository { User = user },
            new StubPasswordHasher(),
            new StubRefreshTokenRepository(),
            audit);

        await handler.Handle(
            new ChangeMyPasswordCommand("pass", "NewPass123!"),
            CancellationToken.None);

        Assert.Single(audit.Logs);
        Assert.Contains("Auth.PasswordChanged", audit.Logs[0].Action);
    }
}

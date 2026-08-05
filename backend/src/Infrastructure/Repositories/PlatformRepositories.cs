using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Infrastructure.Repositories;

public sealed class TenantRepository : ITenantRepository
{
    private readonly BusinessDbContext _db;

    public TenantRepository(BusinessDbContext db) => _db = db;

    public Task<Tenant?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => _db.Tenants.FirstOrDefaultAsync(t => t.Id == id, cancellationToken);

    public Task AddAsync(Tenant tenant, CancellationToken cancellationToken = default)
        => _db.Tenants.AddAsync(tenant, cancellationToken).AsTask();
}

public sealed class UserRepository : IUserRepository
{
    private readonly BusinessDbContext _db;

    public UserRepository(BusinessDbContext db) => _db = db;

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
        => _db.Users
            .Include(u => u.Roles)
            .FirstOrDefaultAsync(u => u.Email == email, cancellationToken);

    public Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => _db.Users
            .Include(u => u.Roles)
            .FirstOrDefaultAsync(u => u.Id == id, cancellationToken);

    public Task AddAsync(User user, CancellationToken cancellationToken = default)
        => _db.Users.AddAsync(user, cancellationToken).AsTask();
}

public sealed class RoleRepository : IRoleRepository
{
    private readonly BusinessDbContext _db;

    public RoleRepository(BusinessDbContext db) => _db = db;

    public Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default)
        => _db.Roles
            .Include(r => r.Permissions)
            .FirstOrDefaultAsync(r => r.TenantId == tenantId && r.Name == name, cancellationToken);

    public Task AddAsync(Role role, CancellationToken cancellationToken = default)
        => _db.Roles.AddAsync(role, cancellationToken).AsTask();

    public async Task<IReadOnlyList<string>> GetPermissionsAsync(
        Guid roleId,
        CancellationToken cancellationToken = default)
        => await _db.Roles
            .Where(r => r.Id == roleId)
            .SelectMany(r => r.Permissions.Select(p => p.Name))
            .Distinct()
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Permission>> GetPermissionsByNamesAsync(
        IEnumerable<string> names,
        CancellationToken cancellationToken = default)
    {
        var nameList = names.ToArray();
        return await _db.Permissions
            .Where(p => nameList.Contains(p.Name))
            .ToListAsync(cancellationToken);
    }
}

public sealed class RefreshTokenRepository : IRefreshTokenRepository
{
    private readonly BusinessDbContext _db;

    public RefreshTokenRepository(BusinessDbContext db) => _db = db;

    public Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken = default)
        => _db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == tokenHash, cancellationToken);

    public Task AddAsync(RefreshToken refreshToken, CancellationToken cancellationToken = default)
        => _db.RefreshTokens.AddAsync(refreshToken, cancellationToken).AsTask();

    public async Task RevokeFamilyAsync(
        Guid familyId,
        Guid revokedByTokenId,
        CancellationToken cancellationToken = default)
    {
        var family = await _db.RefreshTokens
            .Where(t => t.FamilyId == familyId)
            .ToListAsync(cancellationToken);

        foreach (var token in family)
        {
            if (token.RevokedAt is null)
            {
                token.Revoke();
            }
        }
    }

    public Task<int> DeleteExpiredAsync(DateTime cutoff, CancellationToken cancellationToken = default)
        => _db.RefreshTokens
            .Where(t => t.RevokedAt != null || t.ExpiresAt < cutoff)
            .ExecuteDeleteAsync(cancellationToken);
}

public sealed class AuditLogRepository : IAuditLogRepository
{
    private readonly BusinessDbContext _db;

    public AuditLogRepository(BusinessDbContext db) => _db = db;

    public Task AddAsync(AuditLog auditLog, CancellationToken cancellationToken = default)
        => _db.AuditLogs.AddAsync(auditLog, cancellationToken).AsTask();
}

public sealed class FeatureFlagRepository : IFeatureFlagRepository
{
    private readonly BusinessDbContext _db;

    public FeatureFlagRepository(BusinessDbContext db) => _db = db;

    public Task<FeatureFlag?> GetAsync(Guid tenantId, string key, CancellationToken cancellationToken = default)
        => _db.FeatureFlags.FirstOrDefaultAsync(f => f.TenantId == tenantId && f.Key == key, cancellationToken);
}

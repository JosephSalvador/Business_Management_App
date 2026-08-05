using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared.Events;

namespace BusinessOS.Application.Ports;

public sealed record DispatchedEvent(Guid OutboxMessageId, IDomainEvent Event);

public interface IUnitOfWork
{
    Task<IReadOnlyList<DispatchedEvent>> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task MarkProcessedAsync(IReadOnlyCollection<Guid> outboxMessageIds, CancellationToken cancellationToken = default);
}

public interface ITenantRepository
{
    Task<Tenant?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task AddAsync(Tenant tenant, CancellationToken cancellationToken = default);
}

public interface IUserRepository
{
    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task AddAsync(User user, CancellationToken cancellationToken = default);
}

public interface IRoleRepository
{
    Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task AddAsync(Role role, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<string>> GetPermissionsAsync(Guid roleId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Permission>> GetPermissionsByNamesAsync(
        IEnumerable<string> names, CancellationToken cancellationToken = default);
}

public interface IRefreshTokenRepository
{
    Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken = default);
    Task AddAsync(RefreshToken refreshToken, CancellationToken cancellationToken = default);
    Task RevokeFamilyAsync(Guid familyId, Guid revokedByTokenId, CancellationToken cancellationToken = default);
    Task<int> DeleteExpiredAsync(DateTime cutoff, CancellationToken cancellationToken = default);
}

public interface IAuditLogRepository
{
    Task AddAsync(AuditLog auditLog, CancellationToken cancellationToken = default);
}

public interface IFeatureFlagRepository
{
    Task<FeatureFlag?> GetAsync(Guid tenantId, string key, CancellationToken cancellationToken = default);
}

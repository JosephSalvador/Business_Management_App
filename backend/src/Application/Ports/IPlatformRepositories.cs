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
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}

public interface ITenantRepository
{
    Task<Tenant?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task AddAsync(Tenant tenant, CancellationToken cancellationToken = default);
}

public interface IBranchRepository
{
    Task<Branch?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Branch?> GetByCodeAsync(Guid tenantId, string code, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Branch>> ListAsync(
        Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Branch>> ListAllAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Branch>> ListByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Branch branch, CancellationToken cancellationToken = default);
}

public interface IUserRepository
{
    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task<User?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByIdWithRolesAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<User>> ListAsync(
        Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<int> CountActiveAdministratorsAsync(
        Guid tenantId, Guid excludeUserId, CancellationToken cancellationToken = default);
    Task AddAsync(User user, CancellationToken cancellationToken = default);
}

public interface IRoleRepository
{
    Task<Role?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default);
    Task<Role?> GetByNameAsync(Guid tenantId, string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Role>> ListAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Role>> GetManyByIdsAsync(
        Guid tenantId, IEnumerable<Guid> ids, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<string>> GetPermissionsAsync(
        Guid tenantId, Guid roleId, CancellationToken cancellationToken = default);
    Task AddAsync(Role role, CancellationToken cancellationToken = default);
    Task RemoveAsync(Role role, CancellationToken cancellationToken = default);
}

public interface IPermissionRepository
{
    Task<IReadOnlyList<Permission>> ListAsync(CancellationToken cancellationToken = default);
    Task<Permission?> GetByNameAsync(string name, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Permission>> ResolveByNamesAsync(
        IEnumerable<string> names, CancellationToken cancellationToken = default);
}

public interface IRefreshTokenRepository
{
    Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken = default);
    Task AddAsync(RefreshToken refreshToken, CancellationToken cancellationToken = default);
    Task RevokeFamilyAsync(Guid familyId, Guid revokedByTokenId, CancellationToken cancellationToken = default);
    Task RevokeAllForUserAsync(Guid tenantId, Guid userId, CancellationToken cancellationToken = default);
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

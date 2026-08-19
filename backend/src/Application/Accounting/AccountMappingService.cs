using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;

namespace BusinessOS.Application.Accounting;

public interface IAccountMappingService
{
    Task<Guid?> GetAccountIdAsync(Guid tenantId, string mappingKey, CancellationToken cancellationToken = default);
}

public sealed class AccountMappingService : IAccountMappingService
{
    private readonly ITenantAccountMappingRepository _mappings;

    public AccountMappingService(ITenantAccountMappingRepository mappings)
    {
        _mappings = mappings;
    }

    public async Task<Guid?> GetAccountIdAsync(Guid tenantId, string mappingKey, CancellationToken cancellationToken = default)
    {
        var mapping = await _mappings.GetByMappingKeyAsync(tenantId, mappingKey, cancellationToken);
        return mapping?.AccountId;
    }
}

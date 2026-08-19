using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Accounting;

public sealed class TenantAccountMapping : Entity
{
    private TenantAccountMapping(Guid id, Guid tenantId, string mappingKey, Guid accountId) : base(id)
    {
        TenantId = tenantId;
        MappingKey = mappingKey;
        AccountId = accountId;
    }

    public Guid TenantId { get; private set; }
    public string MappingKey { get; private set; } = string.Empty;
    public Guid AccountId { get; private set; }

    public static TenantAccountMapping Create(Guid tenantId, string mappingKey, Guid accountId)
    {
        return new TenantAccountMapping(Guid.NewGuid(), tenantId, mappingKey.Trim(), accountId);
    }
}

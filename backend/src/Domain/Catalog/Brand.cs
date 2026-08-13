using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Catalog;

public sealed class Brand : AggregateRoot
{
    private Brand(Guid id, Guid tenantId, string name)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }

    public static Brand Create(Guid tenantId, string name)
        => new(Guid.NewGuid(), tenantId, name.Trim());

    public void Rename(string name) => Name = name.Trim();
}

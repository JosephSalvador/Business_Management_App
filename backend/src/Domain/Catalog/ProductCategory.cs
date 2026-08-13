using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Catalog;

public sealed class ProductCategory : AggregateRoot
{
    private ProductCategory(Guid id, Guid tenantId, string name, Guid? parentId)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        ParentId = parentId;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public Guid? ParentId { get; private set; }
    public bool IsActive { get; private set; } = true;

    public static ProductCategory Create(Guid tenantId, string name, Guid? parentId = null)
        => new(Guid.NewGuid(), tenantId, name.Trim(), parentId);

    public void UpdateProfile(string name, Guid? parentId)
    {
        Name = name.Trim();
        ParentId = parentId;
    }

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;
}

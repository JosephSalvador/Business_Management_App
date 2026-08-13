using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Catalog;

public sealed class UnitOfMeasure : AggregateRoot
{
    private UnitOfMeasure(Guid id, Guid tenantId, string name, string abbreviation)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        Abbreviation = abbreviation;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public string Abbreviation { get; private set; }

    public static UnitOfMeasure Create(Guid tenantId, string name, string abbreviation)
        => new(Guid.NewGuid(), tenantId, name.Trim(), abbreviation.Trim());

    public void Update(string name, string abbreviation)
    {
        Name = name.Trim();
        Abbreviation = abbreviation.Trim();
    }
}

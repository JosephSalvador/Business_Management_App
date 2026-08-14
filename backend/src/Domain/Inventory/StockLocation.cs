using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Inventory;

public sealed class StockLocation : Entity
{
    private StockLocation(Guid id, Guid tenantId, Guid warehouseId, string code, string name, bool isActive)
        : base(id)
    {
        TenantId = tenantId;
        WarehouseId = warehouseId;
        Code = code;
        Name = name;
        IsActive = isActive;
    }

    public Guid TenantId { get; private set; }
    public Guid WarehouseId { get; private set; }
    public string Code { get; private set; }
    public string Name { get; private set; }
    public bool IsActive { get; private set; }

    internal static StockLocation Assign(
        Guid tenantId, Guid warehouseId, Guid id, string code, string name, bool isActive)
        => new(id, tenantId, warehouseId, code, name, isActive);

    internal void Rename(string code, string name)
    {
        Code = code;
        Name = name;
    }
}

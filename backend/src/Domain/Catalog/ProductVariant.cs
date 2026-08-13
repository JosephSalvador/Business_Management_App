using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Catalog;

public sealed class ProductVariant : Entity
{
    private ProductVariant(Guid id, Guid tenantId, Guid productId, string name, string? sku, string? barcode)
        : base(id)
    {
        TenantId = tenantId;
        ProductId = productId;
        Name = name;
        Sku = sku;
        Barcode = barcode;
    }

    public Guid TenantId { get; private set; }
    public Guid ProductId { get; private set; }
    public string Name { get; private set; }
    public string? Sku { get; private set; }
    public string? Barcode { get; private set; }

    internal static ProductVariant Assign(Guid tenantId, Guid productId, Guid id, string name, string? sku, string? barcode)
        => new(id, tenantId, productId, name, sku, barcode);

    internal void Rename(string name, string? sku, string? barcode)
    {
        Name = name;
        Sku = sku;
        Barcode = barcode;
    }
}

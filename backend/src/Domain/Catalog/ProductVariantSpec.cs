namespace BusinessOS.Domain.Catalog;

public sealed record ProductVariantSpec(Guid Id, string Name, string? Sku, string? Barcode);

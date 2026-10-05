using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Catalog;

public sealed class Product : AggregateRoot
{
    private readonly List<ProductVariant> _variants = new();

    private Product(
        Guid id,
        Guid tenantId,
        string name,
        string? description,
        string? sku,
        string? barcode,
        Guid? categoryId,
        Guid? brandId,
        Guid unitOfMeasureId,
        ProductType productType,
        ProductStatus status,
        Guid? taxCategoryId,
        decimal? costPrice)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        Description = description;
        Sku = sku;
        Barcode = barcode;
        CategoryId = categoryId;
        BrandId = brandId;
        UnitOfMeasureId = unitOfMeasureId;
        ProductType = productType;
        Status = status;
        TaxCategoryId = taxCategoryId;
        CostPrice = costPrice;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public string? Description { get; private set; }
    public string? Sku { get; private set; }
    public string? Barcode { get; private set; }
    public Guid? CategoryId { get; private set; }
    public Guid? BrandId { get; private set; }
    public Guid UnitOfMeasureId { get; private set; }
    public ProductType ProductType { get; private set; }
    public ProductStatus Status { get; private set; }
    public Guid? TaxCategoryId { get; private set; }
    public decimal? CostPrice { get; private set; }

    public bool HasVariants => _variants.Count > 0;
    public IReadOnlyCollection<ProductVariant> Variants => _variants.AsReadOnly();

    public static Product Create(
        Guid tenantId,
        string name,
        string? description,
        string? sku,
        string? barcode,
        Guid? categoryId,
        Guid? brandId,
        Guid unitOfMeasureId,
        ProductType productType,
        ProductStatus status = ProductStatus.Draft,
        Guid? taxCategoryId = null,
        decimal? costPrice = null)
    {
        var product = new Product(
            Guid.NewGuid(),
            tenantId,
            name.Trim(),
            description,
            NormalizeIdentifier(sku),
            NormalizeIdentifier(barcode),
            categoryId,
            brandId,
            unitOfMeasureId,
            productType,
            status,
            taxCategoryId,
            costPrice);

        product.AddDomainEvent(new ProductCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, product.Id, tenantId, product.Name, product.Sku));

        return product;
    }

    public void UpdateProfile(
        string name,
        string? description,
        Guid? categoryId,
        Guid? brandId,
        Guid unitOfMeasureId,
        Guid? taxCategoryId = null,
        decimal? costPrice = null)
    {
        Name = name.Trim();
        Description = description;
        CategoryId = categoryId;
        BrandId = brandId;
        UnitOfMeasureId = unitOfMeasureId;
        TaxCategoryId = taxCategoryId;
        CostPrice = costPrice;

        AddDomainEvent(new ProductUpdatedEvent(Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name));
    }

    public void UpdateIdentifiers(string? sku, string? barcode)
    {
        if (HasVariants && (sku is not null || barcode is not null))
        {
            throw new InvalidOperationException("Products with variants must keep product-level SKU and barcode empty.");
        }

        Sku = NormalizeIdentifier(sku);
        Barcode = NormalizeIdentifier(barcode);

        AddDomainEvent(new ProductUpdatedEvent(Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name));
    }

    public void SetStatus(ProductStatus status)
    {
        if (Status == status)
        {
            return;
        }

        Status = status;

        AddDomainEvent(new ProductStatusChangedEvent(Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Status));
    }

    public void SetVariants(IEnumerable<ProductVariantSpec> variants)
    {
        var specs = variants.ToList();

        if (specs.Select(s => s.Name.Trim()).Distinct().Count() != specs.Count)
        {
            throw new ArgumentException("Variant names must be unique.", nameof(variants));
        }

        if (specs.Count > 0 && (Sku is not null || Barcode is not null))
        {
            throw new InvalidOperationException("Products with variants must keep product-level SKU and barcode empty.");
        }

        if (HasSameVariants(specs))
        {
            return;
        }

        var kept = new List<ProductVariant>();
        foreach (var spec in specs)
        {
            var name = spec.Name.Trim();
            var sku = NormalizeIdentifier(spec.Sku);
            var barcode = NormalizeIdentifier(spec.Barcode);

            var existing = _variants.FirstOrDefault(v => (spec.Id != Guid.Empty && v.Id == spec.Id) || v.Name == name);
            if (existing is null)
            {
                kept.Add(ProductVariant.Assign(TenantId, Id, Guid.Empty, name, sku, barcode));
                continue;
            }

            existing.Rename(name, sku, barcode);
            kept.Add(existing);
        }

        foreach (var dropped in _variants.Except(kept).ToList())
        {
            _variants.Remove(dropped);
        }

        _variants.Clear();
        _variants.AddRange(kept);

        AddDomainEvent(new ProductVariantsChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, _variants.Select(v => v.Id).ToArray(), HasVariants));
    }

    private bool HasSameVariants(IReadOnlyCollection<ProductVariantSpec> specs)
    {
        if (specs.Count != _variants.Count)
        {
            return false;
        }

        foreach (var spec in specs)
        {
            var name = spec.Name.Trim();
            var sku = NormalizeIdentifier(spec.Sku);
            var barcode = NormalizeIdentifier(spec.Barcode);

            var match = _variants.FirstOrDefault(v => (spec.Id != Guid.Empty && v.Id == spec.Id) || v.Name == name);
            if (match is null || match.Name != name || match.Sku != sku || match.Barcode != barcode)
            {
                return false;
            }
        }

        return true;
    }

    public static string? NormalizeIdentifier(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

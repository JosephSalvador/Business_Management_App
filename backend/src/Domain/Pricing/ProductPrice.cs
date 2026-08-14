using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Pricing;

public sealed class ProductPrice : Entity
{
    private ProductPrice(
        Guid id,
        Guid tenantId,
        Guid priceListId,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType)
        : base(id)
    {
        TenantId = tenantId;
        PriceListId = priceListId;
        ProductId = productId;
        VariantId = variantId;
        BranchId = branchId;
        PriceType = priceType;
    }

    public Guid TenantId { get; private set; }
    public Guid PriceListId { get; private set; }
    public Guid ProductId { get; private set; }
    public Guid? VariantId { get; private set; }
    public Guid? BranchId { get; private set; }
    public PriceType PriceType { get; private set; }
    public decimal Price { get; private set; }
    public string Currency { get; private set; } = String.Empty;
    public decimal MinQuantity { get; private set; }
    public DateTime? EffectiveFrom { get; private set; }
    public DateTime? EffectiveTo { get; private set; }
    public bool IsActive { get; private set; }

    public static ProductPrice Assign(
        Guid tenantId,
        Guid priceListId,
        Guid id,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal price,
        string currency,
        decimal minQuantity,
        DateTime? effectiveFrom,
        DateTime? effectiveTo,
        bool isActive)
    {
        var productPrice = new ProductPrice(
            id == Guid.Empty ? Guid.NewGuid() : id,
            tenantId,
            priceListId,
            productId,
            variantId,
            branchId,
            priceType);

        productPrice.Update(price, currency, minQuantity, effectiveFrom, effectiveTo, isActive);
        return productPrice;
    }

    public void Update(
        decimal price,
        string currency,
        decimal minQuantity,
        DateTime? effectiveFrom,
        DateTime? effectiveTo,
        bool isActive)
    {
        if (price <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(price), "Price must be positive.");
        }

        if (minQuantity < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(minQuantity), "Minimum quantity must be at least 1.");
        }

        ValidateWindow(effectiveFrom, effectiveTo);

        Price = price;
        Currency = NormalizeCurrency(currency);
        MinQuantity = minQuantity;
        EffectiveFrom = effectiveFrom;
        EffectiveTo = effectiveTo;
        IsActive = isActive;
    }

    public bool IsEffectiveAt(DateTime onDate)
        => IsActive
            && (EffectiveFrom is null || EffectiveFrom <= onDate)
            && (EffectiveTo is null || EffectiveTo >= onDate);

    public bool HasSameKey(ProductPriceSpec spec)
        => ProductId == spec.ProductId
            && VariantId == spec.VariantId
            && BranchId == spec.BranchId
            && PriceType == spec.PriceType;

    public static string NormalizeCurrency(string currency) => currency.Trim().ToUpperInvariant();

    private static void ValidateWindow(DateTime? effectiveFrom, DateTime? effectiveTo)
    {
        if (effectiveFrom is not null && effectiveTo is not null && effectiveFrom > effectiveTo)
        {
            throw new ArgumentException("EffectiveFrom must be before or equal to EffectiveTo.");
        }
    }
}

using BusinessOS.Domain.Pricing;

namespace BusinessOS.Tests.Unit.Pricing;

public sealed class PriceResolverTests
{
    private static readonly Guid ProductId = Guid.NewGuid();
    private static readonly Guid VariantA = Guid.NewGuid();
    private static readonly Guid VariantB = Guid.NewGuid();
    private static readonly Guid BranchA = Guid.NewGuid();
    private static readonly Guid BranchB = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid PriceListId = Guid.NewGuid();

    private static readonly DateTime OnDate = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

    private static ProductPrice Price(
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal price,
        decimal minQuantity = 1m,
        DateTime? effectiveFrom = null,
        DateTime? effectiveTo = null,
        bool isActive = true)
        => ProductPrice.Assign(
            TenantId,
            PriceListId,
            Guid.Empty,
            productId,
            variantId,
            branchId,
            priceType,
            price,
            "TZS",
            minQuantity,
            effectiveFrom,
            effectiveTo,
            isActive);

    [Fact]
    public void Resolve_BranchOverride_BeatsAllBranchBase()
    {
        var prices = new[]
        {
            Price(ProductId, null, null, PriceType.Retail, 100m),
            Price(ProductId, null, BranchA, PriceType.Retail, 90m),
        };

        var resolved = PriceResolver.Resolve(prices, ProductId, null, BranchA, PriceType.Retail, 1m, OnDate);

        Assert.NotNull(resolved);
        Assert.Equal(90m, resolved!.Price);
    }

    [Fact]
    public void Resolve_WithoutBranch_UsesAllBranchBaseOnly()
    {
        var prices = new[]
        {
            Price(ProductId, null, null, PriceType.Retail, 100m),
            Price(ProductId, null, BranchA, PriceType.Retail, 90m),
        };

        var resolved = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 1m, OnDate);

        Assert.NotNull(resolved);
        Assert.Equal(100m, resolved!.Price);
    }

    [Fact]
    public void Resolve_FiltersByPriceType()
    {
        var prices = new[]
        {
            Price(ProductId, null, null, PriceType.Retail, 100m),
            Price(ProductId, null, null, PriceType.Wholesale, 80m),
        };

        var wholesale = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Wholesale, 1m, OnDate);
        Assert.Equal(80m, wholesale!.Price);

        var retail = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 1m, OnDate);
        Assert.Equal(100m, retail!.Price);
    }

    [Fact]
    public void Resolve_FiltersByVariant()
    {
        var prices = new[]
        {
            Price(ProductId, VariantA, null, PriceType.Retail, 60m),
            Price(ProductId, VariantB, null, PriceType.Retail, 70m),
        };

        var resolved = PriceResolver.Resolve(prices, ProductId, VariantB, null, PriceType.Retail, 1m, OnDate);

        Assert.NotNull(resolved);
        Assert.Equal(70m, resolved!.Price);
    }

    [Fact]
    public void Resolve_HighestQualifyingMinQuantity_Wins()
    {
        var prices = new[]
        {
            Price(ProductId, null, null, PriceType.Retail, 100m, minQuantity: 1m),
            Price(ProductId, null, null, PriceType.Retail, 90m, minQuantity: 5m),
            Price(ProductId, null, null, PriceType.Retail, 80m, minQuantity: 10m),
        };

        var qty3 = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 3m, OnDate);
        Assert.Equal(100m, qty3!.Price);

        var qty5 = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 5m, OnDate);
        Assert.Equal(90m, qty5!.Price);

        var qty12 = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 12m, OnDate);
        Assert.Equal(80m, qty12!.Price);
    }

    [Fact]
    public void Resolve_LatestEffectiveFrom_IsTieBreak()
    {
        var prices = new[]
        {
            Price(ProductId, null, null, PriceType.Retail, 100m, effectiveFrom: new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)),
            Price(ProductId, null, null, PriceType.Retail, 110m, effectiveFrom: new DateTime(2026, 6, 1, 0, 0, 0, DateTimeKind.Utc)),
        };

        var resolved = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 1m, OnDate);

        Assert.NotNull(resolved);
        Assert.Equal(110m, resolved!.Price);
    }

    [Fact]
    public void Resolve_IgnoresInactiveAndOutOfWindowRows()
    {
        var prices = new[]
        {
            Price(ProductId, null, null, PriceType.Retail, 100m, isActive: false),
            Price(ProductId, null, null, PriceType.Retail, 120m, effectiveFrom: new DateTime(2026, 9, 1, 0, 0, 0, DateTimeKind.Utc)),
        };

        var resolved = PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 1m, OnDate);

        Assert.Null(resolved);
    }

    [Fact]
    public void Resolve_NoPrice_ReturnsNull()
    {
        var prices = new[] { Price(ProductId, null, null, PriceType.Retail, 100m) };

        var resolved = PriceResolver.Resolve(
            prices, Guid.NewGuid(), null, null, PriceType.Retail, 1m, OnDate);

        Assert.Null(resolved);
    }

    [Fact]
    public void Resolve_QuantityBelowOne_Throws()
    {
        var prices = new[] { Price(ProductId, null, null, PriceType.Retail, 100m) };

        Assert.Throws<ArgumentOutOfRangeException>(() =>
            PriceResolver.Resolve(prices, ProductId, null, null, PriceType.Retail, 0m, OnDate));
    }
}

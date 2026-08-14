namespace BusinessOS.Domain.Pricing;

public sealed record ResolvedPrice(
    Guid ProductPriceId,
    Guid PriceListId,
    decimal Price,
    string Currency,
    PriceType PriceType,
    decimal MinQuantity);

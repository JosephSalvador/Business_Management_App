namespace BusinessOS.Domain.Pricing;

public sealed record ProductPriceSpec(
    Guid Id,
    Guid ProductId,
    Guid? VariantId,
    Guid? BranchId,
    PriceType PriceType,
    decimal Price,
    string Currency,
    decimal MinQuantity,
    DateTime? EffectiveFrom,
    DateTime? EffectiveTo,
    bool IsActive);

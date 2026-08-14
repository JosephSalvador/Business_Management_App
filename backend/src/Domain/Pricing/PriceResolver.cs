namespace BusinessOS.Domain.Pricing;

public static class PriceResolver
{
    public static ResolvedPrice? Resolve(
        IEnumerable<ProductPrice> prices,
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal quantity,
        DateTime onDate)
    {
        if (quantity < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(quantity), "Quantity must be at least 1.");
        }

        var price = prices
            .Where(candidate => candidate.ProductId == productId)
            .Where(candidate => candidate.VariantId == variantId)
            .Where(candidate => candidate.PriceType == priceType)
            .Where(candidate => candidate.MinQuantity <= quantity)
            .Where(candidate => candidate.IsEffectiveAt(onDate))
            .Where(candidate => branchId.HasValue
                ? candidate.BranchId is null || candidate.BranchId == branchId
                : candidate.BranchId is null)
            .OrderByDescending(candidate => branchId.HasValue && candidate.BranchId == branchId)
            .ThenByDescending(candidate => candidate.MinQuantity)
            .ThenByDescending(candidate => candidate.EffectiveFrom ?? DateTime.MinValue)
            .FirstOrDefault();

        return price is null
            ? null
            : new ResolvedPrice(
                price.Id,
                price.PriceListId,
                price.Price,
                price.Currency,
                price.PriceType,
                price.MinQuantity);
    }
}

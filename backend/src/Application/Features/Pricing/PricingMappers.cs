using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Domain.Pricing;

namespace BusinessOS.Application.Features.Pricing;

internal static class PricingMappers
{
    internal static PriceListDto ToDto(PriceList priceList) => new(
        priceList.Id,
        priceList.TenantId,
        priceList.Name,
        priceList.Currency,
        priceList.IsDefault,
        priceList.IsActive,
        priceList.EffectiveFrom,
        priceList.EffectiveTo,
        priceList.CreatedAt,
        priceList.UpdatedAt);

    internal static ProductPriceDto ToPriceDto(ProductPrice price) => new(
        price.Id,
        price.PriceListId,
        price.ProductId,
        price.VariantId,
        price.BranchId,
        price.PriceType,
        price.Price,
        price.Currency,
        price.MinQuantity,
        price.EffectiveFrom,
        price.EffectiveTo,
        price.IsActive);

    internal static ProductPriceSpec ToSpec(ProductPriceInputDto input) => new(
        input.Id ?? Guid.Empty,
        input.ProductId,
        input.VariantId,
        input.BranchId,
        input.PriceType,
        input.Price,
        ProductPrice.NormalizeCurrency(input.Currency),
        input.MinQuantity,
        input.EffectiveFrom,
        input.EffectiveTo,
        input.IsActive);

    internal static ResolvedPriceDto ToResolvedDto(ResolvedPrice price) => new(
        price.Price,
        price.Currency,
        price.PriceListId,
        price.PriceType,
        price.MinQuantity);
}

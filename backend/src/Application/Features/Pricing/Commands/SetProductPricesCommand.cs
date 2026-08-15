using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Pricing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Commands;

public sealed record SetProductPricesCommand(
    Guid PriceListId,
    IReadOnlyList<ProductPriceInputDto> Prices)
    : IRequest<Result<IReadOnlyList<ProductPriceDto>>>, IRequiresTenantAdvisoryLock;

public sealed class SetProductPricesCommandHandler
    : IRequestHandler<SetProductPricesCommand, Result<IReadOnlyList<ProductPriceDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPriceListRepository _priceLists;
    private readonly IProductPriceRepository _productPrices;
    private readonly IProductRepository _products;
    private readonly IBranchRepository _branches;

    public SetProductPricesCommandHandler(
        ITenantContext tenantContext,
        IPriceListRepository priceLists,
        IProductPriceRepository productPrices,
        IProductRepository products,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _priceLists = priceLists;
        _productPrices = productPrices;
        _products = products;
        _branches = branches;
    }

    public async Task<Result<IReadOnlyList<ProductPriceDto>>> Handle(
        SetProductPricesCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var priceList = await _priceLists.GetByIdAsync(tenantId, command.PriceListId, includePrices: true, cancellationToken);
        if (priceList is null)
        {
            return Error.NotFound("Price list not found.");
        }

        if (HasDuplicateKeys(command.Prices))
        {
            return Error.Validation("Each price key (product, variant, branch, price type) may appear only once.");
        }

        var branchIds = command.Prices
            .Select(p => p.BranchId)
            .Where(b => b.HasValue)
            .Select(b => b!.Value)
            .Distinct()
            .ToArray();
        if (branchIds.Length > 0)
        {
            var branches = await _branches.ListByIdsAsync(tenantId, branchIds, cancellationToken);
            if (branches.Count != branchIds.Length)
            {
                return Error.Validation("One or more branches do not exist in this tenant.");
            }
        }

        foreach (var productId in command.Prices.Select(p => p.ProductId).Distinct())
        {
            var product = await _products.GetByIdAsync(tenantId, productId, cancellationToken);
            if (product is null)
            {
                return Error.Validation("One or more products do not exist in this tenant.");
            }

            foreach (var price in command.Prices.Where(p => p.ProductId == productId))
            {
                if (product.HasVariants)
                {
                    if (!price.VariantId.HasValue || product.Variants.All(v => v.Id != price.VariantId.Value))
                    {
                        return Error.Validation("A variant belonging to the product must be specified.");
                    }
                }
                else if (price.VariantId.HasValue)
                {
                    return Error.Validation("This product has no variants.");
                }
            }
        }

        await _productPrices.UpsertManyAsync(
            priceList, command.Prices.Select(PricingMappers.ToSpec).ToList(), cancellationToken);

        return Result.Success<IReadOnlyList<ProductPriceDto>>(
            priceList.Prices.Select(PricingMappers.ToPriceDto).ToArray());
    }

    private static bool HasDuplicateKeys(IReadOnlyList<ProductPriceInputDto> prices)
    {
        var keys = prices.Select(p => (p.ProductId, p.VariantId, p.BranchId, p.PriceType)).ToArray();
        return keys.Distinct().Count() != keys.Length;
    }
}

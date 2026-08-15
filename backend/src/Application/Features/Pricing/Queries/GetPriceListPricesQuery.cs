using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Pricing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Queries;

public sealed record GetPriceListPricesQuery(
    Guid PriceListId,
    Guid? ProductId,
    Guid? BranchId,
    PriceType? PriceType) : IRequest<Result<IReadOnlyList<ProductPriceDto>>>;

public sealed class GetPriceListPricesQueryHandler
    : IRequestHandler<GetPriceListPricesQuery, Result<IReadOnlyList<ProductPriceDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPriceListRepository _priceLists;
    private readonly IProductPriceRepository _productPrices;

    public GetPriceListPricesQueryHandler(
        ITenantContext tenantContext,
        IPriceListRepository priceLists,
        IProductPriceRepository productPrices)
    {
        _tenantContext = tenantContext;
        _priceLists = priceLists;
        _productPrices = productPrices;
    }

    public async Task<Result<IReadOnlyList<ProductPriceDto>>> Handle(
        GetPriceListPricesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        if (await _priceLists.GetByIdAsync(tenantId, request.PriceListId, includePrices: false, cancellationToken) is null)
        {
            return Error.NotFound("Price list not found.");
        }

        var prices = await _productPrices.ListAsync(
            tenantId, request.PriceListId, request.ProductId, request.BranchId, request.PriceType, cancellationToken);

        return Result.Success<IReadOnlyList<ProductPriceDto>>(prices.Select(PricingMappers.ToPriceDto).ToArray());
    }
}

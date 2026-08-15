using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Queries;

public sealed record GetPriceListQuery(Guid Id) : IRequest<Result<PriceListDto>>;

public sealed class GetPriceListQueryHandler : IRequestHandler<GetPriceListQuery, Result<PriceListDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPriceListRepository _priceLists;

    public GetPriceListQueryHandler(ITenantContext tenantContext, IPriceListRepository priceLists)
    {
        _tenantContext = tenantContext;
        _priceLists = priceLists;
    }

    public async Task<Result<PriceListDto>> Handle(GetPriceListQuery request, CancellationToken cancellationToken)
    {
        var priceList = await _priceLists.GetByIdAsync(
            _tenantContext.TenantId, request.Id, includePrices: false, cancellationToken);
        if (priceList is null)
        {
            return Error.NotFound("Price list not found.");
        }

        return Result.Success(PricingMappers.ToDto(priceList));
    }
}

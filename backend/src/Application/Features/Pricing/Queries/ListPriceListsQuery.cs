using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Pricing.Queries;

public sealed record ListPriceListsQuery : IRequest<Result<IReadOnlyList<PriceListDto>>>;

public sealed class ListPriceListsQueryHandler : IRequestHandler<ListPriceListsQuery, Result<IReadOnlyList<PriceListDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPriceListRepository _priceLists;

    public ListPriceListsQueryHandler(ITenantContext tenantContext, IPriceListRepository priceLists)
    {
        _tenantContext = tenantContext;
        _priceLists = priceLists;
    }

    public async Task<Result<IReadOnlyList<PriceListDto>>> Handle(
        ListPriceListsQuery request, CancellationToken cancellationToken)
    {
        var priceLists = await _priceLists.ListAsync(_tenantContext.TenantId, cancellationToken);
        return Result.Success<IReadOnlyList<PriceListDto>>(priceLists.Select(PricingMappers.ToDto).ToArray());
    }
}

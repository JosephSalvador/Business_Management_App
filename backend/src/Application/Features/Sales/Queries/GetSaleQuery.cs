using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Sales.Queries;

public sealed record GetSaleQuery(Guid Id) : IRequest<Result<SaleDto>>;

public sealed class GetSaleQueryHandler : IRequestHandler<GetSaleQuery, Result<SaleDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISaleRepository _sales;

    public GetSaleQueryHandler(ITenantContext tenantContext, ISaleRepository sales)
    {
        _tenantContext = tenantContext;
        _sales = sales;
    }

    public async Task<Result<SaleDto>> Handle(GetSaleQuery request, CancellationToken cancellationToken)
    {
        var sale = await _sales.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (sale is null)
        {
            return Error.NotFound("Sale not found.");
        }

        return Result.Success(SalesMappers.ToDto(sale));
    }
}

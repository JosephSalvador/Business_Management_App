using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Queries;

public sealed record GetProductQuery(Guid Id) : IRequest<Result<ProductDto>>;

public sealed class GetProductQueryHandler : IRequestHandler<GetProductQuery, Result<ProductDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;

    public GetProductQueryHandler(ITenantContext tenantContext, IProductRepository products)
    {
        _tenantContext = tenantContext;
        _products = products;
    }

    public async Task<Result<ProductDto>> Handle(GetProductQuery request, CancellationToken cancellationToken)
    {
        var product = await _products.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        return Result.Success(ProductMappers.ToDto(product));
    }
}

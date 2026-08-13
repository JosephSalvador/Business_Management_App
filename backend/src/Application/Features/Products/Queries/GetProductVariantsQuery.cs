using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Queries;

public sealed record GetProductVariantsQuery(Guid Id) : IRequest<Result<IReadOnlyList<ProductVariantDto>>>;

public sealed class GetProductVariantsQueryHandler
    : IRequestHandler<GetProductVariantsQuery, Result<IReadOnlyList<ProductVariantDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;

    public GetProductVariantsQueryHandler(ITenantContext tenantContext, IProductRepository products)
    {
        _tenantContext = tenantContext;
        _products = products;
    }

    public async Task<Result<IReadOnlyList<ProductVariantDto>>> Handle(
        GetProductVariantsQuery request, CancellationToken cancellationToken)
    {
        var product = await _products.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        return Result.Success<IReadOnlyList<ProductVariantDto>>(
            product.Variants.OrderBy(v => v.Name).Select(ProductMappers.ToVariantDto).ToArray());
    }
}

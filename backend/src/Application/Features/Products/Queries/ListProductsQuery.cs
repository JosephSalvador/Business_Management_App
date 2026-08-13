using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Queries;

public sealed record ListProductsQuery(
    int Page,
    int PageSize,
    string? Search,
    Guid? CategoryId,
    Guid? BrandId,
    ProductType? ProductType,
    ProductStatus? Status) : IRequest<Result<PagedResult<ProductDto>>>;

public sealed class ListProductsQueryHandler
    : IRequestHandler<ListProductsQuery, Result<PagedResult<ProductDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;

    public ListProductsQueryHandler(ITenantContext tenantContext, IProductRepository products)
    {
        _tenantContext = tenantContext;
        _products = products;
    }

    public async Task<Result<PagedResult<ProductDto>>> Handle(
        ListProductsQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var filter = new ProductListFilter(request.Search, request.CategoryId, request.BrandId, request.ProductType, request.Status);

        var products = await _products.ListAsync(tenantId, request.Page, request.PageSize, filter, cancellationToken);
        var total = await _products.CountAsync(tenantId, filter, cancellationToken);

        var items = products.Select(ProductMappers.ToDto).ToList();
        return Result.Success(new PagedResult<ProductDto>(items, request.Page, request.PageSize, total));
    }
}

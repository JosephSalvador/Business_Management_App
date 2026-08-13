using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record ListCategoriesQuery() : IRequest<Result<IReadOnlyList<ProductCategoryDto>>>;

public sealed class ListCategoriesQueryHandler
    : IRequestHandler<ListCategoriesQuery, Result<IReadOnlyList<ProductCategoryDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICategoryRepository _categories;

    public ListCategoriesQueryHandler(ITenantContext tenantContext, ICategoryRepository categories)
    {
        _tenantContext = tenantContext;
        _categories = categories;
    }

    public async Task<Result<IReadOnlyList<ProductCategoryDto>>> Handle(
        ListCategoriesQuery request, CancellationToken cancellationToken)
    {
        var categories = await _categories.ListAsync(_tenantContext.TenantId, cancellationToken);
        return Result.Success<IReadOnlyList<ProductCategoryDto>>(
            categories.Select(CatalogMappers.ToCategoryDto).ToArray());
    }
}

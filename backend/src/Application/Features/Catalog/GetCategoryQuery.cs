using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record GetCategoryQuery(Guid Id) : IRequest<Result<ProductCategoryDto>>;

public sealed class GetCategoryQueryHandler : IRequestHandler<GetCategoryQuery, Result<ProductCategoryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICategoryRepository _categories;

    public GetCategoryQueryHandler(ITenantContext tenantContext, ICategoryRepository categories)
    {
        _tenantContext = tenantContext;
        _categories = categories;
    }

    public async Task<Result<ProductCategoryDto>> Handle(
        GetCategoryQuery request, CancellationToken cancellationToken)
    {
        var category = await _categories.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (category is null)
        {
            return Error.NotFound("Category not found.");
        }

        return Result.Success(CatalogMappers.ToCategoryDto(category));
    }
}

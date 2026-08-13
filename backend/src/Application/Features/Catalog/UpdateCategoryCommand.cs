using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record UpdateCategoryCommand(Guid Id, string Name, Guid? ParentId)
    : IRequest<Result<ProductCategoryDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateCategoryCommandHandler : IRequestHandler<UpdateCategoryCommand, Result<ProductCategoryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICategoryRepository _categories;

    public UpdateCategoryCommandHandler(ITenantContext tenantContext, ICategoryRepository categories)
    {
        _tenantContext = tenantContext;
        _categories = categories;
    }

    public async Task<Result<ProductCategoryDto>> Handle(
        UpdateCategoryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var category = await _categories.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (category is null)
        {
            return Error.NotFound("Category not found.");
        }

        if (await _categories.GetByNameAsync(tenantId, command.Name.Trim(), cancellationToken) is { } owner
            && owner.Id != category.Id)
        {
            return Error.Conflict("A category with this name already exists.");
        }

        if (await ValidateParentAsync(tenantId, category, command.ParentId, cancellationToken) is { } error)
        {
            return error;
        }

        category.UpdateProfile(command.Name, command.ParentId);
        return Result.Success(CatalogMappers.ToCategoryDto(category));
    }

    private async Task<Error?> ValidateParentAsync(
        Guid tenantId,
        ProductCategory category,
        Guid? parentId,
        CancellationToken cancellationToken)
    {
        if (parentId is null)
        {
            return null;
        }

        if (parentId == category.Id)
        {
            return Error.Validation("A category cannot be its own parent.");
        }

        var current = await _categories.GetByIdAsync(tenantId, parentId.Value, cancellationToken);
        if (current is null)
        {
            return Error.Validation("Parent category does not exist in this tenant.");
        }

        var visited = new HashSet<Guid> { category.Id };
        while (current is not null)
        {
            if (!visited.Add(current.Id))
            {
                return Error.Validation("The selected parent would create a category cycle.");
            }

            current = current.ParentId is null
                ? null
                : await _categories.GetByIdAsync(tenantId, current.ParentId.Value, cancellationToken);
        }

        return null;
    }
}

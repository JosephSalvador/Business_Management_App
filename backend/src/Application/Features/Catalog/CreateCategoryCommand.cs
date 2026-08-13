using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record CreateCategoryCommand(string Name, Guid? ParentId)
    : IRequest<Result<ProductCategoryDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateCategoryCommandHandler : IRequestHandler<CreateCategoryCommand, Result<ProductCategoryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICategoryRepository _categories;

    public CreateCategoryCommandHandler(ITenantContext tenantContext, ICategoryRepository categories)
    {
        _tenantContext = tenantContext;
        _categories = categories;
    }

    public async Task<Result<ProductCategoryDto>> Handle(
        CreateCategoryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        if (await _categories.GetByNameAsync(tenantId, command.Name.Trim(), cancellationToken) is not null)
        {
            return Error.Conflict("A category with this name already exists.");
        }

        if (command.ParentId is { } parentId
            && await _categories.GetByIdAsync(tenantId, parentId, cancellationToken) is null)
        {
            return Error.Validation("Parent category does not exist in this tenant.");
        }

        var category = ProductCategory.Create(tenantId, command.Name, command.ParentId);
        await _categories.AddAsync(category, cancellationToken);

        return Result.Success(CatalogMappers.ToCategoryDto(category));
    }
}

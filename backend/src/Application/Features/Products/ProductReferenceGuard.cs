using BusinessOS.Application.Ports;
using BusinessOS.Shared;

namespace BusinessOS.Application.Features.Products;

internal static class ProductReferenceGuard
{
    public static async Task<Error?> EnsureReferencesValidAsync(
        ITenantContext tenantContext,
        ICategoryRepository categories,
        IBrandRepository brands,
        IUnitOfMeasureRepository units,
        ITaxRuleRepository taxRules,
        Guid unitOfMeasureId,
        Guid? categoryId,
        Guid? brandId,
        Guid? taxCategoryId,
        CancellationToken cancellationToken)
    {
        var tenantId = tenantContext.TenantId;

        if (await units.GetByIdAsync(tenantId, unitOfMeasureId, cancellationToken) is null)
        {
            return Error.Validation("Unit of measure does not exist in this tenant.");
        }

        if (categoryId.HasValue
            && await categories.GetByIdAsync(tenantId, categoryId.Value, cancellationToken) is null)
        {
            return Error.Validation("Category does not exist in this tenant.");
        }

        if (brandId.HasValue
            && await brands.GetByIdAsync(tenantId, brandId.Value, cancellationToken) is null)
        {
            return Error.Validation("Brand does not exist in this tenant.");
        }

        if (taxCategoryId.HasValue
            && await taxRules.GetCategoryByIdAsync(taxCategoryId.Value, cancellationToken) is null)
        {
            return Error.Validation("Tax category does not exist.");
        }

        return null;
    }
}

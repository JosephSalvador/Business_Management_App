using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Domain.Catalog;

namespace BusinessOS.Application.Features.Catalog;

internal static class CatalogMappers
{
    public static ProductCategoryDto ToCategoryDto(ProductCategory category) => new(
        category.Id,
        category.TenantId,
        category.Name,
        category.ParentId,
        category.IsActive,
        category.CreatedAt,
        category.UpdatedAt);

    public static BrandDto ToBrandDto(Brand brand) => new(
        brand.Id,
        brand.TenantId,
        brand.Name,
        brand.CreatedAt,
        brand.UpdatedAt);

    public static UnitOfMeasureDto ToUnitDto(UnitOfMeasure unit) => new(
        unit.Id,
        unit.TenantId,
        unit.Name,
        unit.Abbreviation,
        unit.CreatedAt,
        unit.UpdatedAt);
}

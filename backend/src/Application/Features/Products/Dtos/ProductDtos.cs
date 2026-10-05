using BusinessOS.Domain.Catalog;

namespace BusinessOS.Application.Features.Products.Dtos;

public sealed record ProductDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? Description,
    string? Sku,
    string? Barcode,
    Guid? CategoryId,
    Guid? BrandId,
    Guid UnitOfMeasureId,
    ProductType ProductType,
    ProductStatus Status,
    IReadOnlyList<ProductVariantDto> Variants,
    Guid? TaxCategoryId,
    decimal? CostPrice,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record ProductVariantDto(
    Guid Id,
    Guid ProductId,
    string Name,
    string? Sku,
    string? Barcode);

public sealed record ProductVariantInputDto(Guid? Id, string Name, string? Sku, string? Barcode);

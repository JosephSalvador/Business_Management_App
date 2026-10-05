using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Domain.Catalog;

namespace BusinessOS.Application.Features.Products;

internal static class ProductMappers
{
    public static ProductDto ToDto(Product product) => new(
        product.Id,
        product.TenantId,
        product.Name,
        product.Description,
        product.Sku,
        product.Barcode,
        product.CategoryId,
        product.BrandId,
        product.UnitOfMeasureId,
        product.ProductType,
        product.Status,
        product.Variants.Select(ToVariantDto).OrderBy(v => v.Name).ToArray(),
        product.TaxCategoryId,
        product.CostPrice,
        product.CreatedAt,
        product.UpdatedAt);

    public static ProductVariantDto ToVariantDto(ProductVariant variant) => new(
        variant.Id,
        variant.ProductId,
        variant.Name,
        variant.Sku,
        variant.Barcode);

    public static ProductVariantSpec ToSpec(ProductVariantInputDto input) => new(
        input.Id ?? Guid.Empty,
        input.Name.Trim(),
        Product.NormalizeIdentifier(input.Sku),
        Product.NormalizeIdentifier(input.Barcode));
}

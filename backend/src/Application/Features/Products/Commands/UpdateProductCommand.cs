using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Features.Products.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Commands;

public sealed record UpdateProductCommand(
    Guid Id,
    string Name,
    string? Description,
    string? Sku,
    string? Barcode,
    Guid? CategoryId,
    Guid? BrandId,
    Guid UnitOfMeasureId)
    : IRequest<Result<ProductDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateProductCommandHandler : IRequestHandler<UpdateProductCommand, Result<ProductDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;
    private readonly ICategoryRepository _categories;
    private readonly IBrandRepository _brands;
    private readonly IUnitOfMeasureRepository _units;

    public UpdateProductCommandHandler(
        ITenantContext tenantContext,
        IProductRepository products,
        ICategoryRepository categories,
        IBrandRepository brands,
        IUnitOfMeasureRepository units)
    {
        _tenantContext = tenantContext;
        _products = products;
        _categories = categories;
        _brands = brands;
        _units = units;
    }

    public async Task<Result<ProductDto>> Handle(UpdateProductCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var product = await _products.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        if (await ProductReferenceGuard.EnsureReferencesValidAsync(
                _tenantContext, _categories, _brands, _units,
                command.UnitOfMeasureId, command.CategoryId, command.BrandId, cancellationToken) is { } error)
        {
            return error;
        }

        var sku = Product.NormalizeIdentifier(command.Sku);
        var barcode = Product.NormalizeIdentifier(command.Barcode);

        if (product.HasVariants && (sku is not null || barcode is not null))
        {
            return Error.Validation("Products with variants must keep product-level SKU and barcode empty.");
        }

        if (sku is not null
            && await _products.GetBySkuAsync(tenantId, sku, cancellationToken) is { } skuOwner
            && skuOwner.Id != product.Id)
        {
            return Error.Conflict("A product with this SKU already exists.");
        }

        if (barcode is not null
            && await _products.GetByBarcodeAsync(tenantId, barcode, cancellationToken) is { } barcodeOwner
            && barcodeOwner.Id != product.Id)
        {
            return Error.Conflict("A product with this barcode already exists.");
        }

        if (sku is not null
            && await _products.VariantSkuExistsAsync(tenantId, sku, command.Id, cancellationToken))
        {
            return Error.Conflict("A variant with this SKU already exists.");
        }

        if (barcode is not null
            && await _products.VariantBarcodeExistsAsync(tenantId, barcode, command.Id, cancellationToken))
        {
            return Error.Conflict("A variant with this barcode already exists.");
        }

        product.UpdateProfile(command.Name, command.Description, command.CategoryId, command.BrandId, command.UnitOfMeasureId);
        product.UpdateIdentifiers(sku, barcode);

        return Result.Success(ProductMappers.ToDto(product));
    }
}

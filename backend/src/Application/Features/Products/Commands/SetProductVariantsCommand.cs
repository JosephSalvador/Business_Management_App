using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Features.Products.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Commands;

public sealed record SetProductVariantsCommand(
    Guid Id,
    IReadOnlyList<ProductVariantInputDto> Variants)
    : IRequest<Result<IReadOnlyList<ProductVariantDto>>>, IRequiresTenantAdvisoryLock;

public sealed class SetProductVariantsCommandHandler
    : IRequestHandler<SetProductVariantsCommand, Result<IReadOnlyList<ProductVariantDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;

    public SetProductVariantsCommandHandler(ITenantContext tenantContext, IProductRepository products)
    {
        _tenantContext = tenantContext;
        _products = products;
    }

    public async Task<Result<IReadOnlyList<ProductVariantDto>>> Handle(
        SetProductVariantsCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var product = await _products.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        var skus = command.Variants
            .Select(v => Product.NormalizeIdentifier(v.Sku))
            .Where(v => v is not null)
            .ToArray();
        if (skus.Length != skus.Distinct().Count())
        {
            return Error.Validation("Variant SKUs must be unique.");
        }

        var barcodes = command.Variants
            .Select(v => Product.NormalizeIdentifier(v.Barcode))
            .Where(v => v is not null)
            .ToArray();
        if (barcodes.Length != barcodes.Distinct().Count())
        {
            return Error.Validation("Variant barcodes must be unique.");
        }

        foreach (var sku in skus)
        {
            if (await _products.VariantSkuExistsAsync(tenantId, sku!, command.Id, cancellationToken))
            {
                return Error.Conflict("A variant with this SKU already exists.");
            }
        }

        foreach (var barcode in barcodes)
        {
            if (await _products.VariantBarcodeExistsAsync(tenantId, barcode!, command.Id, cancellationToken))
            {
                return Error.Conflict("A variant with this barcode already exists.");
            }
        }

        if (product.Sku is not null || product.Barcode is not null)
        {
            return Error.Validation("Products with variants must keep product-level SKU and barcode empty.");
        }

        product.SetVariants(command.Variants.Select(ProductMappers.ToSpec));

        return Result.Success<IReadOnlyList<ProductVariantDto>>(
            product.Variants.OrderBy(v => v.Name).Select(ProductMappers.ToVariantDto).ToArray());
    }
}

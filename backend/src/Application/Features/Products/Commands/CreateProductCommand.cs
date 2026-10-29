using BusinessOS.Application.Features.Billing;
using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Features.Products.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Commands;

public sealed record CreateProductCommand(
    string Name,
    string? Description,
    string? Sku,
    string? Barcode,
    Guid? CategoryId,
    Guid? BrandId,
    Guid UnitOfMeasureId,
    ProductType ProductType,
    ProductStatus Status = ProductStatus.Draft,
    Guid? TaxCategoryId = null,
    decimal? CostPrice = null,
    Guid? Id = null)
    : IRequest<Result<ProductDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateProductCommandHandler : IRequestHandler<CreateProductCommand, Result<ProductDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;
    private readonly ICategoryRepository _categories;
    private readonly IBrandRepository _brands;
    private readonly IUnitOfMeasureRepository _units;
    private readonly ITaxRuleRepository _taxRules;
    private readonly SubscriptionEntitlementGuard _entitlementGuard;

    public CreateProductCommandHandler(
        ITenantContext tenantContext,
        IProductRepository products,
        ICategoryRepository categories,
        IBrandRepository brands,
        IUnitOfMeasureRepository units,
        ITaxRuleRepository taxRules,
        SubscriptionEntitlementGuard entitlementGuard)
    {
        _tenantContext = tenantContext;
        _products = products;
        _categories = categories;
        _brands = brands;
        _units = units;
        _taxRules = taxRules;
        _entitlementGuard = entitlementGuard;
    }

    public async Task<Result<ProductDto>> Handle(CreateProductCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        if (command.Id.HasValue && command.Id.Value != Guid.Empty)
        {
            var existing = await _products.GetByIdAsync(tenantId, command.Id.Value, cancellationToken);
            if (existing is not null)
            {
                return Result.Success(ProductMappers.ToDto(existing));
            }
        }

        var entitlement = await _entitlementGuard.GetEntitlementAsync(cancellationToken);
        var currentProducts = await _products.CountAsync(
            tenantId, new ProductListFilter(null, null, null, null, null), cancellationToken);
        if (SubscriptionEntitlementGuard.EnsureWithinLimit(
                entitlement.MaxProducts, currentProducts + 1, "products") is { } limitError)
        {
            return limitError;
        }

        if (await ProductReferenceGuard.EnsureReferencesValidAsync(
                _tenantContext, _categories, _brands, _units, _taxRules,
                command.UnitOfMeasureId, command.CategoryId, command.BrandId,
                command.TaxCategoryId, cancellationToken) is { } error)
        {
            return error;
        }

        var sku = Product.NormalizeIdentifier(command.Sku);
        var barcode = Product.NormalizeIdentifier(command.Barcode);

        if (sku is not null)
        {
            var existingBySku = await _products.GetBySkuAsync(tenantId, sku, cancellationToken);
            if (existingBySku is not null)
            {
                if (command.Id.HasValue && existingBySku.Id == command.Id.Value)
                {
                    return Result.Success(ProductMappers.ToDto(existingBySku));
                }
                return Error.Conflict("A product with this SKU already exists.");
            }
        }

        if (barcode is not null)
        {
            var existingByBarcode = await _products.GetByBarcodeAsync(tenantId, barcode, cancellationToken);
            if (existingByBarcode is not null)
            {
                if (command.Id.HasValue && existingByBarcode.Id == command.Id.Value)
                {
                    return Result.Success(ProductMappers.ToDto(existingByBarcode));
                }
                return Error.Conflict("A product with this barcode already exists.");
            }
        }

        if (sku is not null && await _products.VariantSkuExistsAsync(tenantId, sku, cancellationToken: cancellationToken))
        {
            return Error.Conflict("A variant with this SKU already exists.");
        }

        if (barcode is not null && await _products.VariantBarcodeExistsAsync(tenantId, barcode, cancellationToken: cancellationToken))
        {
            return Error.Conflict("A variant with this barcode already exists.");
        }

        var product = Product.Create(
            tenantId,
            command.Name,
            command.Description,
            sku,
            barcode,
            command.CategoryId,
            command.BrandId,
            command.UnitOfMeasureId,
            command.ProductType,
            command.Status,
            command.TaxCategoryId,
            command.CostPrice,
            command.Id);

        await _products.AddAsync(product, cancellationToken);
        return Result.Success(ProductMappers.ToDto(product));
    }
}

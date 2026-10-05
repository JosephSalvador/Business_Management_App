using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Commands;

/// <summary>
/// Ensures the tenant has the POS quick-sale product ("Bila Jina"), creating
/// it lazily on first use. The product is a Service (never debits stock), is
/// excluded from the normal catalogue (reserved SKU + service type), and is
/// priced through the line-level <c>UnitPrice</c> override at sale time, so no
/// price-list row is required.
/// </summary>
public sealed record EnsureQuickSaleProductCommand
    : IRequest<Result<ProductDto>>, IRequiresTenantAdvisoryLock;

public sealed class EnsureQuickSaleProductCommandHandler
    : IRequestHandler<EnsureQuickSaleProductCommand, Result<ProductDto>>
{
    public const string QuickSaleSku = "QS-BILA-JINA";
    public const string QuickSaleName = "Bila Jina";

    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;
    private readonly IUnitOfMeasureRepository _unitsOfMeasure;

    public EnsureQuickSaleProductCommandHandler(
        ITenantContext tenantContext,
        IProductRepository products,
        IUnitOfMeasureRepository unitsOfMeasure)
    {
        _tenantContext = tenantContext;
        _products = products;
        _unitsOfMeasure = unitsOfMeasure;
    }

    public async Task<Result<ProductDto>> Handle(
        EnsureQuickSaleProductCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var existing = await _products.GetBySkuAsync(tenantId, QuickSaleSku, cancellationToken);
        if (existing is not null)
        {
            if (existing.Status != ProductStatus.Active)
            {
                existing.SetStatus(ProductStatus.Active);
            }

            return Result.Success(ProductMappers.ToDto(existing));
        }

        // Products require a unit of measure. Prefer the tenant's canonical
        // "Mara" line; fall back to any existing one; only create when the
        // tenant has no unit of measure at all.
        var unitOfMeasure = await _unitsOfMeasure
            .GetByNameAsync(tenantId, QuickSaleProductDefaults.UnitOfMeasureName, cancellationToken);
        if (unitOfMeasure is null)
        {
            unitOfMeasure = (await _unitsOfMeasure.ListAsync(tenantId, cancellationToken)).FirstOrDefault();
        }

        if (unitOfMeasure is null)
        {
            unitOfMeasure = UnitOfMeasure.Create(
                tenantId,
                QuickSaleProductDefaults.UnitOfMeasureName,
                QuickSaleProductDefaults.UnitOfMeasureName);
            await _unitsOfMeasure.AddAsync(unitOfMeasure, cancellationToken);
        }

        var product = Product.Create(
            tenantId,
            QuickSaleName,
            description: "Quick sale — bila jina, unaweka bei mwenyewe",
            sku: QuickSaleSku,
            barcode: null,
            categoryId: null,
            brandId: null,
            unitOfMeasure.Id,
            ProductType.Service,
            status: ProductStatus.Active);

        await _products.AddAsync(product, cancellationToken);

        return Result.Success(ProductMappers.ToDto(product));
    }
}

/// <summary>Shared defaults for the anonymous quick-sale product.</summary>
public static class QuickSaleProductDefaults
{
    public const string UnitOfMeasureName = "Mara";
}
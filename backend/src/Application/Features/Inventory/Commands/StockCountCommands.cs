using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

// ── Create Stock Count ─────────────────────────────────────────────
public sealed record CreateStockCountCommand(
    Guid WarehouseId,
    Guid? StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    decimal CountedQuantity,
    string? Notes)
    : IRequest<Result<StockCountDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateStockCountCommandHandler
    : IRequestHandler<CreateStockCountCommand, Result<StockCountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IStockCountRepository _counts;

    public CreateStockCountCommandHandler(
        ITenantContext tenantContext,
        IWarehouseRepository warehouses,
        IProductRepository products,
        IStockCountRepository counts)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
        _products = products;
        _counts = counts;
    }

    public async Task<Result<StockCountDto>> Handle(
        CreateStockCountCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var warehouse = await _warehouses.GetByIdAsync(tenantId, command.WarehouseId, cancellationToken);
        if (warehouse is null)
        {
            return Error.NotFound("Warehouse not found.");
        }

        var location = ResolveLocation(warehouse, command.StockLocationId);
        if (location is null)
        {
            return Error.Validation("The stock location does not exist in this warehouse.");
        }

        var product = await _products.GetByIdAsync(tenantId, command.ProductId, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        if (product.ProductType != ProductType.Product)
        {
            return Error.Validation("Only physical products can be counted.");
        }

        if (product.HasVariants)
        {
            if (!command.VariantId.HasValue || product.Variants.All(v => v.Id != command.VariantId.Value))
            {
                return Error.Validation("A variant belonging to the product must be specified.");
            }
        }
        else if (command.VariantId.HasValue)
        {
            return Error.Validation("This product has no variants.");
        }

        var count = StockCount.Create(
            tenantId,
            command.WarehouseId,
            command.StockLocationId,
            command.ProductId,
            command.VariantId,
            command.CountedQuantity,
            command.Notes);

        await _counts.AddAsync(count, cancellationToken);

        return Result.Success(WarehouseMappers.ToStockCountDto(count, warehouse.Name, product.Name));
    }

    private static StockLocation? ResolveLocation(Warehouse warehouse, Guid? stockLocationId)
    {
        if (stockLocationId.HasValue)
        {
            return warehouse.Locations.FirstOrDefault(l => l.Id == stockLocationId.Value);
        }

        return warehouse.Locations.FirstOrDefault(l => l.Code == Warehouse.DefaultLocationCode)
            ?? warehouse.Locations.FirstOrDefault();
    }
}

// ── Complete Stock Count ───────────────────────────────────────────
public sealed record CompleteStockCountCommand(Guid Id)
    : IRequest<Result<StockCountDto>>, IRequiresTenantAdvisoryLock;

public sealed class CompleteStockCountCommandHandler
    : IRequestHandler<CompleteStockCountCommand, Result<StockCountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockCountRepository _counts;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IStockRepository _stock;

    public CompleteStockCountCommandHandler(
        ITenantContext tenantContext,
        IStockCountRepository counts,
        IWarehouseRepository warehouses,
        IProductRepository products,
        IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _counts = counts;
        _warehouses = warehouses;
        _products = products;
        _stock = stock;
    }

    public async Task<Result<StockCountDto>> Handle(
        CompleteStockCountCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var count = await _counts.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (count is null)
        {
            return Error.NotFound("Stock count not found.");
        }

        if (count.Status != CountStatus.Draft)
        {
            return Error.Conflict($"Stock count is already {count.Status}.");
        }

        var warehouse = await _warehouses.GetByIdAsync(tenantId, count.WarehouseId, cancellationToken);
        var locationId = count.StockLocationId
            ?? warehouse?.Locations.FirstOrDefault()?.Id
            ?? throw new InvalidOperationException("Warehouse has no locations.");

        var systemBalance = await _stock.GetBalanceAsync(
            tenantId, count.WarehouseId, locationId,
            count.ProductId, count.VariantId, cancellationToken);

        var systemQuantity = systemBalance?.Quantity ?? 0m;

        count.Complete(systemQuantity, DateTime.UtcNow);

        if (count.Difference != 0)
        {
            var product = await _products.GetByIdAsync(tenantId, count.ProductId, cancellationToken);
            var uomId = product?.UnitOfMeasureId ?? Guid.Empty;
            var branchId = warehouse?.BranchId ?? Guid.Empty;

            var movement = StockMovement.Record(
                tenantId,
                branchId,
                count.WarehouseId,
                locationId,
                count.ProductId,
                count.VariantId,
                StockMovementType.Count,
                count.Difference,
                uomId,
                DateTime.UtcNow,
                referenceType: "StockCount",
                referenceId: count.Id,
                reason: count.Notes,
                createdBy: _tenantContext.UserId);

            await _stock.AddMovementAsync(movement, cancellationToken);

            if (systemBalance is not null)
            {
                systemBalance.Apply(count.Difference);
            }
        }

        await _counts.UpdateAsync(count, cancellationToken);

        var productName = (await _products.GetByIdAsync(tenantId, count.ProductId, cancellationToken))?.Name ?? "Unknown";
        return Result.Success(WarehouseMappers.ToStockCountDto(count, warehouse?.Name ?? "Unknown", productName));
    }
}

// ── Cancel Stock Count ─────────────────────────────────────────────
public sealed record CancelStockCountCommand(Guid Id)
    : IRequest<Result<StockCountDto>>, IRequiresTenantAdvisoryLock;

public sealed class CancelStockCountCommandHandler
    : IRequestHandler<CancelStockCountCommand, Result<StockCountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockCountRepository _counts;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;

    public CancelStockCountCommandHandler(
        ITenantContext tenantContext,
        IStockCountRepository counts,
        IWarehouseRepository warehouses,
        IProductRepository products)
    {
        _tenantContext = tenantContext;
        _counts = counts;
        _warehouses = warehouses;
        _products = products;
    }

    public async Task<Result<StockCountDto>> Handle(
        CancelStockCountCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var count = await _counts.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (count is null)
        {
            return Error.NotFound("Stock count not found.");
        }

        if (count.Status != CountStatus.Draft)
        {
            return Error.Conflict($"Cannot cancel a stock count in {count.Status} status.");
        }

        count.Cancel(DateTime.UtcNow);
        await _counts.UpdateAsync(count, cancellationToken);

        var warehouse = await _warehouses.GetByIdAsync(tenantId, count.WarehouseId, cancellationToken);
        var product = await _products.GetByIdAsync(tenantId, count.ProductId, cancellationToken);

        return Result.Success(WarehouseMappers.ToStockCountDto(
            count, warehouse?.Name ?? "Unknown", product?.Name ?? "Unknown"));
    }
}

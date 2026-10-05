using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

public sealed record AdjustStockCommand(
    Guid WarehouseId,
    Guid? StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    decimal QuantityDelta,
    string Reason,
    DateTime EffectiveAt,
    decimal? UnitCost = null,
    StockReasonType? ReasonType = null,
    Guid? BatchId = null,
    Guid? IdempotencyKey = null)
    : IRequest<Result<StockBalanceDto>>, IRequiresTenantAdvisoryLock;

public sealed class AdjustStockCommandHandler
    : IRequestHandler<AdjustStockCommand, Result<StockBalanceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IUnitOfMeasureRepository _unitsOfMeasure;
    private readonly IStockRepository _stock;

    public AdjustStockCommandHandler(
        ITenantContext tenantContext,
        IWarehouseRepository warehouses,
        IProductRepository products,
        IUnitOfMeasureRepository unitsOfMeasure,
        IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
        _products = products;
        _unitsOfMeasure = unitsOfMeasure;
        _stock = stock;
    }

    public async Task<Result<StockBalanceDto>> Handle(
        AdjustStockCommand command, CancellationToken cancellationToken)
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

        var unitOfMeasure = await _unitsOfMeasure.GetByIdAsync(tenantId, product.UnitOfMeasureId, cancellationToken);

        if (product.ProductType != ProductType.Product)
        {
            return Error.Validation("Only stocked products can have stock adjustments.");
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

        // Idempotent replay: the tenant advisory lock serializes stock commands,
        // so re-submitting the same client id is either a retry after a dropped
        // response (dedupe — never apply twice) or a brand-new request. The key is
        // stored on the adjustment ledger row's CorrelationId.
        var idempotencyKey = command.IdempotencyKey?.ToString();
        if (idempotencyKey is not null)
        {
            var alreadyApplied = await _stock.FindAdjustmentByKeyAsync(
                tenantId, idempotencyKey, cancellationToken);
            if (alreadyApplied is not null)
            {
                var current = await _stock.GetBalanceWithLockAsync(
                    tenantId, warehouse.Id, location.Id, product.Id, command.VariantId, cancellationToken);
                current ??= await _stock.GetOrCreateBalanceAsync(
                    tenantId, warehouse.Id, location.Id, product.Id, command.VariantId, cancellationToken);
                return Result.Success(WarehouseMappers.ToBalanceDto(
                    current,
                    warehouse.Name,
                    location.Name,
                    product.Name,
                    product.Sku,
                    product.Barcode,
                    unitOfMeasure?.Name ?? string.Empty));
            }
        }

        var balance = await _stock.GetBalanceWithLockAsync(
            tenantId, warehouse.Id, location.Id, product.Id, command.VariantId, cancellationToken);

        if (balance is null)
        {
            if (command.QuantityDelta <= 0)
            {
                return Error.Validation("No stock exists at this location to adjust. Record opening stock first.");
            }

            balance = await _stock.GetOrCreateBalanceAsync(
                tenantId, warehouse.Id, location.Id, product.Id, command.VariantId, cancellationToken);
        }

        var projected = balance.Quantity + command.QuantityDelta;
        if (projected < 0)
        {
            return Error.Validation(
                $"Insufficient stock. Current quantity is {balance.Quantity}, " +
                $"cannot adjust by {command.QuantityDelta}.");
        }

        var movement = StockMovement.Record(
            tenantId,
            warehouse.BranchId,
            warehouse.Id,
            location.Id,
            product.Id,
            command.VariantId,
            StockMovementType.Adjustment,
            command.QuantityDelta,
            product.UnitOfMeasureId,
            command.EffectiveAt,
            reason: command.Reason,
            correlationId: idempotencyKey,
            batchId: command.BatchId,
            createdBy: _tenantContext.UserId);

        await _stock.AddMovementAsync(movement, cancellationToken);

        balance.Apply(command.QuantityDelta);

        return Result.Success(WarehouseMappers.ToBalanceDto(
            balance,
            warehouse.Name,
            location.Name,
            product.Name,
            product.Sku,
            product.Barcode,
            unitOfMeasure?.Name ?? string.Empty));
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

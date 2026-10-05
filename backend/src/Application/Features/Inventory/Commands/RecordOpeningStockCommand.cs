using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

public sealed record RecordOpeningStockCommand(
    Guid WarehouseId,
    Guid? StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    decimal Quantity,
    Guid UnitOfMeasureId,
    DateTime EffectiveAt,
    decimal? UnitCost = null,
    string? ReferenceType = null,
    Guid? ReferenceId = null,
    string? Reason = null,
    string? CorrelationId = null,
    Guid? BatchId = null)
    : IRequest<Result<StockBalanceDto>>, IRequiresTenantAdvisoryLock;

public sealed class RecordOpeningStockCommandHandler
    : IRequestHandler<RecordOpeningStockCommand, Result<StockBalanceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IUnitOfMeasureRepository _unitsOfMeasure;
    private readonly IStockRepository _stock;

    public RecordOpeningStockCommandHandler(
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
        RecordOpeningStockCommand command, CancellationToken cancellationToken)
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

        var unitOfMeasure = await _unitsOfMeasure.GetByIdAsync(tenantId, command.UnitOfMeasureId, cancellationToken);
        if (unitOfMeasure is null)
        {
            return Error.Validation("The unit of measure does not exist in this tenant.");
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

        var balance = await _stock.GetBalanceWithLockAsync(
            tenantId, warehouse.Id, location.Id, product.Id, command.VariantId, cancellationToken);
        if (balance is not null)
        {
            return Error.Conflict("Opening stock has already been recorded for this product at this location.");
        }

        var movement = StockMovement.Record(
            tenantId,
            warehouse.BranchId,
            warehouse.Id,
            location.Id,
            product.Id,
            command.VariantId,
            StockMovementType.OpeningStock,
            command.Quantity,
            command.UnitOfMeasureId,
            command.EffectiveAt,
            command.ReferenceType,
            command.ReferenceId,
            command.Reason,
            command.CorrelationId,
            command.BatchId,
            _tenantContext.UserId);

        await _stock.AddMovementAsync(movement, cancellationToken);

        balance = await _stock.GetOrCreateBalanceAsync(
            tenantId, warehouse.Id, location.Id, product.Id, command.VariantId, cancellationToken);
        balance.Apply(command.Quantity);

        return Result.Success(WarehouseMappers.ToBalanceDto(
            balance,
            warehouse.Name,
            location.Name,
            product.Name,
            product.Sku,
            product.Barcode,
            unitOfMeasure.Name));
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

using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;

namespace BusinessOS.Application.Sales;

/// <summary>One line to debit from stock for a sale.</summary>
public sealed record StockDebitLine(
    Guid ProductId,
    Guid? VariantId,
    string ProductName,
    Guid UnitOfMeasureId,
    decimal Quantity,
    bool DebitsStock);

/// <summary>
/// Atomic stock debit for a completed sale. Service lines (<see cref="StockDebitLine.DebitsStock"/>
/// false) are skipped. Every stocked line is debited under a row lock. Stock is advisory — sales
/// are never blocked by low or missing stock; the signed balance may go negative so the seller can
/// see they sold more than they have recorded, while the ledger stays truthful.
/// </summary>
public sealed record StockDebitRequest(
    Guid TenantId,
    Guid BranchId,
    Guid WarehouseId,
    Guid StockLocationId,
    Guid SaleId,
    DateTime OccurredAt,
    Guid? CreatedBy,
    IReadOnlyCollection<StockDebitLine> Lines);

/// <summary>
/// Reusable stock-debit path used by the sale command: locks each balance row
/// (<c>GetBalanceWithLockAsync</c>), creates the balance if it has never been recorded, then
/// writes a <see cref="StockMovementType.Sale"/> ledger row (negative delta, reference = sale id)
/// and debits the balance. Stock never blocks a sale — an oversold balance simply goes negative.
/// </summary>
public sealed class SaleStockDebitService
{
    private readonly IStockRepository _stock;

    public SaleStockDebitService(IStockRepository stock)
    {
        _stock = stock;
    }

    public async Task<Result> DebitAsync(StockDebitRequest request, CancellationToken cancellationToken)
    {
        var stocked = request.Lines.Where(l => l.DebitsStock).ToList();
        if (stocked.Count == 0)
        {
            return Result.Success();
        }

        var locked = new List<(StockDebitLine Line, StockBalance Balance)>(stocked.Count);
        foreach (var line in stocked)
        {
            var balance = await _stock.GetBalanceWithLockAsync(
                request.TenantId,
                request.WarehouseId,
                request.StockLocationId,
                line.ProductId,
                line.VariantId,
                cancellationToken);
            balance ??= await _stock.GetOrCreateBalanceAsync(
                request.TenantId,
                request.WarehouseId,
                request.StockLocationId,
                line.ProductId,
                line.VariantId,
                cancellationToken);

            locked.Add((line, balance));
        }

        foreach (var (line, balance) in locked)
        {
            var movement = StockMovement.Record(
                request.TenantId,
                request.BranchId,
                request.WarehouseId,
                request.StockLocationId,
                line.ProductId,
                line.VariantId,
                StockMovementType.Sale,
                -line.Quantity,
                line.UnitOfMeasureId,
                request.OccurredAt,
                referenceType: "Sale",
                referenceId: request.SaleId,
                createdBy: request.CreatedBy);

            await _stock.AddMovementAsync(movement, cancellationToken);
            balance.Apply(-line.Quantity);
        }

        return Result.Success();
    }

    /// <summary>
    /// Stock add-back for a voided sale: a compensating reversal of the original
    /// <see cref="StockMovementType.Sale"/> rows. Each posted <see cref="StockMovementType.Sale"/>
    /// movement for the sale gets a positive <see cref="StockMovementType.SaleVoid"/> ledger row
    /// (same warehouse/location/product/variant/UoM/quantity, reference = sale id) and the balance
    /// is credited. Add-back can never be insufficient (stock was physically returned), so the
    /// balance is created if missing and no availability check runs.
    /// </summary>
    public async Task RestoreAsync(StockRestoreRequest request, CancellationToken cancellationToken)
    {
        var reversals = new List<(StockMovement Debit, StockBalance Balance)>(request.Movements.Count);
        foreach (var debit in request.Movements)
        {
            var balance = await _stock.GetOrCreateBalanceAsync(
                request.TenantId,
                debit.WarehouseId,
                debit.StockLocationId,
                debit.ProductId,
                debit.VariantId,
                cancellationToken);

            reversals.Add((debit, balance));
        }

        foreach (var (debit, balance) in reversals)
        {
            var movement = StockMovement.Record(
                request.TenantId,
                debit.BranchId,
                debit.WarehouseId,
                debit.StockLocationId,
                debit.ProductId,
                debit.VariantId,
                StockMovementType.SaleVoid,
                -debit.Quantity,
                debit.UnitOfMeasureId,
                request.OccurredAt,
                referenceType: "Sale",
                referenceId: request.SaleId,
                reason: request.Reason,
                createdBy: request.CreatedBy);

            await _stock.AddMovementAsync(movement, cancellationToken);
            balance.Apply(-debit.Quantity);
        }
    }
}

/// <summary>
/// Compensating stock add-back for a voided sale. <see cref="Movements"/> are the original
/// <see cref="StockMovementType.Sale"/> ledger rows of the sale; each is reversed with a positive
/// <see cref="StockMovementType.SaleVoid"/> movement.
/// </summary>
public sealed record StockRestoreRequest(
    Guid TenantId,
    Guid SaleId,
    DateTime OccurredAt,
    Guid? CreatedBy,
    string? Reason,
    IReadOnlyCollection<StockMovement> Movements);

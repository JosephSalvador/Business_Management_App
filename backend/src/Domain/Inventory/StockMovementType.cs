namespace BusinessOS.Domain.Inventory;

/// <summary>
/// Signed-stock ledger operation. Quantity semantics: positive = stock entering a location,
/// negative = stock leaving a location. Corrections are compensating movements, never edits
/// to posted rows.
/// </summary>
public enum StockMovementType
{
    OpeningStock = 0,
    Sale = 1,
    SaleVoid = 2,
    Adjustment = 3,
    TransferIn = 4,
    TransferOut = 5,
    Count = 6,
}

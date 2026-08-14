namespace BusinessOS.Domain.Inventory;

/// <summary>
/// Signed-stock ledger operation. Quantity semantics: positive = stock entering a location,
/// negative = stock leaving a location. Future movement types (adjustment, transfer in/out,
/// sale out, purchase in) are added when their features ship; corrections are compensating
/// movements, never edits to posted rows.
/// </summary>
public enum StockMovementType
{
    OpeningStock = 0,
}

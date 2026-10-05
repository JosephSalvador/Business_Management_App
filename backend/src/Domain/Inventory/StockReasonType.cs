namespace BusinessOS.Domain.Inventory;

/// <summary>
/// Why stock is being increased. Guides the user through the reason at the moment they have the information.
/// </summary>
public enum StockReasonType
{
    Purchase = 0,
    Return = 1,
    OpeningStock = 2,
    Adjustment = 3,
    Transfer = 4,
    Production = 5,
}

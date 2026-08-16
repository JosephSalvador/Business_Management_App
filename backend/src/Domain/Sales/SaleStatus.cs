namespace BusinessOS.Domain.Sales;

/// <summary>
/// Lifecycle state of a sale. Only <see cref="Completed"/> is creatable in the core slice;
/// <see cref="Voided"/> arrives with the void/returns sub-slice.
/// </summary>
public enum SaleStatus
{
    Completed = 0,
    Voided = 1,
}

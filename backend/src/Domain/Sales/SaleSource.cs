namespace BusinessOS.Domain.Sales;

/// <summary>
/// How the sale request arrived: directly online, or offline on the device and synced later.
/// This describes arrival, not state.
/// </summary>
public enum SaleSource
{
    Online = 0,
    Offline = 1,
}

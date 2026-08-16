namespace BusinessOS.Domain.Sales;

/// <summary>
/// How a sale payment was tendered. Payments are data only in this slice — no gateway calls;
/// M-Pesa/Airtel adapters are a future Payments engine slice.
/// </summary>
public enum PaymentMethod
{
    Cash = 0,
    MobileMoney = 1,
    Card = 2,
    BankTransfer = 3,
    Credit = 4,
    Other = 5,
}

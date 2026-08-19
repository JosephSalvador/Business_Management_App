namespace BusinessOS.Domain.Purchasing;

public enum SupplierPaymentMethod
{
    Cash = 0,
    MobileMoney = 1,
    BankTransfer = 2,
    Other = 3,
}

public sealed class SupplierPayment
{
    private SupplierPayment(
        Guid id,
        Guid supplierBillId,
        SupplierPaymentMethod method,
        decimal amount,
        string? provider,
        string? reference,
        string? phoneNumber)
    {
        Id = id;
        SupplierBillId = supplierBillId;
        Method = method;
        Amount = amount;
        Provider = provider;
        Reference = reference;
        PhoneNumber = phoneNumber;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid Id { get; private set; }
    public Guid SupplierBillId { get; private set; }
    public SupplierPaymentMethod Method { get; private set; }
    public decimal Amount { get; private set; }
    public string? Provider { get; private set; }
    public string? Reference { get; private set; }
    public string? PhoneNumber { get; private set; }
    public DateTime CreatedAt { get; private set; }

    public static SupplierPayment Create(
        Guid supplierBillId,
        SupplierPaymentMethod method,
        decimal amount,
        string? provider = null,
        string? reference = null,
        string? phoneNumber = null)
    {
        if (amount <= 0)
        {
            throw new ArgumentException("Payment amount must be positive.", nameof(amount));
        }

        return new SupplierPayment(
            Guid.NewGuid(), supplierBillId, method, amount,
            provider?.Trim(), reference?.Trim(), phoneNumber?.Trim());
    }
}

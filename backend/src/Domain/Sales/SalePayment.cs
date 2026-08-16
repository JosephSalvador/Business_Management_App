using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A tender row on a sale. A sale has 1..N payments and, by the full-payment rule, the sum of
/// the payments equals the sale total at creation. Payments are data only in this slice.
/// </summary>
public sealed class SalePayment : Entity
{
    private SalePayment(
        PaymentMethod method,
        decimal amount,
        string? provider,
        string? phoneNumber,
        string? reference,
        int orderIndex)
    {
        Method = method;
        Amount = amount;
        Provider = provider;
        PhoneNumber = phoneNumber;
        Reference = reference;
        OrderIndex = orderIndex;
    }

    public Guid SaleId { get; private set; }

    public PaymentMethod Method { get; private set; }
    public decimal Amount { get; private set; }
    public string? Provider { get; private set; }
    public string? PhoneNumber { get; private set; }
    public string? Reference { get; private set; }

    public int OrderIndex { get; private set; }

    public static SalePayment Create(
        PaymentMethod method,
        decimal amount,
        string? provider,
        string? phoneNumber,
        string? reference,
        int orderIndex)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Payment amount must be greater than zero.");
        }

        if (orderIndex < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(orderIndex), "Order index cannot be negative.");
        }

        return new SalePayment(
            method,
            amount,
            Normalize(provider),
            Normalize(phoneNumber),
            Normalize(reference),
            orderIndex);
    }

    internal void AttachTo(Guid saleId) => SaleId = saleId;

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

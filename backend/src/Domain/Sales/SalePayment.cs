using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A tender row on a sale. A sale has 1..N payments. Non-credit payments must be
/// positive and, combined, cover the sale total at creation; a CREDIT payment may
/// be zero or partial so the sale goes on the customer's ledger (the unpaid
/// balance is recorded as a ledger transaction). Payments are data only.
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
        if (amount <= 0 && method != PaymentMethod.Credit)
        {
            throw new ArgumentOutOfRangeException(
                nameof(amount), "Payment amount must be greater than zero (credit may be zero).");
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

using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Invoicing;

/// <summary>
/// A customer invoice (what the shop bills its customers), independent of the subscription
/// billing invoices. Issued from the Invoicing package, paid in whole or in part, and
/// voidable while money is still outstanding. It does not move stock or touch POS.
/// </summary>
public sealed class CustomerInvoice : AggregateRoot
{
    private readonly List<CustomerInvoiceLine> _lines = new();

    private CustomerInvoice(
        Guid id,
        Guid tenantId,
        string number,
        Guid? customerId,
        string? customerName,
        string currency,
        DateTime issueDate,
        DateTime? dueDate,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        Number = number;
        CustomerId = customerId;
        CustomerName = customerName;
        Currency = currency;
        IssueDate = issueDate;
        DueDate = dueDate;
        Notes = notes;
        Status = CustomerInvoiceStatus.Unpaid;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public string Number { get; private set; }
    public Guid? CustomerId { get; private set; }
    public string? CustomerName { get; private set; }
    public string Currency { get; private set; }
    public DateTime IssueDate { get; private set; }
    public DateTime? DueDate { get; private set; }
    public string? Notes { get; private set; }
    public CustomerInvoiceStatus Status { get; private set; }
    public decimal Subtotal { get; private set; }
    public decimal TaxAmount { get; private set; }
    public decimal TotalAmount { get; private set; }
    public decimal AmountPaid { get; private set; }
    public decimal BalanceDue => TotalAmount - AmountPaid;
    public string? PaymentMethod { get; private set; }
    public string? PaymentReference { get; private set; }
    public Guid? PaymentRecordedByUserId { get; private set; }
    public DateTime? PaidAtUtc { get; private set; }
    public DateTime? VoidedAtUtc { get; private set; }
    public Guid? VoidedByUserId { get; private set; }
    public IReadOnlyCollection<CustomerInvoiceLine> Lines => _lines;

    public static CustomerInvoice Create(
        Guid tenantId,
        string number,
        IEnumerable<CustomerInvoiceLineSpec> lines,
        Guid? customerId = null,
        string? customerName = null,
        string currency = "TZS",
        DateTime? issueDate = null,
        DateTime? dueDate = null,
        string? notes = null,
        DateTime? nowUtc = null)
    {
        if (string.IsNullOrWhiteSpace(number))
        {
            throw new ArgumentException("Invoice number is required.", nameof(number));
        }

        var specs = lines?.ToList() ?? new List<CustomerInvoiceLineSpec>();
        if (specs.Count == 0)
        {
            throw new ArgumentException("An invoice needs at least one line.", nameof(lines));
        }

        var issued = issueDate ?? (nowUtc ?? DateTime.UtcNow);
        if (dueDate is { } due && due.Date < issued.Date)
        {
            throw new ArgumentException("Due date cannot be before the issue date.", nameof(dueDate));
        }

        var invoice = new CustomerInvoice(
            Guid.NewGuid(),
            tenantId,
            number.Trim(),
            customerId,
            customerName?.Trim(),
            string.IsNullOrWhiteSpace(currency) ? "TZS" : currency.Trim().ToUpperInvariant(),
            issued,
            dueDate,
            notes?.Trim());

        for (var index = 0; index < specs.Count; index++)
        {
            var line = CustomerInvoiceLine.Create(specs[index], index);
            line.CustomerInvoiceId = invoice.Id;
            invoice._lines.Add(line);
        }

        invoice.RecalculateTotals();
        invoice.AddDomainEvent(new CustomerInvoiceIssuedEvent(
            Guid.NewGuid(),
            nowUtc ?? DateTime.UtcNow,
            invoice.Id,
            tenantId,
            invoice.Number,
            invoice.TotalAmount,
            invoice.Currency,
            invoice.CustomerId));
        return invoice;
    }

    public void RecordPayment(
        decimal amount,
        string? method,
        string? reference,
        Guid? recordedByUserId = null,
        DateTime? nowUtc = null)
    {
        if (Status is CustomerInvoiceStatus.Paid or CustomerInvoiceStatus.Void)
        {
            throw new InvalidOperationException(
                $"Cannot record a payment on an invoice that is {Status}.");
        }

        if (amount <= 0)
        {
            throw new ArgumentException("Payment amount must be positive.", nameof(amount));
        }

        if (amount > BalanceDue)
        {
            throw new ArgumentException(
                $"Payment amount ({amount}) exceeds balance due ({BalanceDue}).", nameof(amount));
        }

        var now = nowUtc ?? DateTime.UtcNow;
        AmountPaid += amount;
        PaymentMethod = method?.Trim();
        PaymentReference = reference?.Trim();
        PaymentRecordedByUserId = recordedByUserId;
        Status = AmountPaid >= TotalAmount
            ? CustomerInvoiceStatus.Paid
            : CustomerInvoiceStatus.PartiallyPaid;

        if (Status == CustomerInvoiceStatus.Paid)
        {
            PaidAtUtc = now;
        }

        UpdatedAt = now;

        if (Status == CustomerInvoiceStatus.Paid)
        {
            AddDomainEvent(new CustomerInvoicePaidEvent(
                Guid.NewGuid(),
                now,
                Id,
                TenantId,
                Number,
                AmountPaid,
                Currency,
                PaymentReference));
        }
    }

    public void Void(Guid? voidedByUserId = null, DateTime? nowUtc = null)
    {
        if (Status == CustomerInvoiceStatus.Void)
        {
            throw new InvalidOperationException("This invoice is already void.");
        }

        if (Status == CustomerInvoiceStatus.Paid)
        {
            throw new InvalidOperationException("Cannot void a fully paid invoice.");
        }

        var now = nowUtc ?? DateTime.UtcNow;
        Status = CustomerInvoiceStatus.Void;
        VoidedAtUtc = now;
        VoidedByUserId = voidedByUserId;
        UpdatedAt = now;

        AddDomainEvent(new CustomerInvoiceVoidedEvent(
            Guid.NewGuid(),
            now,
            Id,
            TenantId,
            Number,
            TotalAmount,
            Currency));
    }

    private void RecalculateTotals()
    {
        Subtotal = decimal.Round(_lines.Sum(line => line.LineTotal), 2);
        TaxAmount = decimal.Round(_lines.Sum(line => line.TaxAmount), 2);
        TotalAmount = Subtotal + TaxAmount;
    }
}

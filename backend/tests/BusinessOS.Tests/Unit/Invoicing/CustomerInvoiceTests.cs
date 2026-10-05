using BusinessOS.Domain.Events;
using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Tests.Unit.Invoicing;

public sealed class CustomerInvoiceTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 9, 20, 10, 0, 0, DateTimeKind.Utc);

    private static CustomerInvoiceLineSpec Line(
        string description = "Fitting",
        decimal quantity = 2m,
        decimal unitPrice = 50_000m,
        decimal taxRatePercent = 0m)
        => new(description, quantity, unitPrice, taxRatePercent);

    private static CustomerInvoice CreateInvoice(
        IEnumerable<CustomerInvoiceLineSpec>? lines = null,
        DateTime? dueDate = null)
        => CustomerInvoice.Create(
            TenantId,
            "CI-2026-0001",
            lines ?? new[] { Line() },
            customerId: null,
            customerName: null,
            currency: "TZS",
            issueDate: Now,
            dueDate: dueDate,
            notes: null,
            nowUtc: Now);

    [Fact]
    public void Create_CalculatesSubtotalTaxAndTotal()
    {
        var invoice = CreateInvoice(new[]
        {
            Line("Fitting", 2m, 50_000m),
            Line("Labour", 1m, 20_000m, 18m),
        });

        Assert.Equal("CI-2026-0001", invoice.Number);
        Assert.Equal("TZS", invoice.Currency);
        Assert.Equal(CustomerInvoiceStatus.Unpaid, invoice.Status);
        Assert.Equal(120_000m, invoice.Subtotal);
        Assert.Equal(3_600m, invoice.TaxAmount);
        Assert.Equal(123_600m, invoice.TotalAmount);
        Assert.Equal(0m, invoice.AmountPaid);
        Assert.Equal(123_600m, invoice.BalanceDue);
        Assert.Equal(2, invoice.Lines.Count);
    }

    [Fact]
    public void Create_NumbersLinesInOrder()
    {
        var invoice = CreateInvoice(new[]
        {
            Line("First"),
            Line("Second"),
            Line("Third"),
        });

        Assert.Equal(new[] { 0, 1, 2 }, invoice.Lines.OrderBy(l => l.OrderIndex).Select(l => l.OrderIndex));
        Assert.All(invoice.Lines, line => Assert.Equal(invoice.Id, line.CustomerInvoiceId));
    }

    [Fact]
    public void Create_RaisesInvoiceIssuedEvent()
    {
        var invoice = CreateInvoice();

        var issued = Assert.Single(invoice.DomainEvents.OfType<CustomerInvoiceIssuedEvent>());
        Assert.Equal(TenantId, issued.TenantId);
        Assert.Equal(invoice.Id, issued.CustomerInvoiceId);
        Assert.Equal("CI-2026-0001", issued.InvoiceNumber);
        Assert.Equal(100_000m, issued.TotalAmount);
        Assert.Equal("TZS", issued.Currency);
    }

    [Fact]
    public void Create_WithoutLines_Throws()
    {
        var exception = Assert.Throws<ArgumentException>(() =>
            CustomerInvoice.Create(TenantId, "CI-2026-0002", Array.Empty<CustomerInvoiceLineSpec>()));

        Assert.Equal("lines", exception.ParamName);
    }

    [Fact]
    public void Create_WithBlankNumber_Throws()
    {
        var exception = Assert.Throws<ArgumentException>(() =>
            CustomerInvoice.Create(TenantId, "   ", new[] { Line() }));

        Assert.Equal("number", exception.ParamName);
    }

    [Fact]
    public void Create_WithDueDateBeforeIssueDate_Throws()
    {
        var exception = Assert.Throws<ArgumentException>(() =>
            CreateInvoice(dueDate: Now.AddDays(-1)));

        Assert.Equal("dueDate", exception.ParamName);
    }

    [Fact]
    public void Create_WithZeroQuantityLine_Throws()
    {
        var exception = Assert.Throws<ArgumentException>(() =>
            CreateInvoice(new[] { Line(quantity: 0m) }));

        Assert.Equal("spec", exception.ParamName);
    }

    [Fact]
    public void Create_WithNegativePrice_Throws()
    {
        var exception = Assert.Throws<ArgumentException>(() =>
            CreateInvoice(new[] { Line(unitPrice: -1m) }));

        Assert.Equal("spec", exception.ParamName);
    }

    [Fact]
    public void Create_WithBlankDescription_Throws()
    {
        var exception = Assert.Throws<ArgumentException>(() =>
            CreateInvoice(new[] { Line(description: "  ") }));

        Assert.Equal("spec", exception.ParamName);
    }

    [Fact]
    public void Create_WithTaxRateAboveHundred_Throws()
    {
        var exception = Assert.Throws<ArgumentException>(() =>
            CreateInvoice(new[] { Line(taxRatePercent: 120m) }));

        Assert.Equal("spec", exception.ParamName);
    }

    [Fact]
    public void RecordPayment_Partially_SetsPartiallyPaidStatus()
    {
        var invoice = CreateInvoice(new[] { Line(quantity: 1m, unitPrice: 100_000m) });

        invoice.RecordPayment(40_000m, "M-PESA", "MPESA-1", UserId, Now.AddDays(1));

        Assert.Equal(CustomerInvoiceStatus.PartiallyPaid, invoice.Status);
        Assert.Equal(40_000m, invoice.AmountPaid);
        Assert.Equal(60_000m, invoice.BalanceDue);
        Assert.Equal("M-PESA", invoice.PaymentMethod);
        Assert.Equal("MPESA-1", invoice.PaymentReference);
        Assert.Equal(UserId, invoice.PaymentRecordedByUserId);
        Assert.Null(invoice.PaidAtUtc);
    }

    [Fact]
    public void RecordPayment_InFull_SetsPaidStatusAndRaisesPaidEvent()
    {
        var invoice = CreateInvoice(new[] { Line(quantity: 1m, unitPrice: 100_000m) });

        invoice.RecordPayment(60_000m, "Cash", null, UserId, Now.AddDays(1));
        Assert.Equal(CustomerInvoiceStatus.PartiallyPaid, invoice.Status);

        invoice.RecordPayment(40_000m, "Cash", null, UserId, Now.AddDays(2));

        Assert.Equal(CustomerInvoiceStatus.Paid, invoice.Status);
        Assert.Equal(100_000m, invoice.AmountPaid);
        Assert.Equal(0m, invoice.BalanceDue);
        Assert.Equal(Now.AddDays(2), invoice.PaidAtUtc);

        var paid = Assert.Single(invoice.DomainEvents.OfType<CustomerInvoicePaidEvent>());
        Assert.Equal(100_000m, paid.AmountPaid);
        Assert.Equal(invoice.Id, paid.CustomerInvoiceId);
    }

    [Fact]
    public void RecordPayment_OverBalance_Throws()
    {
        var invoice = CreateInvoice(new[] { Line(quantity: 1m, unitPrice: 100_000m) });

        var exception = Assert.Throws<ArgumentException>(() =>
            invoice.RecordPayment(100_000.01m, "Cash", null, UserId, Now));

        Assert.Equal("amount", exception.ParamName);
        Assert.Equal(CustomerInvoiceStatus.Unpaid, invoice.Status);
        Assert.Equal(0m, invoice.AmountPaid);
    }

    [Fact]
    public void RecordPayment_NonPositive_Throws()
    {
        var invoice = CreateInvoice();

        Assert.Throws<ArgumentException>(() => invoice.RecordPayment(0m, "Cash", null, UserId, Now));
        Assert.Throws<ArgumentException>(() => invoice.RecordPayment(-10m, "Cash", null, UserId, Now));
    }

    [Fact]
    public void RecordPayment_AfterVoid_Throws()
    {
        var invoice = CreateInvoice();
        invoice.Void(UserId, Now);

        Assert.Throws<InvalidOperationException>(() =>
            invoice.RecordPayment(1_000m, "Cash", null, UserId, Now));
    }

    [Fact]
    public void Void_WithOutstandingBalance_SetsVoidStatusAndRaisesEvent()
    {
        var invoice = CreateInvoice();
        invoice.RecordPayment(10_000m, "Cash", null, UserId, Now);
        invoice.Void(UserId, Now.AddHours(2));

        Assert.Equal(CustomerInvoiceStatus.Void, invoice.Status);
        Assert.Equal(UserId, invoice.VoidedByUserId);
        Assert.Equal(Now.AddHours(2), invoice.VoidedAtUtc);
        Assert.Single(invoice.DomainEvents.OfType<CustomerInvoiceVoidedEvent>());
    }

    [Fact]
    public void Void_WhenPaid_Throws()
    {
        var invoice = CreateInvoice(new[] { Line(quantity: 1m, unitPrice: 100_000m) });
        invoice.RecordPayment(100_000m, "Cash", null, UserId, Now);

        Assert.Throws<InvalidOperationException>(() => invoice.Void(UserId, Now));
    }

    [Fact]
    public void Void_Twice_Throws()
    {
        var invoice = CreateInvoice();
        invoice.Void(UserId, Now);

        Assert.Throws<InvalidOperationException>(() => invoice.Void(UserId, Now));
    }
}

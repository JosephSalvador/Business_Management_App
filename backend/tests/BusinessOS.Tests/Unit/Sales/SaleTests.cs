using BusinessOS.Domain.Events;
using BusinessOS.Domain.Sales;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class SaleTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid BranchId = Guid.NewGuid();
    private static readonly Guid CashierId = Guid.NewGuid();
    private static readonly Guid ClientSaleId = Guid.NewGuid();
    private static readonly DateTime OnDate = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

    private static SaleLine Line(
        decimal quantity = 1m,
        decimal unitPrice = 1000m,
        decimal discountAmount = 0m,
        Guid? variantId = null,
        Guid? appliedRuleId = null,
        decimal baseAmount = 847.46m,
        decimal taxAmount = 152.54m)
        => SaleLine.Create(
            productId: Guid.NewGuid(),
            variantId,
            productName: "Rice 1kg",
            sku: "RICE-1KG",
            barcode: null,
            unitOfMeasureId: Guid.NewGuid(),
            unitOfMeasureName: "kg",
            quantity,
            unitPrice,
            discountAmount,
            taxCode: "A",
            appliedRate: 0.18m,
            appliedRuleId,
            baseAmount,
            taxAmount,
            lineTotal: baseAmount + taxAmount,
            orderIndex: 0);

    private static SalePayment Payment(decimal amount = 1000m, PaymentMethod method = PaymentMethod.Cash)
        => SalePayment.Create(method, amount, provider: null, phoneNumber: null, reference: null, orderIndex: 0);

    private static Sale CreateSale(
        IReadOnlyCollection<SaleLine>? lines = null,
        IReadOnlyCollection<SalePayment>? payments = null,
        decimal? subtotal = null,
        decimal? discountAmount = null,
        decimal? taxAmount = null,
        decimal? totalAmount = null,
        decimal? amountPaid = null,
        decimal? change = null,
        decimal lineDiscount = 0m,
        decimal paid = 1000m)
    {
        var resolvedLines = lines ?? new[] { Line(discountAmount: lineDiscount) };
        var resolvedPayments = payments ?? new[] { Payment(paid) };

        var computedSubtotal = resolvedLines.Sum(l => Math.Round(l.UnitPrice * l.Quantity, 2, MidpointRounding.AwayFromZero));
        var computedDiscount = resolvedLines.Sum(l => l.DiscountAmount);
        var computedTax = resolvedLines.Sum(l => l.TaxAmount);
        var computedTotal = resolvedLines.Sum(l => l.LineTotal - l.DiscountAmount);
        var computedPaid = resolvedPayments.Sum(p => p.Amount);

        return Sale.Create(
            TenantId,
            BranchId,
            warehouseId: null,
            CashierId,
            ClientSaleId,
            number: "SALE-000001",
            SaleSource.Online,
            OnDate,
            effectiveAt: OnDate,
            currency: "TZS",
            priceListId: null,
            isPriceTaxInclusive: true,
            isElectronicPayment: false,
            customerId: null,
            customerName: null,
            customerTin: null,
            isVatRegistered: null,
            subtotal: subtotal ?? computedSubtotal,
            discountAmount: discountAmount ?? computedDiscount,
            taxAmount: taxAmount ?? computedTax,
            totalAmount: totalAmount ?? computedTotal,
            amountPaid: amountPaid ?? computedPaid,
            change: change ?? computedPaid - computedTotal,
            resolvedLines,
            resolvedPayments);
    }

    [Fact]
    public void Create_WithValidLinesAndFullPayment_Completes()
    {
        var sale = CreateSale();

        Assert.Equal(SaleStatus.Completed, sale.Status);
        Assert.Equal(SaleSource.Online, sale.Source);
        Assert.Equal("SALE-000001", sale.Number);
        Assert.Equal(TenantId, sale.TenantId);
        Assert.Equal(BranchId, sale.BranchId);
        Assert.Equal(CashierId, sale.CashierId);
        Assert.Equal(ClientSaleId, sale.ClientSaleId);
        Assert.Equal(OnDate, sale.SaleDate);
        Assert.Equal(OnDate, sale.EffectiveAt);
        Assert.Equal(1000m, sale.Subtotal);
        Assert.Equal(0m, sale.DiscountAmount);
        Assert.Equal(152.54m, sale.TaxAmount);
        Assert.Equal(1000m, sale.TotalAmount);
        Assert.Equal(1000m, sale.AmountPaid);
        Assert.Equal(0m, sale.Change);
        Assert.Single(sale.Lines);
        Assert.Single(sale.Payments);
        Assert.All(sale.Lines, l => Assert.Equal(sale.Id, l.SaleId));
    }

    [Fact]
    public void Create_AttachesLinesAndPaymentsAndRaisesEvent()
    {
        var sale = CreateSale();

        var events = sale.DomainEvents.OfType<SaleCompletedEvent>().ToList();
        Assert.Single(events);

        var completed = events[0];
        Assert.Equal(sale.Id, completed.SaleId);
        Assert.Equal(TenantId, completed.TenantId);
        Assert.Equal(BranchId, completed.BranchId);
        Assert.Equal(CashierId, completed.CashierId);
        Assert.Equal(ClientSaleId, completed.ClientSaleId);
        Assert.Equal("SALE-000001", completed.Number);
        Assert.Equal("TZS", completed.Currency);
        Assert.Equal(1000m, completed.TotalAmount);
        Assert.Equal(152.54m, completed.TaxAmount);
        Assert.NotEqual(Guid.Empty, completed.EventId);
    }

    [Fact]
    public void Create_EmptyLines_Throws()
    {
        Assert.Throws<ArgumentException>(() => CreateSale(lines: Array.Empty<SaleLine>()));
    }

    [Fact]
    public void Create_EmptyPayments_Throws()
    {
        Assert.Throws<ArgumentException>(() => CreateSale(payments: Array.Empty<SalePayment>()));
    }

    [Fact]
    public void Create_NonPositiveQuantity_Throws()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => Line(quantity: 0m));
        Assert.Throws<ArgumentOutOfRangeException>(() => Line(quantity: -1m));
    }

    [Fact]
    public void Create_OffByOneCentSubtotal_Throws()
    {
        Assert.Throws<InvalidOperationException>(() => CreateSale(subtotal: 999.99m));
    }

    [Fact]
    public void Create_OffByOneCentTax_Throws()
    {
        Assert.Throws<InvalidOperationException>(() => CreateSale(taxAmount: 152.53m));
    }

    [Fact]
    public void Create_PaymentsNotEqualTotal_Throws()
    {
        Assert.Throws<InvalidOperationException>(() => CreateSale(amountPaid: 999.99m));
    }

    [Fact]
    public void Create_ChangeMismatch_Throws()
    {
        Assert.Throws<InvalidOperationException>(() => CreateSale(change: 0.01m));
    }

    [Fact]
    public void Create_PaymentsSumMismatch_Throws()
    {
        Assert.Throws<InvalidOperationException>(() => CreateSale(
            payments: new[] { Payment(600m), Payment(400m) },
            amountPaid: 999.99m));
    }

    [Fact]
    public void Create_WithSplitCashAndMobileMoney_Reconciles()
    {
        var sale = CreateSale(
            payments: new[] { Payment(700m), Payment(300m, PaymentMethod.MobileMoney) });

        Assert.Equal(1000m, sale.AmountPaid);
        Assert.Equal(0m, sale.Change);
        Assert.Equal(2, sale.Payments.Count);
        Assert.Equal(PaymentMethod.MobileMoney, sale.Payments.Last().Method);
    }

    [Fact]
    public void Create_WithLineDiscount_KeepsLineTotalPreDiscount()
    {
        var sale = CreateSale(lineDiscount: 50m, paid: 950m);

        Assert.Equal(50m, sale.DiscountAmount);
        Assert.Equal(1000m, sale.Subtotal);
        Assert.Equal(950m, sale.TotalAmount);
        Assert.Equal(1000m, sale.Lines.Single().LineTotal);
        Assert.Equal(950m, sale.AmountPaid);
        Assert.Equal(0m, sale.Change);
    }

    [Fact]
    public void Create_FractionalQuantity_RoundsPerLine()
    {
        var line = SaleLine.Create(
            productId: Guid.NewGuid(),
            variantId: null,
            productName: "Rice 1kg",
            sku: null,
            barcode: null,
            unitOfMeasureId: Guid.NewGuid(),
            unitOfMeasureName: "kg",
            quantity: 0.5m,
            unitPrice: 1.05m,
            discountAmount: 0m,
            taxCode: "A",
            appliedRate: 0.18m,
            appliedRuleId: null,
            baseAmount: 0.45m,
            taxAmount: 0.08m,
            lineTotal: 0.53m,
            orderIndex: 0);

        var sale = CreateSale(
            lines: new[] { line },
            payments: new[] { Payment(0.53m) },
            subtotal: 0.53m,
            discountAmount: 0m,
            taxAmount: 0.08m,
            totalAmount: 0.53m,
            amountPaid: 0.53m,
            change: 0m);

        Assert.Equal(0.53m, sale.TotalAmount);
        Assert.Equal(0.53m, sale.Lines.Single().LineTotal);
    }

    [Fact]
    public void Create_FiscalPlaceholdersDefaultToNotApplicable()
    {
        var sale = CreateSale();

        Assert.Equal(FiscalStatus.NotApplicable, sale.FiscalStatus);
        Assert.Null(sale.BuyerTin);
        Assert.Null(sale.BuyerName);
        Assert.Null(sale.BuyerIdType);
        Assert.Null(sale.BuyerMobile);
        Assert.Null(sale.FiscalReceiptNumber);
        Assert.Null(sale.FiscalVerificationCode);
        Assert.Null(sale.FiscalZNumber);
        Assert.Null(sale.FiscalDailyCounter);
        Assert.Null(sale.VoidedAt);
        Assert.Null(sale.VoidedBy);
        Assert.Null(sale.VoidReason);
    }

    [Fact]
    public void Create_RejectsMissingIdsAndNumber()
    {
        Assert.Throws<ArgumentException>(() =>
            Sale.Create(
                Guid.Empty, BranchId, null, CashierId, ClientSaleId, "SALE-000001",
                SaleSource.Online, OnDate, OnDate, "TZS", null, true, false,
                null, null, null, null, 1000m, 0m, 152.54m, 1000m, 1000m, 0m,
                new[] { Line() }, new[] { Payment() }));

        Assert.Throws<ArgumentException>(() =>
            Sale.Create(
                TenantId, BranchId, null, CashierId, ClientSaleId, "   ",
                SaleSource.Online, OnDate, OnDate, "TZS", null, true, false,
                null, null, null, null, 1000m, 0m, 152.54m, 1000m, 1000m, 0m,
                new[] { Line() }, new[] { Payment() }));
    }

    [Fact]
    public void Line_LineTotalMustEqualBasePlusTax_Throws()
    {
        Assert.Throws<ArgumentException>(() => SaleLine.Create(
            Guid.NewGuid(), null, "Rice 1kg", null, null, Guid.NewGuid(), "kg",
            1m, 1000m, 0m, "A", 0.18m, null, 800m, 200m, 1001m, 0));
    }

    [Fact]
    public void Line_RejectsBlankTaxCode()
    {
        Assert.Throws<ArgumentException>(() => SaleLine.Create(
            Guid.NewGuid(), null, "Rice 1kg", null, null, Guid.NewGuid(), "kg",
            1m, 1000m, 0m, " ", 0.18m, null, 847.46m, 152.54m, 1000m, 0));
    }

    [Fact]
    public void Line_RejectsInvalidAppliedRate()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => SaleLine.Create(
            Guid.NewGuid(), null, "Rice 1kg", null, null, Guid.NewGuid(), "kg",
            1m, 1000m, 0m, "A", 1.01m, null, 847.46m, 152.54m, 1000m, 0));
    }

    [Fact]
    public void Payment_RejectsNonPositiveAmount()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => Payment(0m));
        Assert.Throws<ArgumentOutOfRangeException>(() => Payment(-1m));
    }

    [Fact]
    public void Void_CompletedSale_TransitionsToVoided()
    {
        var sale = CreateSale();
        var voidedBy = Guid.NewGuid();
        var occurredAt = new DateTime(2026, 8, 16, 9, 30, 0, DateTimeKind.Utc);

        sale.Void("Wrong item rung up", voidedBy, occurredAt);

        Assert.Equal(SaleStatus.Voided, sale.Status);
        Assert.Equal(occurredAt, sale.VoidedAt);
        Assert.Equal(voidedBy, sale.VoidedBy);
        Assert.Equal("Wrong item rung up", sale.VoidReason);
    }

    [Fact]
    public void Void_RaisesSaleVoidedEvent()
    {
        var sale = CreateSale();
        var voidedBy = Guid.NewGuid();

        sale.Void("Cancelled by customer", voidedBy, new DateTime(2026, 8, 16, 9, 30, 0, DateTimeKind.Utc));

        var @event = Assert.Single(sale.DomainEvents.OfType<SaleVoidedEvent>());
        Assert.Equal(sale.Id, @event.SaleId);
        Assert.Equal(TenantId, @event.TenantId);
        Assert.Equal(BranchId, @event.BranchId);
        Assert.Equal(voidedBy, @event.VoidedBy);
        Assert.Equal("SALE-000001", @event.Number);
        Assert.Equal("TZS", @event.Currency);
        Assert.Equal(1000m, @event.TotalAmount);
        Assert.Equal("Cancelled by customer", @event.Reason);
        Assert.NotEqual(Guid.Empty, @event.EventId);
    }

    [Fact]
    public void Void_AlreadyVoided_Throws()
    {
        var sale = CreateSale();
        sale.Void("First reason", Guid.NewGuid(), new DateTime(2026, 8, 16, 9, 30, 0, DateTimeKind.Utc));

        Assert.Throws<InvalidOperationException>(
            () => sale.Void("Second reason", Guid.NewGuid(), new DateTime(2026, 8, 16, 10, 0, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void Void_NormalizesReason()
    {
        var sale = CreateSale();
        sale.Void("  Wrong item  ", Guid.NewGuid(), new DateTime(2026, 8, 16, 9, 30, 0, DateTimeKind.Utc));

        Assert.Equal("Wrong item", sale.VoidReason);
    }

    [Fact]
    public void Void_BlankReason_Throws()
    {
        var sale = CreateSale();
        Assert.Throws<ArgumentException>(
            () => sale.Void("   ", Guid.NewGuid(), new DateTime(2026, 8, 16, 9, 30, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void Void_EmptyVoidedBy_Throws()
    {
        var sale = CreateSale();
        Assert.Throws<ArgumentException>(
            () => sale.Void("Reason", Guid.Empty, new DateTime(2026, 8, 16, 9, 30, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void Void_DefaultOccurredAt_Throws()
    {
        var sale = CreateSale();
        Assert.Throws<ArgumentException>(() => sale.Void("Reason", Guid.NewGuid(), default));
    }
}

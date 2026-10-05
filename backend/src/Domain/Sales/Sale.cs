using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A completed point-of-sale sale: one tenant, one branch, one cashier. The header is a dumb
/// aggregator of its lines — it never computes tax itself. All money is server-resolved from
/// resolved lines and must reconcile exactly; a mismatch is a programmer error, not a user path.
/// The <see cref="Number"/> (receipt sequence) is immutable and server-issued. Fiscal placeholders
/// are written only by the tenant's fiscal adapter (async outbox consumer); a standard tenant
/// keeps them null and <see cref="FiscalStatus.NotApplicable"/>.
/// </summary>
public sealed class Sale : AggregateRoot
{
    private readonly List<SaleLine> _lines = new();
    private readonly List<SalePayment> _payments = new();

    private Sale(
        Guid id,
        Guid tenantId,
        Guid branchId,
        Guid? warehouseId,
        Guid cashierId,
        Guid clientSaleId,
        string number,
        SaleSource source,
        DateTime saleDate,
        DateTime effectiveAt,
        string currency,
        Guid? priceListId,
        bool isPriceTaxInclusive,
        bool isElectronicPayment,
        Guid? customerId,
        string? customerName,
        string? customerTin,
        bool? isVatRegistered,
        decimal subtotal,
        decimal discountAmount,
        decimal taxAmount,
        decimal totalAmount,
        decimal amountPaid,
        decimal change,
        string? buyerTin,
        string? buyerName,
        string? buyerIdType,
        string? buyerMobile,
        string? fiscalReceiptNumber,
        string? fiscalVerificationCode,
        string? fiscalZNumber,
        int? fiscalDailyCounter,
        FiscalStatus fiscalStatus)
        : base(id)
    {
        TenantId = tenantId;
        BranchId = branchId;
        WarehouseId = warehouseId;
        CashierId = cashierId;
        ClientSaleId = clientSaleId;
        Number = number;
        Source = source;
        SaleDate = saleDate;
        EffectiveAt = effectiveAt;
        Currency = currency;
        PriceListId = priceListId;
        IsPriceTaxInclusive = isPriceTaxInclusive;
        IsElectronicPayment = isElectronicPayment;
        CustomerId = customerId;
        CustomerName = customerName;
        CustomerTin = customerTin;
        IsVatRegistered = isVatRegistered;
        Subtotal = subtotal;
        DiscountAmount = discountAmount;
        TaxAmount = taxAmount;
        TotalAmount = totalAmount;
        AmountPaid = amountPaid;
        Change = change;
        BuyerTin = buyerTin;
        BuyerName = buyerName;
        BuyerIdType = buyerIdType;
        BuyerMobile = buyerMobile;
        FiscalReceiptNumber = fiscalReceiptNumber;
        FiscalVerificationCode = fiscalVerificationCode;
        FiscalZNumber = fiscalZNumber;
        FiscalDailyCounter = fiscalDailyCounter;
        FiscalStatus = fiscalStatus;
    }

    public Guid TenantId { get; private set; }
    public Guid BranchId { get; private set; }
    public Guid? WarehouseId { get; private set; }
    public Guid CashierId { get; private set; }

    /// <summary>Client-generated idempotency key, unique per tenant.</summary>
    public Guid ClientSaleId { get; private set; }

    /// <summary>Immutable receipt sequence issued by the server (Numbering).</summary>
    public string Number { get; private set; }

    public SaleSource Source { get; private set; }

    /// <summary>Only <see cref="SaleStatus.Completed"/> is creatable; void is a follow-up.</summary>
    public SaleStatus Status { get; private set; } = SaleStatus.Completed;

    public DateTime SaleDate { get; private set; }
    public DateTime EffectiveAt { get; private set; }

    public string Currency { get; private set; }
    public Guid? PriceListId { get; private set; }
    public bool IsPriceTaxInclusive { get; private set; }
    public bool IsElectronicPayment { get; private set; }

    public Guid? CustomerId { get; private set; }
    public string? CustomerName { get; private set; }
    public string? CustomerTin { get; private set; }
    public bool? IsVatRegistered { get; private set; }

    public decimal Subtotal { get; private set; }
    public decimal DiscountAmount { get; private set; }
    public decimal TaxAmount { get; private set; }
    public decimal TotalAmount { get; private set; }
    public decimal AmountPaid { get; private set; }
    public decimal Change { get; private set; }

    public DateTime? VoidedAt { get; private set; }
    public Guid? VoidedBy { get; private set; }
    public string? VoidReason { get; private set; }

    public string? BuyerTin { get; private set; }
    public string? BuyerName { get; private set; }
    public string? BuyerIdType { get; private set; }
    public string? BuyerMobile { get; private set; }

    public string? FiscalReceiptNumber { get; private set; }
    public string? FiscalVerificationCode { get; private set; }
    public string? FiscalZNumber { get; private set; }
    public int? FiscalDailyCounter { get; private set; }
    public FiscalStatus FiscalStatus { get; private set; }

    public IReadOnlyCollection<SaleLine> Lines => _lines.AsReadOnly();
    public IReadOnlyCollection<SalePayment> Payments => _payments.AsReadOnly();

    /// <summary>
    /// Creates a completed sale. <paramref name="subtotal"/>, <paramref name="discountAmount"/>,
    /// <paramref name="taxAmount"/>, <paramref name="totalAmount"/>, <paramref name="amountPaid"/>
    /// and <paramref name="change"/> are supplied by the caller (server-computed from resolved
    /// lines) and must reconcile exactly with the lines and payments:
    /// Subtotal = Σ Round(unitPrice × quantity); DiscountAmount = Σ line discount;
    /// TaxAmount = Σ line tax; TotalAmount = Σ (lineTotal − discount) = Subtotal − DiscountAmount;
    /// AmountPaid = Σ payments; Change = AmountPaid − TotalAmount (≥ 0; a cash tender may
    /// overpay so the cashier can give change, but underpayment is never allowed).
    /// </summary>
    public static Sale Create(
        Guid tenantId,
        Guid branchId,
        Guid? warehouseId,
        Guid cashierId,
        Guid clientSaleId,
        string number,
        SaleSource source,
        DateTime saleDate,
        DateTime effectiveAt,
        string currency,
        Guid? priceListId,
        bool isPriceTaxInclusive,
        bool isElectronicPayment,
        Guid? customerId,
        string? customerName,
        string? customerTin,
        bool? isVatRegistered,
        decimal subtotal,
        decimal discountAmount,
        decimal taxAmount,
        decimal totalAmount,
        decimal amountPaid,
        decimal change,
        IReadOnlyCollection<SaleLine> lines,
        IReadOnlyCollection<SalePayment> payments,
        string? buyerTin = null,
        string? buyerName = null,
        string? buyerIdType = null,
        string? buyerMobile = null,
        string? fiscalReceiptNumber = null,
        string? fiscalVerificationCode = null,
        string? fiscalZNumber = null,
        int? fiscalDailyCounter = null,
        FiscalStatus fiscalStatus = FiscalStatus.NotApplicable)
    {
        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("A tenant is required.", nameof(tenantId));
        }

        if (branchId == Guid.Empty)
        {
            throw new ArgumentException("A branch is required.", nameof(branchId));
        }

        if (cashierId == Guid.Empty)
        {
            throw new ArgumentException("A cashier is required.", nameof(cashierId));
        }

        if (clientSaleId == Guid.Empty)
        {
            throw new ArgumentException("A client sale id is required.", nameof(clientSaleId));
        }

        if (string.IsNullOrWhiteSpace(number))
        {
            throw new ArgumentException("A receipt number is required.", nameof(number));
        }

        if (string.IsNullOrWhiteSpace(currency))
        {
            throw new ArgumentException("A currency is required.", nameof(currency));
        }

        if (saleDate == default)
        {
            throw new ArgumentException("A sale date is required.", nameof(saleDate));
        }

        if (effectiveAt == default)
        {
            throw new ArgumentException("An effective date is required.", nameof(effectiveAt));
        }

        if (lines.Count == 0)
        {
            throw new ArgumentException("A sale requires at least one line.", nameof(lines));
        }

        if (payments.Count == 0)
        {
            throw new ArgumentException("A sale requires at least one payment.", nameof(payments));
        }

        if (subtotal < 0 || discountAmount < 0 || taxAmount < 0 || totalAmount < 0 || amountPaid < 0 || change < 0)
        {
            throw new ArgumentException("Money amounts cannot be negative.");
        }

        Reconcile(lines, payments, subtotal, discountAmount, taxAmount, totalAmount, amountPaid, change);

        var sale = new Sale(
            Guid.NewGuid(),
            tenantId,
            branchId,
            warehouseId,
            cashierId,
            clientSaleId,
            number.Trim(),
            source,
            saleDate,
            effectiveAt,
            currency.Trim(),
            priceListId,
            isPriceTaxInclusive,
            isElectronicPayment,
            customerId,
            Normalize(customerName),
            Normalize(customerTin),
            isVatRegistered,
            subtotal,
            discountAmount,
            taxAmount,
            totalAmount,
            amountPaid,
            change,
            Normalize(buyerTin),
            Normalize(buyerName),
            Normalize(buyerIdType),
            Normalize(buyerMobile),
            Normalize(fiscalReceiptNumber),
            Normalize(fiscalVerificationCode),
            Normalize(fiscalZNumber),
            fiscalDailyCounter,
            fiscalStatus);

        foreach (var line in lines)
        {
            line.AttachTo(sale.Id);
            sale._lines.Add(line);
        }

        foreach (var payment in payments)
        {
            payment.AttachTo(sale.Id);
            sale._payments.Add(payment);
        }

        sale.AddDomainEvent(new SaleCompletedEvent(
            Guid.NewGuid(),
            DateTime.UtcNow,
            sale.Id,
            tenantId,
            branchId,
            cashierId,
            clientSaleId,
            sale.Number,
            sale.Currency,
            sale.TotalAmount,
            sale.TaxAmount));

        return sale;
    }

    /// <summary>
    /// Voids a completed sale: a compensating status transition, never a delete — the receipt
    /// number stays immutable and the original ledger rows stay posted. Stock is added back by
    /// the command handler (compensating <see cref="StockMovementType.SaleVoid"/> movements), not
    /// here. Idempotency is the caller's concern: a sale that is not <see cref="SaleStatus.Completed"/>
    /// cannot be voided again (guarded before any state change).
    /// </summary>
    public void Void(string reason, Guid voidedBy, DateTime occurredAt)
    {
        if (string.IsNullOrWhiteSpace(reason))
        {
            throw new ArgumentException("A void reason is required.", nameof(reason));
        }

        if (voidedBy == Guid.Empty)
        {
            throw new ArgumentException("A voiding user is required.", nameof(voidedBy));
        }

        if (occurredAt == default)
        {
            throw new ArgumentException("A void date is required.", nameof(occurredAt));
        }

        if (Status != SaleStatus.Completed)
        {
            throw new InvalidOperationException(
                $"Only a completed sale can be voided (current status: {Status}).");
        }

        Status = SaleStatus.Voided;
        VoidedAt = occurredAt;
        VoidedBy = voidedBy;
        VoidReason = Normalize(reason);

        AddDomainEvent(new SaleVoidedEvent(
            Guid.NewGuid(),
            DateTime.UtcNow,
            Id,
            TenantId,
            BranchId,
            voidedBy,
            Number,
            Currency,
            TotalAmount,
            VoidReason!));
    }

    private static void Reconcile(
        IReadOnlyCollection<SaleLine> lines,
        IReadOnlyCollection<SalePayment> payments,
        decimal subtotal,
        decimal discountAmount,
        decimal taxAmount,
        decimal totalAmount,
        decimal amountPaid,
        decimal change)
    {
        var computedSubtotal = lines.Sum(l => Round(l.UnitPrice * l.Quantity));
        var computedDiscount = lines.Sum(l => l.DiscountAmount);
        var computedTax = lines.Sum(l => l.TaxAmount);
        var computedTotal = lines.Sum(l => l.LineTotal - l.DiscountAmount);

        // The header is a dumb aggregator of the lines: totals must match what the lines imply.
        // There is deliberately no `totalAmount == subtotal - discount` cross-check: under the
        // dual-VAT scheme (electronic rate B) the collectable total is less than the embedded
        // shelf gross, so the receipt may legitimately total below the pre-discount subtotal.
        if (subtotal != computedSubtotal
            || discountAmount != computedDiscount
            || taxAmount != computedTax
            || totalAmount != computedTotal)
        {
            throw new InvalidOperationException(
                "Sale totals do not reconcile with the resolved lines (programmer error).");
        }

        var computedPaid = payments.Sum(p => p.Amount);
        var hasCreditPayment = payments.Any(p => p.Method == PaymentMethod.Credit);

        // A cash tender may overpay the total so the seller can give change
        // (Change = amountPaid - total). A CREDIT tender may underpay — the
        // unpaid balance becomes the customer's ledger debt — and gets no
        // change, so Change is floored at zero. All other methods pay in full.
        var expectedChange = hasCreditPayment
            ? Math.Max(0m, amountPaid - totalAmount)
            : amountPaid - totalAmount;
        if (amountPaid != computedPaid
            || change != expectedChange
            || change < 0
            || (amountPaid < totalAmount && !hasCreditPayment))
        {
            throw new InvalidOperationException(
                "Sale payments must fully cover (or over-cover) the total, "
                + "except credit tenders which may leave a ledger balance (programmer error).");
        }
    }

    private static decimal Round(decimal value)
        => Math.Round(value, 2, MidpointRounding.AwayFromZero);

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

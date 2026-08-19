using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Purchasing;

public sealed class SupplierBill : AggregateRoot
{
    private SupplierBill(
        Guid id,
        Guid tenantId,
        Guid supplierId,
        Guid purchaseOrderId,
        string? billNumber,
        DateTime billDate,
        decimal subtotal,
        decimal taxAmount,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        SupplierId = supplierId;
        PurchaseOrderId = purchaseOrderId;
        BillNumber = billNumber;
        BillDate = billDate;
        Subtotal = subtotal;
        TaxAmount = taxAmount;
        TotalAmount = subtotal + taxAmount;
        AmountPaid = 0m;
        Status = SupplierBillStatus.Draft;
        Notes = notes;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid SupplierId { get; private set; }
    public Guid PurchaseOrderId { get; private set; }
    public string? BillNumber { get; private set; }
    public DateTime BillDate { get; private set; }
    public SupplierBillStatus Status { get; private set; }
    public decimal Subtotal { get; private set; }
    public decimal TaxAmount { get; private set; }
    public decimal TotalAmount { get; private set; }
    public decimal AmountPaid { get; private set; }
    public decimal BalanceDue => TotalAmount - AmountPaid;
    public string? Notes { get; private set; }
    public DateTime? ApprovedAt { get; private set; }
    public DateTime? VoidedAt { get; private set; }

    public static SupplierBill Create(
        Guid tenantId,
        Guid supplierId,
        Guid purchaseOrderId,
        decimal subtotal,
        decimal taxAmount,
        string? billNumber = null,
        DateTime? billDate = null,
        string? notes = null)
    {
        if (supplierId == Guid.Empty)
        {
            throw new ArgumentException("Supplier is required.", nameof(supplierId));
        }

        if (purchaseOrderId == Guid.Empty)
        {
            throw new ArgumentException("Purchase order is required.", nameof(purchaseOrderId));
        }

        if (subtotal < 0)
        {
            throw new ArgumentException("Subtotal cannot be negative.", nameof(subtotal));
        }

        if (taxAmount < 0)
        {
            throw new ArgumentException("Tax amount cannot be negative.", nameof(taxAmount));
        }

        return new SupplierBill(
            Guid.NewGuid(), tenantId, supplierId, purchaseOrderId,
            billNumber?.Trim(), billDate ?? DateTime.UtcNow, subtotal, taxAmount,
            notes?.Trim());
    }

    public void Approve(DateTime approvedAt)
    {
        if (Status != SupplierBillStatus.Draft)
        {
            throw new InvalidOperationException($"Cannot approve a bill in {Status} status.");
        }

        Status = SupplierBillStatus.Approved;
        ApprovedAt = approvedAt;
    }

    public void RecordPayment(decimal amount, DateTime paidAt)
    {
        if (Status != SupplierBillStatus.Approved && Status != SupplierBillStatus.Draft)
        {
            throw new InvalidOperationException($"Cannot record payment on a bill in {Status} status.");
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

        AmountPaid += amount;

        if (AmountPaid >= TotalAmount)
        {
            Status = SupplierBillStatus.Paid;
        }

        UpdatedAt = DateTime.UtcNow;
    }

    public void Void(DateTime voidedAt)
    {
        if (Status == SupplierBillStatus.Paid)
        {
            throw new InvalidOperationException("Cannot void a fully paid bill.");
        }

        Status = SupplierBillStatus.Void;
        VoidedAt = voidedAt;
    }
}

using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Purchasing;

public sealed class PurchaseOrder : AggregateRoot
{
    private readonly List<PurchaseOrderLine> _lines = new();

    private PurchaseOrder(
        Guid id,
        Guid tenantId,
        Guid supplierId,
        Guid warehouseId,
        Guid? branchId,
        string? reference,
        DateTime? expectedDate,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        SupplierId = supplierId;
        WarehouseId = warehouseId;
        BranchId = branchId;
        Reference = reference;
        ExpectedDate = expectedDate;
        Notes = notes;
        Status = PurchaseOrderStatus.Draft;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid SupplierId { get; private set; }
    public Guid WarehouseId { get; private set; }
    public Guid? BranchId { get; private set; }
    public PurchaseOrderStatus Status { get; private set; }
    public string? Reference { get; private set; }
    public DateTime? ExpectedDate { get; private set; }
    public string? Notes { get; private set; }
    public decimal TotalAmount { get; private set; }
    public DateTime? SubmittedAt { get; private set; }
    public DateTime? ReceivedAt { get; private set; }
    public DateTime? CancelledAt { get; private set; }
    public IReadOnlyCollection<PurchaseOrderLine> Lines => _lines.AsReadOnly();

    public static PurchaseOrder Create(
        Guid tenantId,
        Guid supplierId,
        Guid warehouseId,
        Guid? branchId,
        IEnumerable<(Guid ProductId, decimal Quantity, decimal UnitPrice)> lines,
        string? reference = null,
        DateTime? expectedDate = null,
        string? notes = null)
    {
        if (supplierId == Guid.Empty)
        {
            throw new ArgumentException("Supplier is required.", nameof(supplierId));
        }

        if (warehouseId == Guid.Empty)
        {
            throw new ArgumentException("Warehouse is required.", nameof(warehouseId));
        }

        var lineList = lines.ToList();
        if (lineList.Count == 0)
        {
            throw new ArgumentException("At least one line is required.", nameof(lines));
        }

        var po = new PurchaseOrder(
            Guid.NewGuid(), tenantId, supplierId, warehouseId, branchId,
            reference, expectedDate, notes);

        foreach (var line in lineList)
        {
            po._lines.Add(PurchaseOrderLine.Create(line.ProductId, line.Quantity, line.UnitPrice));
        }

        po.TotalAmount = po._lines.Sum(l => l.LineTotal);

        return po;
    }

    public void Submit(DateTime submittedAt)
    {
        if (Status != PurchaseOrderStatus.Draft)
        {
            throw new InvalidOperationException($"Cannot submit a PO in {Status} status.");
        }

        Status = PurchaseOrderStatus.Submitted;
        SubmittedAt = submittedAt;
    }

    public void Receive(DateTime receivedAt)
    {
        if (Status != PurchaseOrderStatus.Submitted)
        {
            throw new InvalidOperationException($"Cannot receive a PO in {Status} status. Must be Submitted.");
        }

        Status = PurchaseOrderStatus.Received;
        ReceivedAt = receivedAt;
    }

    public void Cancel(DateTime cancelledAt)
    {
        if (Status != PurchaseOrderStatus.Draft && Status != PurchaseOrderStatus.Submitted)
        {
            throw new InvalidOperationException($"Cannot cancel a PO in {Status} status.");
        }

        Status = PurchaseOrderStatus.Cancelled;
        CancelledAt = cancelledAt;
    }
}

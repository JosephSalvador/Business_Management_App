using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Inventory;

/// <summary>
/// Represents a stock transfer between warehouses/locations. Transfers move stock from a
/// source to a destination. A transfer starts as <see cref="TransferStatus.Pending"/> and
/// is completed when stock is actually moved (two movements: TransferOut + TransferIn).
/// </summary>
public sealed class Transfer : AggregateRoot
{
    private readonly List<TransferLine> _lines = new();

    private Transfer(
        Guid id,
        Guid tenantId,
        Guid sourceWarehouseId,
        Guid? sourceLocationId,
        Guid destinationWarehouseId,
        Guid? destinationLocationId,
        string? referenceType,
        Guid? referenceId,
        string? reason)
        : base(id)
    {
        TenantId = tenantId;
        SourceWarehouseId = sourceWarehouseId;
        SourceLocationId = sourceLocationId;
        DestinationWarehouseId = destinationWarehouseId;
        DestinationLocationId = destinationLocationId;
        ReferenceType = referenceType;
        ReferenceId = referenceId;
        Reason = reason;
        Status = TransferStatus.Pending;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid SourceWarehouseId { get; private set; }
    public Guid? SourceLocationId { get; private set; }
    public Guid DestinationWarehouseId { get; private set; }
    public Guid? DestinationLocationId { get; private set; }
    public TransferStatus Status { get; private set; }
    public string? ReferenceType { get; private set; }
    public Guid? ReferenceId { get; private set; }
    public string? Reason { get; private set; }
    public DateTime? CompletedAt { get; private set; }
    public DateTime? CancelledAt { get; private set; }
    public IReadOnlyCollection<TransferLine> Lines => _lines.AsReadOnly();

    public static Transfer Create(
        Guid tenantId,
        Guid sourceWarehouseId,
        Guid? sourceLocationId,
        Guid destinationWarehouseId,
        Guid? destinationLocationId,
        IEnumerable<(Guid ProductId, Guid? VariantId, decimal Quantity, Guid? BatchId)> lines,
        string? referenceType = null,
        Guid? referenceId = null,
        string? reason = null)
    {
        if (sourceWarehouseId == destinationWarehouseId && sourceLocationId == destinationLocationId)
        {
            throw new ArgumentException("Source and destination must be different.");
        }

        var lineList = lines.ToList();
        if (lineList.Count == 0)
        {
            throw new ArgumentException("At least one transfer line is required.", nameof(lines));
        }

        foreach (var line in lineList)
        {
            if (line.Quantity <= 0)
            {
                throw new ArgumentException($"Transfer line quantity must be positive (product {line.ProductId}).");
            }
        }

        var transfer = new Transfer(
            Guid.NewGuid(),
            tenantId,
            sourceWarehouseId,
            sourceLocationId,
            destinationWarehouseId,
            destinationLocationId,
            referenceType,
            referenceId,
            reason);

        foreach (var line in lineList)
        {
            transfer._lines.Add(TransferLine.Create(line.ProductId, line.VariantId, line.Quantity, line.BatchId));
        }

        return transfer;
    }

    public void Complete(DateTime completedAt)
    {
        if (Status != TransferStatus.Pending)
        {
            throw new InvalidOperationException($"Cannot complete a transfer in {Status} status.");
        }

        Status = TransferStatus.Completed;
        CompletedAt = completedAt;
    }

    public void Cancel(DateTime cancelledAt)
    {
        if (Status != TransferStatus.Pending)
        {
            throw new InvalidOperationException($"Cannot cancel a transfer in {Status} status.");
        }

        Status = TransferStatus.Cancelled;
        CancelledAt = cancelledAt;
    }
}

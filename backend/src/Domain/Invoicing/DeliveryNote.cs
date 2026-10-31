using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Invoicing;

/// <summary>
/// A delivery note (goods dispatch document) handed to the driver and signed by the receiver.
/// It can be raised standalone or from an existing <see cref="CustomerInvoice"/>. Like the
/// invoice it is independent of POS: it never moves stock, it is the paper trail for delivery.
/// </summary>
public sealed class DeliveryNote : AggregateRoot
{
    private readonly List<DeliveryNoteItem> _items = new();

    private DeliveryNote(
        Guid id,
        Guid tenantId,
        string number,
        Guid? invoiceId,
        string? invoiceNumber,
        Guid? customerId,
        string? customerName,
        string? customerAttention,
        string? customerPhone,
        string? deliveryAddress,
        DateTime issueDate,
        string? vehicleNumber,
        string? driverName,
        string? driverPhone,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        Number = number;
        InvoiceId = invoiceId;
        InvoiceNumber = invoiceNumber;
        CustomerId = customerId;
        CustomerName = customerName;
        CustomerAttention = customerAttention;
        CustomerPhone = customerPhone;
        DeliveryAddress = deliveryAddress;
        IssueDate = issueDate;
        VehicleNumber = vehicleNumber;
        DriverName = driverName;
        DriverPhone = driverPhone;
        Notes = notes;
        Status = DeliveryNoteStatus.Draft;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public string Number { get; private set; }
    public Guid? InvoiceId { get; private set; }
    public string? InvoiceNumber { get; private set; }
    public Guid? CustomerId { get; private set; }
    public string? CustomerName { get; private set; }
    public string? CustomerAttention { get; private set; }
    public string? CustomerPhone { get; private set; }
    public string? DeliveryAddress { get; private set; }
    public DateTime IssueDate { get; private set; }
    public DeliveryNoteStatus Status { get; private set; }
    public string? VehicleNumber { get; private set; }
    public string? DriverName { get; private set; }
    public string? DriverPhone { get; private set; }
    public string? ReceivedByName { get; private set; }
    public string? Notes { get; private set; }
    public DateTime? DispatchedAtUtc { get; private set; }
    public DateTime? DeliveredAtUtc { get; private set; }
    public DateTime? CancelledAtUtc { get; private set; }
    public IReadOnlyCollection<DeliveryNoteItem> Items => _items;

    public static DeliveryNote Create(
        Guid tenantId,
        string number,
        IEnumerable<DeliveryNoteItemSpec> items,
        Guid? invoiceId = null,
        string? invoiceNumber = null,
        Guid? customerId = null,
        string? customerName = null,
        string? customerAttention = null,
        string? customerPhone = null,
        string? deliveryAddress = null,
        DateTime? issueDate = null,
        string? vehicleNumber = null,
        string? driverName = null,
        string? driverPhone = null,
        string? notes = null,
        DateTime? nowUtc = null,
        Guid? id = null)
    {
        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("A tenant is required.", nameof(tenantId));
        }

        if (string.IsNullOrWhiteSpace(number))
        {
            throw new ArgumentException("Delivery note number is required.", nameof(number));
        }

        var specs = items?.ToList() ?? new List<DeliveryNoteItemSpec>();
        if (specs.Count == 0)
        {
            throw new ArgumentException("A delivery note needs at least one item.", nameof(items));
        }

        var now = nowUtc ?? DateTime.UtcNow;
        var noteId = id.HasValue && id.Value != Guid.Empty ? id.Value : Guid.NewGuid();

        var note = new DeliveryNote(
            noteId,
            tenantId,
            number.Trim(),
            invoiceId,
            Clean(invoiceNumber),
            customerId,
            Clean(customerName),
            Clean(customerAttention),
            Clean(customerPhone),
            Clean(deliveryAddress),
            issueDate ?? now,
            Clean(vehicleNumber),
            Clean(driverName),
            Clean(driverPhone),
            Clean(notes));

        for (var index = 0; index < specs.Count; index++)
        {
            note._items.Add(DeliveryNoteItem.Create(tenantId, note.Id, specs[index], index));
        }

        note.AddDomainEvent(new DeliveryNoteCreatedEvent(
            Guid.NewGuid(),
            now,
            note.Id,
            tenantId,
            note.Number,
            note.InvoiceId,
            note.CustomerId,
            note._items.Count));
        return note;
    }

    public void MarkDispatched(
        string? vehicleNumber = null, string? driverName = null, string? driverPhone = null, DateTime? nowUtc = null)
    {
        if (Status != DeliveryNoteStatus.Draft)
        {
            throw new InvalidOperationException(
                $"Only a draft delivery note can be dispatched (current status: {Status}).");
        }

        var now = nowUtc ?? DateTime.UtcNow;
        VehicleNumber = Clean(vehicleNumber) ?? VehicleNumber;
        DriverName = Clean(driverName) ?? DriverName;
        DriverPhone = Clean(driverPhone) ?? DriverPhone;
        Status = DeliveryNoteStatus.Dispatched;
        DispatchedAtUtc = now;
        UpdatedAt = now;

        AddDomainEvent(new DeliveryNoteDispatchedEvent(
            Guid.NewGuid(), now, Id, TenantId, Number));
    }

    /// <summary>
    /// Confirms receipt. <paramref name="deliveredQuantities"/> maps item id → quantity actually
    /// delivered; any item not listed is treated as delivered in full.
    /// </summary>
    public void MarkDelivered(
        string receivedByName,
        IReadOnlyDictionary<Guid, decimal>? deliveredQuantities = null,
        DateTime? nowUtc = null)
    {
        if (Status != DeliveryNoteStatus.Dispatched)
        {
            throw new InvalidOperationException(
                $"Only a dispatched delivery note can be marked delivered (current status: {Status}).");
        }

        if (string.IsNullOrWhiteSpace(receivedByName))
        {
            throw new ArgumentException("The receiver's name is required.", nameof(receivedByName));
        }

        if (deliveredQuantities is not null)
        {
            foreach (var itemId in deliveredQuantities.Keys)
            {
                if (_items.All(item => item.Id != itemId))
                {
                    throw new ArgumentException(
                        $"Item {itemId} does not belong to this delivery note.", nameof(deliveredQuantities));
                }
            }
        }

        foreach (var item in _items)
        {
            var delivered = deliveredQuantities is not null
                && deliveredQuantities.TryGetValue(item.Id, out var quantity)
                    ? quantity
                    : item.QuantityOrdered;
            item.ConfirmDelivered(delivered);
        }

        var now = nowUtc ?? DateTime.UtcNow;
        ReceivedByName = receivedByName.Trim();
        Status = DeliveryNoteStatus.Delivered;
        DeliveredAtUtc = now;
        UpdatedAt = now;

        AddDomainEvent(new DeliveryNoteDeliveredEvent(
            Guid.NewGuid(), now, Id, TenantId, Number, ReceivedByName));
    }

    public void Cancel(DateTime? nowUtc = null)
    {
        if (Status == DeliveryNoteStatus.Cancelled)
        {
            throw new InvalidOperationException("This delivery note is already cancelled.");
        }

        if (Status == DeliveryNoteStatus.Delivered)
        {
            throw new InvalidOperationException("A delivered delivery note cannot be cancelled.");
        }

        var now = nowUtc ?? DateTime.UtcNow;
        Status = DeliveryNoteStatus.Cancelled;
        CancelledAtUtc = now;
        UpdatedAt = now;

        AddDomainEvent(new DeliveryNoteCancelledEvent(
            Guid.NewGuid(), now, Id, TenantId, Number));
    }

    private static string? Clean(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

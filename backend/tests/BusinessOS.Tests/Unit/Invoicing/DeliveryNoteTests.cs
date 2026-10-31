using BusinessOS.Domain.Events;
using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Tests.Unit.Invoicing;

public sealed class DeliveryNoteTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 10, 31, 10, 0, 0, DateTimeKind.Utc);

    private static DeliveryNoteItemSpec Item(
        string description = "Cement 50kg",
        decimal quantityOrdered = 10m,
        decimal quantityDelivered = 10m,
        string unit = "Bags")
        => new(Guid.NewGuid(), description, unit, quantityOrdered, quantityDelivered);

    [Fact]
    public void Create_InitializesPropertiesAndEmitsEvent()
    {
        var items = new[] { Item("Tiles", 50m, 50m, "Boxes"), Item("Grout", 5m, 5m, "Bags") };
        var note = DeliveryNote.Create(
            tenantId: TenantId,
            number: "DN-2026-0001",
            items: items,
            customerName: "Acme Builders Ltd",
            customerPhone: "+255712345678",
            deliveryAddress: "Kariakoo, Dar es Salaam",
            vehicleNumber: "T 123 ABC",
            driverName: "John Doe",
            nowUtc: Now);

        Assert.Equal(TenantId, note.TenantId);
        Assert.Equal("DN-2026-0001", note.Number);
        Assert.Equal(DeliveryNoteStatus.Draft, note.Status);
        Assert.Equal("Acme Builders Ltd", note.CustomerName);
        Assert.Equal("+255712345678", note.CustomerPhone);
        Assert.Equal("Kariakoo, Dar es Salaam", note.DeliveryAddress);
        Assert.Equal("T 123 ABC", note.VehicleNumber);
        Assert.Equal("John Doe", note.DriverName);
        Assert.Equal(2, note.Items.Count);

        var createdEvent = Assert.Single(note.DomainEvents.OfType<DeliveryNoteCreatedEvent>());
        Assert.Equal(note.Id, createdEvent.DeliveryNoteId);
        Assert.Equal(TenantId, createdEvent.TenantId);
        Assert.Equal("DN-2026-0001", createdEvent.Number);
        Assert.Equal(2, createdEvent.ItemCount);
    }

    [Fact]
    public void Create_WithoutItems_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() =>
            DeliveryNote.Create(
                TenantId,
                "DN-2026-0002",
                Array.Empty<DeliveryNoteItemSpec>()));
    }

    [Fact]
    public void MarkDispatched_TransitionsFromDraftToDispatched()
    {
        var note = DeliveryNote.Create(
            TenantId,
            "DN-2026-0003",
            new[] { Item() },
            nowUtc: Now);

        note.MarkDispatched("T 456 DEF", "Juma Ali", "+255788000111", Now.AddHours(1));

        Assert.Equal(DeliveryNoteStatus.Dispatched, note.Status);
        Assert.Equal("T 456 DEF", note.VehicleNumber);
        Assert.Equal("Juma Ali", note.DriverName);
        Assert.Equal("+255788000111", note.DriverPhone);
        Assert.Equal(Now.AddHours(1), note.DispatchedAtUtc);

        var dispatchedEvent = Assert.Single(note.DomainEvents.OfType<DeliveryNoteDispatchedEvent>());
        Assert.Equal(note.Id, dispatchedEvent.DeliveryNoteId);
    }

    [Fact]
    public void MarkDispatched_WhenNotDraft_ThrowsInvalidOperationException()
    {
        var note = DeliveryNote.Create(TenantId, "DN-2026-0004", new[] { Item() }, nowUtc: Now);
        note.MarkDispatched();

        Assert.Throws<InvalidOperationException>(() => note.MarkDispatched());
    }

    [Fact]
    public void MarkDelivered_TransitionsFromDispatchedToDelivered()
    {
        var note = DeliveryNote.Create(TenantId, "DN-2026-0005", new[] { Item() }, nowUtc: Now);
        note.MarkDispatched();
        note.MarkDelivered("Supervisor Peter", Now.AddHours(2));

        Assert.Equal(DeliveryNoteStatus.Delivered, note.Status);
        Assert.Equal("Supervisor Peter", note.ReceivedByName);
        Assert.Equal(Now.AddHours(2), note.DeliveredAtUtc);

        var deliveredEvent = Assert.Single(note.DomainEvents.OfType<DeliveryNoteDeliveredEvent>());
        Assert.Equal(note.Id, deliveredEvent.DeliveryNoteId);
        Assert.Equal("Supervisor Peter", deliveredEvent.ReceivedByName);
    }

    [Fact]
    public void MarkDelivered_DirectlyFromDraft_TransitionsToDelivered()
    {
        var note = DeliveryNote.Create(TenantId, "DN-2026-0006", new[] { Item() }, nowUtc: Now);
        note.MarkDelivered("Receiver Mary");

        Assert.Equal(DeliveryNoteStatus.Delivered, note.Status);
        Assert.Equal("Receiver Mary", note.ReceivedByName);
    }

    [Fact]
    public void Cancel_WhenActive_TransitionsToCancelled()
    {
        var note = DeliveryNote.Create(TenantId, "DN-2026-0007", new[] { Item() }, nowUtc: Now);
        note.Cancel("Wrong customer address", Now.AddMinutes(30));

        Assert.Equal(DeliveryNoteStatus.Cancelled, note.Status);
        Assert.Equal(Now.AddMinutes(30), note.CancelledAtUtc);

        var cancelledEvent = Assert.Single(note.DomainEvents.OfType<DeliveryNoteCancelledEvent>());
        Assert.Equal(note.Id, cancelledEvent.DeliveryNoteId);
        Assert.Equal("Wrong customer address", cancelledEvent.Reason);
    }

    [Fact]
    public void Cancel_WhenAlreadyDelivered_ThrowsInvalidOperationException()
    {
        var note = DeliveryNote.Create(TenantId, "DN-2026-0008", new[] { Item() }, nowUtc: Now);
        note.MarkDelivered();

        Assert.Throws<InvalidOperationException>(() => note.Cancel());
    }
}

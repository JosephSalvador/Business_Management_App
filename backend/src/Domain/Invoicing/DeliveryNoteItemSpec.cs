namespace BusinessOS.Domain.Invoicing;

/// <summary>Input for one delivery note line (before it becomes a <see cref="DeliveryNoteItem"/>).</summary>
public sealed record DeliveryNoteItemSpec(
    string Description,
    decimal QuantityOrdered,
    string UnitOfMeasure = "Pcs",
    Guid? ProductId = null);

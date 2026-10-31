using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Invoicing;

/// <summary>
/// One line on a delivery note: what was ordered and what was actually handed over. The
/// delivered quantity can never exceed the ordered quantity.
/// </summary>
public sealed class DeliveryNoteItem : Entity
{
    private DeliveryNoteItem(
        Guid id,
        Guid tenantId,
        Guid deliveryNoteId,
        Guid? productId,
        string description,
        string unitOfMeasure,
        decimal quantityOrdered,
        int orderIndex)
        : base(id)
    {
        TenantId = tenantId;
        DeliveryNoteId = deliveryNoteId;
        ProductId = productId;
        Description = description;
        UnitOfMeasure = unitOfMeasure;
        QuantityOrdered = quantityOrdered;
        QuantityDelivered = 0m;
        OrderIndex = orderIndex;
    }

    public Guid TenantId { get; private set; }
    public Guid DeliveryNoteId { get; private set; }
    public Guid? ProductId { get; private set; }
    public string Description { get; private set; }
    public string UnitOfMeasure { get; private set; }
    public decimal QuantityOrdered { get; private set; }
    public decimal QuantityDelivered { get; private set; }
    public int OrderIndex { get; private set; }

    internal static DeliveryNoteItem Create(
        Guid tenantId, Guid deliveryNoteId, DeliveryNoteItemSpec spec, int orderIndex)
    {
        if (string.IsNullOrWhiteSpace(spec.Description))
        {
            throw new ArgumentException("Item description is required.", nameof(spec));
        }

        if (spec.QuantityOrdered <= 0)
        {
            throw new ArgumentException("Quantity must be positive.", nameof(spec));
        }

        return new DeliveryNoteItem(
            Guid.NewGuid(),
            tenantId,
            deliveryNoteId,
            spec.ProductId,
            spec.Description.Trim(),
            string.IsNullOrWhiteSpace(spec.UnitOfMeasure) ? "Pcs" : spec.UnitOfMeasure.Trim(),
            spec.QuantityOrdered,
            orderIndex);
    }

    internal void ConfirmDelivered(decimal quantityDelivered)
    {
        if (quantityDelivered < 0)
        {
            throw new ArgumentException("Delivered quantity cannot be negative.", nameof(quantityDelivered));
        }

        if (quantityDelivered > QuantityOrdered)
        {
            throw new ArgumentException(
                $"Delivered quantity ({quantityDelivered}) exceeds the ordered quantity ({QuantityOrdered}) for '{Description}'.",
                nameof(quantityDelivered));
        }

        QuantityDelivered = quantityDelivered;
    }
}

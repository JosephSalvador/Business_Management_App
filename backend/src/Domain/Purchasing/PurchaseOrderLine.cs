using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Purchasing;

public sealed class PurchaseOrderLine : Entity
{
    private PurchaseOrderLine(
        Guid id,
        Guid productId,
        decimal quantity,
        decimal unitPrice)
        : base(id)
    {
        ProductId = productId;
        Quantity = quantity;
        UnitPrice = unitPrice;
    }

    public Guid PurchaseOrderId { get; internal set; }
    public Guid ProductId { get; private set; }
    public decimal Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }
    public decimal LineTotal => Quantity * UnitPrice;

    internal void Update(decimal quantity, decimal unitPrice)
    {
        if (quantity <= 0)
        {
            throw new ArgumentException("Quantity must be positive.", nameof(quantity));
        }

        if (unitPrice < 0)
        {
            throw new ArgumentException("Unit price cannot be negative.", nameof(unitPrice));
        }

        Quantity = quantity;
        UnitPrice = unitPrice;
    }

    internal static PurchaseOrderLine Create(Guid productId, decimal quantity, decimal unitPrice)
    {
        if (quantity <= 0)
        {
            throw new ArgumentException("Quantity must be positive.", nameof(quantity));
        }

        if (unitPrice < 0)
        {
            throw new ArgumentException("Unit price cannot be negative.", nameof(unitPrice));
        }

        return new PurchaseOrderLine(Guid.NewGuid(), productId, quantity, unitPrice);
    }
}

namespace BusinessOS.Domain.Inventory;

public sealed class TransferLine
{
    private TransferLine(Guid id, Guid productId, Guid? variantId, decimal quantity, Guid? batchId)
    {
        Id = id;
        ProductId = productId;
        VariantId = variantId;
        Quantity = quantity;
        BatchId = batchId;
    }

    public Guid Id { get; private set; }
    public Guid TransferId { get; internal set; }
    public Guid ProductId { get; private set; }
    public Guid? VariantId { get; private set; }
    public decimal Quantity { get; private set; }
    public Guid? BatchId { get; private set; }

    internal static TransferLine Create(Guid productId, Guid? variantId, decimal quantity, Guid? batchId = null)
        => new(Guid.NewGuid(), productId, variantId, quantity, batchId);
}

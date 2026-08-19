using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Inventory;

/// <summary>
/// A production/supplier batch (lot) for traceability. Batches group stock units by
/// production batch, expiry date, or supplier lot. Optional — products without batch
/// tracking work exactly as before.
/// </summary>
public sealed class StockBatch : Entity
{
    private StockBatch(
        Guid id,
        Guid tenantId,
        Guid productId,
        Guid? variantId,
        string batchNumber,
        DateTime? manufacturerDate,
        DateTime? expiryDate,
        Guid? supplierId,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        ProductId = productId;
        VariantId = variantId;
        BatchNumber = batchNumber;
        ManufacturerDate = manufacturerDate;
        ExpiryDate = expiryDate;
        SupplierId = supplierId;
        Notes = notes;
        IsActive = true;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid ProductId { get; private set; }
    public Guid? VariantId { get; private set; }
    public string BatchNumber { get; private set; }
    public DateTime? ManufacturerDate { get; private set; }
    public DateTime? ExpiryDate { get; private set; }
    public Guid? SupplierId { get; private set; }
    public string? Notes { get; private set; }
    public bool IsActive { get; private set; }

    public static StockBatch Create(
        Guid tenantId,
        Guid productId,
        Guid? variantId,
        string batchNumber,
        DateTime? manufacturerDate = null,
        DateTime? expiryDate = null,
        Guid? supplierId = null,
        string? notes = null)
    {
        if (string.IsNullOrWhiteSpace(batchNumber))
        {
            throw new ArgumentException("Batch number is required.", nameof(batchNumber));
        }

        if (expiryDate.HasValue && expiryDate.Value <= DateTime.UtcNow)
        {
            throw new ArgumentException("Expiry date must be in the future.", nameof(expiryDate));
        }

        return new StockBatch(
            Guid.NewGuid(), tenantId, productId, variantId,
            batchNumber.Trim(), manufacturerDate, expiryDate, supplierId, notes);
    }

    public void Activate()
    {
        IsActive = true;
        UpdatedAt = DateTime.UtcNow;
    }

    public void Deactivate()
    {
        IsActive = false;
        UpdatedAt = DateTime.UtcNow;
    }
}

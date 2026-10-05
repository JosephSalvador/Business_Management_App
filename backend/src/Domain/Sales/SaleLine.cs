using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A sold line carrying the immutable per-line tax snapshot. Values come from the TaxEngine at
/// sale time and sever the line from live tax rules — an old invoice reprinted years later keeps
/// the rate, code and rule id in force on the sale date. EFD/fiscal payloads read
/// <see cref="TaxCode"/>, <see cref="BaseAmount"/> and <see cref="TaxAmount"/> directly (no
/// reverse math). One line per (product, variant) sold.
/// </summary>
public sealed class SaleLine : Entity
{
    private SaleLine(
        Guid productId,
        Guid? variantId,
        string productName,
        string? sku,
        string? barcode,
        Guid unitOfMeasureId,
        string? unitOfMeasureName,
        decimal quantity,
        decimal unitPrice,
        decimal discountAmount,
        string taxCode,
        decimal appliedRate,
        Guid? appliedRuleId,
        decimal baseAmount,
        decimal taxAmount,
        decimal lineTotal,
        int orderIndex,
        decimal? unitCost)
    {
        ProductId = productId;
        VariantId = variantId;
        ProductName = productName;
        Sku = sku;
        Barcode = barcode;
        UnitOfMeasureId = unitOfMeasureId;
        UnitOfMeasureName = unitOfMeasureName;
        Quantity = quantity;
        UnitPrice = unitPrice;
        DiscountAmount = discountAmount;
        TaxCode = taxCode;
        AppliedRate = appliedRate;
        AppliedRuleId = appliedRuleId;
        BaseAmount = baseAmount;
        TaxAmount = taxAmount;
        LineTotal = lineTotal;
        OrderIndex = orderIndex;
        UnitCost = unitCost;
    }

    public Guid SaleId { get; private set; }

    public Guid ProductId { get; private set; }
    public Guid? VariantId { get; private set; }
    public string ProductName { get; private set; }
    public string? Sku { get; private set; }
    public string? Barcode { get; private set; }
    public Guid UnitOfMeasureId { get; private set; }
    public string? UnitOfMeasureName { get; private set; }

    public decimal Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }
    public decimal DiscountAmount { get; private set; }

    public string TaxCode { get; private set; }
    public decimal AppliedRate { get; private set; }
    public Guid? AppliedRuleId { get; private set; }
    public decimal BaseAmount { get; private set; }
    public decimal TaxAmount { get; private set; }
    public decimal LineTotal { get; private set; }

    public int OrderIndex { get; private set; }
    public decimal? UnitCost { get; private set; }

    /// <summary>
    /// Creates a line from the TaxEngine snapshot. <see cref="LineTotal"/> is the pre-discount
    /// line money (base + tax), mirroring the snapshot; the header reconciles discount separately.
    /// </summary>
    public static SaleLine Create(
        Guid productId,
        Guid? variantId,
        string productName,
        string? sku,
        string? barcode,
        Guid unitOfMeasureId,
        string? unitOfMeasureName,
        decimal quantity,
        decimal unitPrice,
        decimal discountAmount,
        string taxCode,
        decimal appliedRate,
        Guid? appliedRuleId,
        decimal baseAmount,
        decimal taxAmount,
        decimal lineTotal,
        int orderIndex,
        decimal? unitCost = null)
    {
        if (productId == Guid.Empty)
        {
            throw new ArgumentException("A product is required.", nameof(productId));
        }

        if (string.IsNullOrWhiteSpace(productName))
        {
            throw new ArgumentException("A product name snapshot is required.", nameof(productName));
        }

        if (unitOfMeasureId == Guid.Empty)
        {
            throw new ArgumentException("A unit of measure is required.", nameof(unitOfMeasureId));
        }

        if (quantity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(quantity), "Quantity must be greater than zero.");
        }

        if (unitPrice < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(unitPrice), "Unit price cannot be negative.");
        }

        if (discountAmount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(discountAmount), "Discount cannot be negative.");
        }

        if (string.IsNullOrWhiteSpace(taxCode))
        {
            throw new ArgumentException("A tax code snapshot is required.", nameof(taxCode));
        }

        if (appliedRate < 0m || appliedRate > 1m)
        {
            throw new ArgumentOutOfRangeException(nameof(appliedRate), "Applied rate must be between 0 and 1.");
        }

        if (baseAmount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(baseAmount), "Base amount cannot be negative.");
        }

        if (taxAmount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(taxAmount), "Tax amount cannot be negative.");
        }

        if (lineTotal != baseAmount + taxAmount)
        {
            throw new ArgumentException("LineTotal must equal BaseAmount + TaxAmount.", nameof(lineTotal));
        }

        if (orderIndex < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(orderIndex), "Order index cannot be negative.");
        }

        return new SaleLine(
            productId,
            variantId,
            productName.Trim(),
            Normalize(sku),
            Normalize(barcode),
            unitOfMeasureId,
            Normalize(unitOfMeasureName),
            quantity,
            unitPrice,
            discountAmount,
            taxCode.Trim(),
            appliedRate,
            appliedRuleId,
            baseAmount,
            taxAmount,
            lineTotal,
            orderIndex,
            unitCost);
    }

    internal void AttachTo(Guid saleId) => SaleId = saleId;

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

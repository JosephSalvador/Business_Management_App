using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Invoicing;

/// <summary>
/// One free-text line on a customer invoice. v1 stays deliberately loose: the Invoicing
/// package lets a shop bill work it has not catalogued, so lines carry a description and
/// price rather than a product reference.
/// </summary>
public sealed class CustomerInvoiceLine : Entity
{
    private CustomerInvoiceLine(
        Guid id,
        string description,
        string unitOfMeasure,
        decimal quantity,
        decimal unitPrice,
        decimal discountAmount,
        decimal taxRatePercent,
        int orderIndex)
        : base(id)
    {
        Description = description;
        UnitOfMeasure = unitOfMeasure;
        Quantity = quantity;
        UnitPrice = unitPrice;
        var grossTotal = decimal.Round(quantity * unitPrice, 2);
        DiscountAmount = decimal.Round(Math.Clamp(discountAmount, 0m, grossTotal), 2);
        TaxRatePercent = taxRatePercent;
        LineTotal = grossTotal - DiscountAmount;
        TaxAmount = decimal.Round(LineTotal * taxRatePercent / 100m, 2);
        OrderIndex = orderIndex;
    }

    public Guid CustomerInvoiceId { get; internal set; }
    public Guid TenantId { get; internal set; }
    public string Description { get; private set; }
    public string UnitOfMeasure { get; private set; }
    public decimal Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }
    public decimal DiscountAmount { get; private set; }
    public decimal TaxRatePercent { get; private set; }
    public decimal LineTotal { get; private set; }
    public decimal TaxAmount { get; private set; }
    public int OrderIndex { get; private set; }

    internal static CustomerInvoiceLine Create(CustomerInvoiceLineSpec spec, int orderIndex)
    {
        if (string.IsNullOrWhiteSpace(spec.Description))
        {
            throw new ArgumentException("Line description is required.", nameof(spec));
        }

        if (spec.Quantity <= 0)
        {
            throw new ArgumentException("Quantity must be positive.", nameof(spec));
        }

        if (spec.UnitPrice < 0)
        {
            throw new ArgumentException("Unit price cannot be negative.", nameof(spec));
        }

        if (spec.DiscountAmount < 0)
        {
            throw new ArgumentException("Discount amount cannot be negative.", nameof(spec));
        }

        if (spec.TaxRatePercent is < 0 or > 100)
        {
            throw new ArgumentException("Tax rate must be between 0 and 100.", nameof(spec));
        }

        var unit = string.IsNullOrWhiteSpace(spec.UnitOfMeasure) ? "Pcs" : spec.UnitOfMeasure.Trim();

        return new CustomerInvoiceLine(
            Guid.NewGuid(),
            spec.Description.Trim(),
            unit,
            spec.Quantity,
            spec.UnitPrice,
            spec.DiscountAmount,
            spec.TaxRatePercent,
            orderIndex);
    }
}

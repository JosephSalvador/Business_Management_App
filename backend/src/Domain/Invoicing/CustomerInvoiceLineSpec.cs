namespace BusinessOS.Domain.Invoicing;

public sealed record CustomerInvoiceLineSpec(
    string Description,
    decimal Quantity,
    decimal UnitPrice,
    decimal TaxRatePercent = 0m,
    string UnitOfMeasure = "Pcs",
    decimal DiscountAmount = 0m);


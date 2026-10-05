using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Domain.Sales;

namespace BusinessOS.Application.Features.Sales;

internal static class SalesMappers
{
    internal static SaleDto ToDto(Sale sale) => new(
        sale.Id,
        sale.TenantId,
        sale.BranchId,
        sale.WarehouseId,
        sale.CashierId,
        sale.Number,
        sale.ClientSaleId,
        sale.Source,
        sale.Status,
        sale.SaleDate,
        sale.EffectiveAt,
        sale.Currency,
        sale.PriceListId,
        sale.IsPriceTaxInclusive,
        sale.IsElectronicPayment,
        sale.CustomerName is null && sale.BuyerMobile is null && sale.CustomerTin is null && sale.IsVatRegistered is null
            ? null
            : new SaleCustomerDto(sale.CustomerName, sale.BuyerMobile, sale.CustomerTin, sale.IsVatRegistered),
        sale.Subtotal,
        sale.DiscountAmount,
        sale.TaxAmount,
        sale.TotalAmount,
        sale.AmountPaid,
        sale.Change,
        sale.Lines.Select(ToLineDto).ToList(),
        sale.Payments.Select(ToPaymentDto).ToList(),
        sale.CreatedAt,
        sale.UpdatedAt,
        sale.VoidedAt,
        sale.VoidedBy,
        sale.VoidReason);

    internal static SaleLineDto ToLineDto(SaleLine line) => new(
        line.Id,
        line.ProductId,
        line.VariantId,
        line.ProductName,
        line.Sku,
        line.Barcode,
        line.UnitOfMeasureId,
        line.UnitOfMeasureName,
        line.Quantity,
        line.UnitPrice,
        line.DiscountAmount,
        line.TaxCode,
        line.AppliedRate,
        line.AppliedRuleId,
        line.BaseAmount,
        line.TaxAmount,
        line.LineTotal,
        line.OrderIndex,
        line.UnitCost);

    internal static SalePaymentDto ToPaymentDto(SalePayment payment) => new(
        payment.Id,
        payment.Method,
        payment.Amount,
        payment.Provider,
        payment.PhoneNumber,
        payment.Reference,
        payment.OrderIndex);
}

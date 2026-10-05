using System.Globalization;
using BusinessOS.Application.Features.Receipts.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Receipts.Queries;

/// <summary>
/// Returns the data needed to render a receipt preview for a sale, including the sale data,
/// receipt metadata, business identity snapshot, and print event count (to detect reprints).
/// </summary>
public sealed record GetReceiptPreviewQuery(Guid SaleId) : IRequest<Result<ReceiptPreviewDto>>;

public sealed class GetReceiptPreviewQueryHandler : IRequestHandler<GetReceiptPreviewQuery, Result<ReceiptPreviewDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISaleRepository _sales;
    private readonly IReceiptMetadataRepository _metadata;
    private readonly IReceiptPrintEventRepository _printEvents;
    private readonly IReceiptLayoutRepository _layouts;
    private readonly IUserRepository _users;
    private readonly IBranchRepository _branches;

    public GetReceiptPreviewQueryHandler(
        ITenantContext tenantContext,
        ISaleRepository sales,
        IReceiptMetadataRepository metadata,
        IReceiptPrintEventRepository printEvents,
        IReceiptLayoutRepository layouts,
        IUserRepository users,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _sales = sales;
        _metadata = metadata;
        _printEvents = printEvents;
        _layouts = layouts;
        _users = users;
        _branches = branches;
    }

    public async Task<Result<ReceiptPreviewDto>> Handle(
        GetReceiptPreviewQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var sale = await _sales.GetByIdAsync(tenantId, query.SaleId, cancellationToken);
        if (sale is null)
        {
            return Error.NotFound("Sale not found.");
        }

        var metadata = await _metadata.GetBySaleIdAsync(query.SaleId, cancellationToken);
        var printCount = await _printEvents.CountBySaleIdAsync(query.SaleId, cancellationToken);
        BusinessIdentitySnapshot? identity = null;
        string? layoutId = null;

        if (metadata is not null)
        {
            identity = BusinessIdentitySnapshot.FromJson(metadata.BusinessIdentitySnapshot);
            var layout = await _layouts.GetByIdAsync(tenantId, metadata.LayoutVersionId, cancellationToken);
            layoutId = layout?.LayoutId;
        }

        var cashier = await _users.GetByIdAsync(tenantId, sale.CashierId, cancellationToken);
        var branch = await _branches.GetByIdAsync(tenantId, sale.BranchId, cancellationToken);

        return new ReceiptPreviewDto(
            SaleId: sale.Id,
            SaleNumber: sale.Number,
            SaleDate: sale.SaleDate,
            IsVoided: sale.Status == SaleStatus.Voided,
            HasMetadata: metadata is not null,
            IsReprint: printCount > 0,
            PrintCount: printCount,
            BusinessName: identity?.BusinessName ?? "Business",
            TIN: identity?.TIN,
            Address: identity?.Address,
            Phone: identity?.Phone,
            Email: identity?.Email,
            BranchName: branch?.Name,
            CashierName: cashier?.FullName,
            CustomerName: sale.CustomerName,
            Currency: sale.Currency,
            LayoutId: layoutId,
            FiscalHash: metadata?.FiscalHash,
            QrPayload: BuildQrPayload(
                metadata?.FiscalHash,
                sale.Number,
                sale.TotalAmount,
                sale.SaleDate,
                identity?.BusinessName ?? "Business",
                sale.Currency),
            Lines: sale.Lines.Select(l => new ReceiptLineDto(
                l.ProductName,
                l.Quantity,
                l.UnitPrice,
                l.DiscountAmount,
                l.LineTotal,
                l.TaxCode,
                l.TaxAmount)).ToList(),
            Payments: sale.Payments.Select(p => new ReceiptPaymentDto(
                p.Method.ToString(),
                p.Amount,
                p.Reference)).ToList(),
            Subtotal: sale.Subtotal,
            TaxAmount: sale.TaxAmount,
            DiscountAmount: sale.DiscountAmount,
            TotalAmount: sale.TotalAmount,
            AmountPaid: sale.AmountPaid,
            Change: sale.Change);
    }

    private static string BuildQrPayload(
        string? fiscalHash,
        string saleNumber,
        decimal totalAmount,
        DateTime saleDate,
        string businessName,
        string currency)
    {
        var dateStr = saleDate.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture);
        var totalStr = totalAmount.ToString("N0", CultureInfo.InvariantCulture);

        // The QR total must read the same as the receipt's GRAND TOTAL row, so it
        // carries the tenant currency code verbatim (empty/unknown → platform default).
        var currencyCode = string.IsNullOrWhiteSpace(currency)
            ? "TZS"
            : currency.Trim().ToUpperInvariant();

        var payload = $"{businessName}\nRISITI: {saleNumber}\nJUMLA: {currencyCode} {totalStr}\nTAREHE: {dateStr}";

        if (!string.IsNullOrEmpty(fiscalHash))
        {
            var shortHash = fiscalHash.Length > 8
                ? fiscalHash[..8]
                : fiscalHash;
            payload += $"\nTHIBITISHO: {shortHash}";
        }

        return payload;
    }
}

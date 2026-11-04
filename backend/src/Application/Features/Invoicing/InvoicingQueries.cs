using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Invoicing.Queries;

// ── List Customer Invoices ───────────────────────────────────────────
public sealed record ListCustomerInvoicesQuery(
    int Page,
    int PageSize,
    CustomerInvoiceStatus? Status = null,
    Guid? CustomerId = null,
    string? Search = null)
    : IRequest<Result<PagedResult<CustomerInvoiceSummaryDto>>>;

public sealed class ListCustomerInvoicesQueryHandler
    : IRequestHandler<ListCustomerInvoicesQuery, Result<PagedResult<CustomerInvoiceSummaryDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerInvoiceRepository _invoices;

    public ListCustomerInvoicesQueryHandler(
        ITenantContext tenantContext, ICustomerInvoiceRepository invoices)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
    }

    public async Task<Result<PagedResult<CustomerInvoiceSummaryDto>>> Handle(
        ListCustomerInvoicesQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var filter = new CustomerInvoiceListFilter(query.Status, query.CustomerId, query.Search);
        var items = await _invoices.ListAsync(
            tenantId, query.Page, query.PageSize, filter, cancellationToken);
        var total = await _invoices.CountAsync(tenantId, filter, cancellationToken);

        return Result.Success(new PagedResult<CustomerInvoiceSummaryDto>(
            items.Select(CustomerInvoiceMappers.ToSummary).ToList(),
            query.Page,
            query.PageSize,
            total));
    }
}

// ── Get Customer Invoice ─────────────────────────────────────────────
public sealed record GetCustomerInvoiceQuery(Guid Id)
    : IRequest<Result<CustomerInvoiceDto>>;

public sealed class GetCustomerInvoiceQueryHandler
    : IRequestHandler<GetCustomerInvoiceQuery, Result<CustomerInvoiceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerInvoiceRepository _invoices;

    public GetCustomerInvoiceQueryHandler(
        ITenantContext tenantContext, ICustomerInvoiceRepository invoices)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
    }

    public async Task<Result<CustomerInvoiceDto>> Handle(
        GetCustomerInvoiceQuery query, CancellationToken cancellationToken)
    {
        var invoice = await _invoices.GetByIdAsync(
            _tenantContext.TenantId, query.Id, cancellationToken);
        if (invoice is null)
        {
            return Error.NotFound("Invoice not found.");
        }

        return Result.Success(CustomerInvoiceMappers.ToDto(invoice));
    }
}

// ── Get Public Invoice Verification ──────────────────────────────────
public sealed record GetPublicInvoiceVerificationQuery(string Token)
    : IRequest<Result<PublicInvoiceVerificationDto>>;

public sealed class GetPublicInvoiceVerificationQueryHandler
    : IRequestHandler<GetPublicInvoiceVerificationQuery, Result<PublicInvoiceVerificationDto>>
{
    private readonly ICustomerInvoiceRepository _invoices;
    private readonly ITenantRepository _tenants;

    public GetPublicInvoiceVerificationQueryHandler(
        ICustomerInvoiceRepository invoices,
        ITenantRepository tenants)
    {
        _invoices = invoices;
        _tenants = tenants;
    }

    public async Task<Result<PublicInvoiceVerificationDto>> Handle(
        GetPublicInvoiceVerificationQuery query, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(query.Token))
        {
            return Error.Validation("Verification token is required.");
        }

        var invoice = await _invoices.GetByVerificationTokenAsync(query.Token.Trim(), cancellationToken);
        if (invoice is null)
        {
            return Error.NotFound("Invoice not found or invalid verification token.");
        }

        var tenant = await _tenants.GetByIdAsync(invoice.TenantId, cancellationToken);
        var orgDto = new PublicInvoiceVerificationTenantDto(
            tenant?.Name ?? "Verified Merchant",
            tenant?.TaxId,
            tenant?.ContactEmail,
            tenant?.ContactPhone,
            tenant?.Address,
            tenant?.LogoBase64,
            tenant?.BankName,
            tenant?.BankAccountName,
            tenant?.BankAccountNumber,
            tenant?.BankBranchOrSwift,
            tenant?.MobileMoneyDetails,
            tenant?.PaymentAccountsJson,
            tenant?.InvoiceTerms);

        var lines = invoice.Lines
            .OrderBy(l => l.OrderIndex)
            .Select(l => new PublicInvoiceVerificationLineDto(
                l.Id,
                l.Description,
                l.Quantity,
                l.UnitPrice,
                l.TaxRatePercent,
                l.LineTotal,
                l.TaxAmount,
                l.UnitOfMeasure,
                l.DiscountAmount))
            .ToList();

        var payments = invoice.GetPayments()
            .Select(p => new CustomerInvoicePaymentDto(
                p.Id, p.Amount, p.Method, p.Reference, p.PaidAtUtc))
            .ToList();

        var dto = new PublicInvoiceVerificationDto(
            invoice.Id,
            invoice.Number,
            invoice.VerificationToken,
            invoice.DocumentTitle,
            invoice.ReferenceNumber,
            invoice.PaymentTerms,
            invoice.CustomerName,
            invoice.CustomerAttention,
            invoice.CustomerPhone,
            invoice.CustomerEmail,
            invoice.CustomerAddress,
            invoice.CustomerTin,
            invoice.Currency,
            invoice.IssueDate,
            invoice.DueDate,
            invoice.Status,
            invoice.Subtotal,
            invoice.DiscountAmount,
            invoice.TaxAmount,
            invoice.TotalAmount,
            invoice.AmountPaid,
            invoice.BalanceDue,
            invoice.PaymentInstructions,
            invoice.Notes,
            invoice.AuthorizedSignatoryName,
            invoice.AuthorizedSignatoryTitle,
            invoice.PaidAtUtc,
            lines,
            payments,
            orgDto,
            DateTime.UtcNow,
            IsAuthentic: true);

        return Result.Success(dto);
    }
}

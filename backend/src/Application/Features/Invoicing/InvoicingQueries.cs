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

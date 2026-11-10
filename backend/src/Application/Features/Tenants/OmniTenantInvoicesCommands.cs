using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants;

public sealed record ListTenantInvoicesAdminQuery(
    Guid TenantId,
    string? Search = null,
    string? Status = null,
    int Page = 1,
    int PageSize = 25) : IRequest<Result<PagedResult<OmniInvoiceSummaryDto>>>;

public sealed class ListTenantInvoicesAdminQueryHandler : IRequestHandler<ListTenantInvoicesAdminQuery, Result<PagedResult<OmniInvoiceSummaryDto>>>
{
    private readonly IOmniTenantInvoicesRepository _invoices;

    public ListTenantInvoicesAdminQueryHandler(IOmniTenantInvoicesRepository invoices) => _invoices = invoices;

    public async Task<Result<PagedResult<OmniInvoiceSummaryDto>>> Handle(
        ListTenantInvoicesAdminQuery request, CancellationToken cancellationToken)
    {
        var result = await _invoices.ListTenantInvoicesAsync(
            request.TenantId, request.Search, request.Status, request.Page, request.PageSize, cancellationToken);

        return Result.Success(result);
    }
}

public sealed record UpdateTenantInvoiceStatusAdminCommand(
    Guid TenantId,
    Guid InvoiceId,
    string NewStatus) : IRequest<Result>;

public sealed class UpdateTenantInvoiceStatusAdminCommandHandler : IRequestHandler<UpdateTenantInvoiceStatusAdminCommand, Result>
{
    private readonly IOmniTenantInvoicesRepository _invoices;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public UpdateTenantInvoiceStatusAdminCommandHandler(
        IOmniTenantInvoicesRepository invoices,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _invoices = invoices;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(
        UpdateTenantInvoiceStatusAdminCommand request, CancellationToken cancellationToken)
    {
        var invoice = await _invoices.GetInvoiceByIdAsync(request.TenantId, request.InvoiceId, cancellationToken);
        if (invoice is null)
        {
            return Error.NotFound($"Invoice {request.InvoiceId} was not found.");
        }

        if (!Enum.TryParse<CustomerInvoiceStatus>(request.NewStatus, true, out var newStatusEnum))
        {
            return Error.Validation("Invalid invoice status.");
        }

        await _invoices.UpdateInvoiceStatusAsync(invoice, newStatusEnum, cancellationToken);

        await _auditLogs.AddAsync(
            AuditLog.Create(
                request.TenantId,
                _tenantContext.UserId,
                "PlatformOperator.UpdateInvoiceStatus",
                "CustomerInvoice",
                invoice.Id,
                $"Invoice status updated to {newStatusEnum} by Platform Operator"),
            cancellationToken);

        return Result.Success();
    }
}

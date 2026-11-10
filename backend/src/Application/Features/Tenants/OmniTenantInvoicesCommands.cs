using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Application.Features.Tenants;

public sealed record TenantInvoiceAdminDto(
    Guid Id,
    string Number,
    string CustomerName,
    DateTime IssueDate,
    DateTime DueDate,
    decimal TotalAmount,
    decimal AmountPaid,
    decimal BalanceDue,
    string Status,
    string Currency);

public sealed record PagedTenantInvoicesResult(
    IReadOnlyList<TenantInvoiceAdminDto> Items,
    int TotalCount,
    int Page,
    int PageSize);

// ── 1. List Invoices for Tenant ──────────────────────────────────
public sealed record ListTenantInvoicesAdminQuery(
    Guid TenantId,
    string? Status = null,
    int Page = 1,
    int PageSize = 50)
    : IRequest<Result<PagedTenantInvoicesResult>>;

public sealed class ListTenantInvoicesAdminQueryHandler
    : IRequestHandler<ListTenantInvoicesAdminQuery, Result<PagedTenantInvoicesResult>>
{
    private readonly BusinessDbContext _db;

    public ListTenantInvoicesAdminQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<PagedTenantInvoicesResult>> Handle(
        ListTenantInvoicesAdminQuery request, CancellationToken cancellationToken)
    {
        var page = request.Page > 0 ? request.Page : 1;
        var pageSize = request.PageSize is > 0 and <= 100 ? request.PageSize : 50;

        var query = _db.CustomerInvoices
            .IgnoreQueryFilters()
            .Where(i => i.TenantId == request.TenantId);

        if (!string.IsNullOrWhiteSpace(request.Status) &&
            Enum.TryParse<CustomerInvoiceStatus>(request.Status, true, out var parsedStatus))
        {
            query = query.Where(i => i.Status == parsedStatus);
        }

        var total = await query.CountAsync(cancellationToken);

        var invoices = await query
            .OrderByDescending(i => i.IssueDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var dtos = invoices.Select(i => new TenantInvoiceAdminDto(
            i.Id,
            i.Number,
            i.CustomerName,
            i.IssueDate,
            i.DueDate,
            i.TotalAmount,
            i.AmountPaid,
            i.BalanceDue,
            i.Status.ToString(),
            i.Currency)).ToList();

        return Result.Success(new PagedTenantInvoicesResult(dtos, total, page, pageSize));
    }
}

// ── 2. Update Invoice Status ─────────────────────────────────────
public sealed record UpdateTenantInvoiceStatusAdminCommand(
    Guid TenantId,
    Guid InvoiceId,
    string NewStatus)
    : IRequest<Result<TenantInvoiceAdminDto>>;

public sealed class UpdateTenantInvoiceStatusAdminCommandHandler
    : IRequestHandler<UpdateTenantInvoiceStatusAdminCommand, Result<TenantInvoiceAdminDto>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public UpdateTenantInvoiceStatusAdminCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<TenantInvoiceAdminDto>> Handle(
        UpdateTenantInvoiceStatusAdminCommand command, CancellationToken cancellationToken)
    {
        if (!Enum.TryParse<CustomerInvoiceStatus>(command.NewStatus, true, out var targetStatus))
        {
            return Error.Validation($"Invalid invoice status '{command.NewStatus}'.");
        }

        var invoice = await _db.CustomerInvoices
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(i => i.TenantId == command.TenantId && i.Id == command.InvoiceId, cancellationToken);

        if (invoice is null)
        {
            return Error.NotFound("Invoice not found.");
        }

        if (targetStatus == CustomerInvoiceStatus.Paid)
        {
            invoice.RecordPayment(invoice.BalanceDue, DateTime.UtcNow, "Platform Admin Reconciliation", null);
        }
        else if (targetStatus == CustomerInvoiceStatus.Cancelled)
        {
            invoice.Cancel("Cancelled by Platform Operator");
        }

        await _db.SaveChangesAsync(cancellationToken);

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        await _auditLogs.AddAsync(AuditLog.Create(
            command.TenantId,
            operatorUserId,
            "Platform.InvoiceStatusUpdate",
            "CustomerInvoice",
            invoice.Id.ToString()),
            cancellationToken);

        return Result.Success(new TenantInvoiceAdminDto(
            invoice.Id,
            invoice.Number,
            invoice.CustomerName,
            invoice.IssueDate,
            invoice.DueDate,
            invoice.TotalAmount,
            invoice.AmountPaid,
            invoice.BalanceDue,
            invoice.Status.ToString(),
            invoice.Currency));
    }
}

using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Finance;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Sales;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Application.Features.Tenants;

public sealed record TenantSaleAdminDto(
    Guid Id,
    string Number,
    string Status,
    decimal TotalAmount,
    string? CustomerName,
    string? CustomerPhone,
    string PaymentMethods,
    string? CashierName,
    DateTime CreatedAt,
    int LineCount);

public sealed record PagedTenantSalesResult(
    IReadOnlyList<TenantSaleAdminDto> Items,
    int TotalCount,
    int Page,
    int PageSize);

public sealed record TenantSaleDetailAdminDto(
    Guid Id,
    string Number,
    string Status,
    decimal TotalAmount,
    decimal DiscountAmount,
    string? CustomerName,
    string? CustomerPhone,
    string? CashierName,
    DateTime CreatedAt,
    IReadOnlyList<TenantSaleLineDto> Lines,
    IReadOnlyList<TenantSalePaymentDto> Payments);

public sealed record TenantSaleLineDto(
    Guid Id,
    string ProductName,
    decimal Quantity,
    decimal UnitPrice,
    decimal LineTotal,
    decimal DiscountAmount);

public sealed record TenantSalePaymentDto(
    string Method,
    decimal Amount,
    string? Reference);

public sealed record TenantCashSessionAdminDto(
    Guid Id,
    string BranchName,
    string CashierName,
    DateTime OpenedAtUtc,
    DateTime? ClosedAtUtc,
    decimal OpeningCash,
    decimal? ClosingCashActual,
    decimal? ClosingCashExpected,
    decimal? Discrepancy,
    string Status);

// ── 1. List Sales for Tenant ─────────────────────────────────────
public sealed record ListTenantSalesAdminQuery(
    Guid TenantId,
    DateTime? From = null,
    DateTime? To = null,
    int Page = 1,
    int PageSize = 50)
    : IRequest<Result<PagedTenantSalesResult>>;

public sealed class ListTenantSalesAdminQueryHandler
    : IRequestHandler<ListTenantSalesAdminQuery, Result<PagedTenantSalesResult>>
{
    private readonly BusinessDbContext _db;

    public ListTenantSalesAdminQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<PagedTenantSalesResult>> Handle(
        ListTenantSalesAdminQuery request, CancellationToken cancellationToken)
    {
        var page = request.Page > 0 ? request.Page : 1;
        var pageSize = request.PageSize is > 0 and <= 100 ? request.PageSize : 50;

        var query = _db.Sales
            .Include(s => s.Payments)
            .Include(s => s.Lines)
            .Where(s => s.TenantId == request.TenantId);

        if (request.From.HasValue)
        {
            query = query.Where(s => s.CreatedAt >= request.From.Value);
        }

        if (request.To.HasValue)
        {
            query = query.Where(s => s.CreatedAt <= request.To.Value);
        }

        var total = await query.CountAsync(cancellationToken);

        var sales = await query
            .OrderByDescending(s => s.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var userIds = sales.Where(s => s.CashierId.HasValue).Select(s => s.CashierId!.Value).Distinct().ToList();
        var users = await _db.Users
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.FullName, cancellationToken);

        var dtos = sales.Select(s =>
        {
            string? cashierName = null;
            if (s.CashierId.HasValue) users.TryGetValue(s.CashierId.Value, out cashierName);

            var payMethods = string.Join(", ", s.Payments.Select(p => p.Method.ToString()).Distinct());

            return new TenantSaleAdminDto(
                s.Id,
                s.Number,
                s.Status.ToString(),
                s.TotalAmount,
                s.BuyerName,
                s.BuyerMobile,
                string.IsNullOrEmpty(payMethods) ? "Cash" : payMethods,
                cashierName ?? "Cashier",
                s.CreatedAt,
                s.Lines.Count);
        }).ToList();

        return Result.Success(new PagedTenantSalesResult(dtos, total, page, pageSize));
    }
}

// ── 2. Get Sale Detail for Tenant ────────────────────────────────
public sealed record GetTenantSaleDetailAdminQuery(
    Guid TenantId,
    Guid SaleId)
    : IRequest<Result<TenantSaleDetailAdminDto>>;

public sealed class GetTenantSaleDetailAdminQueryHandler
    : IRequestHandler<GetTenantSaleDetailAdminQuery, Result<TenantSaleDetailAdminDto>>
{
    private readonly BusinessDbContext _db;

    public GetTenantSaleDetailAdminQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<TenantSaleDetailAdminDto>> Handle(
        GetTenantSaleDetailAdminQuery request, CancellationToken cancellationToken)
    {
        var sale = await _db.Sales
            .Include(s => s.Lines)
            .Include(s => s.Payments)
            .FirstOrDefaultAsync(s => s.TenantId == request.TenantId && s.Id == request.SaleId, cancellationToken);

        if (sale is null) return Error.NotFound("Sale not found.");

        string? cashierName = null;
        if (sale.CashierId.HasValue)
        {
            cashierName = await _db.Users
                .Where(u => u.Id == sale.CashierId.Value)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync(cancellationToken);
        }

        var lines = sale.Lines.Select(l => new TenantSaleLineDto(
            l.Id,
            l.ProductName,
            l.Quantity,
            l.UnitPrice,
            l.LineTotal,
            l.DiscountAmount)).ToList();

        var payments = sale.Payments.Select(p => new TenantSalePaymentDto(
            p.Method.ToString(),
            p.Amount,
            p.ExternalReference)).ToList();

        return Result.Success(new TenantSaleDetailAdminDto(
            sale.Id,
            sale.Number,
            sale.Status.ToString(),
            sale.TotalAmount,
            sale.DiscountAmount,
            sale.BuyerName,
            sale.BuyerMobile,
            cashierName,
            sale.CreatedAt,
            lines,
            payments));
    }
}

// ── 3. Void Sale for Tenant ──────────────────────────────────────
public sealed record VoidTenantSaleAdminCommand(
    Guid TenantId,
    Guid SaleId,
    string Reason)
    : IRequest<Result<bool>>;

public sealed class VoidTenantSaleAdminCommandHandler
    : IRequestHandler<VoidTenantSaleAdminCommand, Result<bool>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public VoidTenantSaleAdminCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<bool>> Handle(
        VoidTenantSaleAdminCommand command, CancellationToken cancellationToken)
    {
        var sale = await _db.Sales
            .Include(s => s.Lines)
            .FirstOrDefaultAsync(s => s.TenantId == command.TenantId && s.Id == command.SaleId, cancellationToken);

        if (sale is null) return Error.NotFound("Sale not found.");
        if (sale.Status == SaleStatus.Voided) return Error.Conflict("Sale is already voided.");

        sale.Void(command.Reason);

        // Reversal of inventory movements
        foreach (var line in sale.Lines)
        {
            if (line.ProductType != Domain.Catalog.ProductType.Goods) continue;

            var balance = await _db.StockBalances
                .FirstOrDefaultAsync(b => b.TenantId == command.TenantId && b.ProductId == line.ProductId, cancellationToken);

            if (balance is not null)
            {
                balance.Adjust(line.Quantity);

                var movement = StockMovement.Create(
                    command.TenantId,
                    line.ProductId,
                    line.VariantId,
                    balance.WarehouseId,
                    balance.LocationId,
                    StockMovementType.Adjustment,
                    line.Quantity,
                    $"Platform Void Sale Reversal {sale.Number}: {command.Reason}",
                    "PLATFORM_VOID",
                    _tenantContext.UserId?.ToString());

                await _db.StockMovements.AddAsync(movement, cancellationToken);
            }
        }

        await _db.SaveChangesAsync(cancellationToken);

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        await _auditLogs.AddAsync(AuditLog.Create(
            command.TenantId,
            operatorUserId,
            "Platform.VoidSale",
            "Sale",
            sale.Id.ToString()),
            cancellationToken);

        return Result.Success(true);
    }
}

// ── 4. List Cash Sessions for Tenant ─────────────────────────────
public sealed record ListTenantCashSessionsAdminQuery(
    Guid TenantId,
    int Page = 1,
    int PageSize = 30)
    : IRequest<Result<IReadOnlyList<TenantCashSessionAdminDto>>>;

public sealed class ListTenantCashSessionsAdminQueryHandler
    : IRequestHandler<ListTenantCashSessionsAdminQuery, Result<IReadOnlyList<TenantCashSessionAdminDto>>>
{
    private readonly BusinessDbContext _db;

    public ListTenantCashSessionsAdminQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<IReadOnlyList<TenantCashSessionAdminDto>>> Handle(
        ListTenantCashSessionsAdminQuery request, CancellationToken cancellationToken)
    {
        var page = request.Page > 0 ? request.Page : 1;
        var pageSize = request.PageSize is > 0 and <= 100 ? request.PageSize : 30;

        var sessions = await _db.Set<CashSession>()
            .Where(s => s.TenantId == request.TenantId)
            .OrderByDescending(s => s.OpenedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var cashierIds = sessions.Select(s => s.CashierUserId).Distinct().ToList();
        var cashiers = await _db.Users
            .Where(u => cashierIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.FullName, cancellationToken);

        var branchIds = sessions.Select(s => s.BranchId).Distinct().ToList();
        var branches = await _db.Branches
            .Where(b => branchIds.Contains(b.Id))
            .ToDictionaryAsync(b => b.Id, b => b.Name, cancellationToken);

        var dtos = sessions.Select(s =>
        {
            cashiers.TryGetValue(s.CashierUserId, out var cashierName);
            branches.TryGetValue(s.BranchId, out var branchName);

            return new TenantCashSessionAdminDto(
                s.Id,
                branchName ?? "Duka Kuu",
                cashierName ?? "Cashier",
                s.OpenedAtUtc,
                s.ClosedAtUtc,
                s.OpeningCash,
                s.ClosingCashActual,
                s.ClosingCashExpected,
                s.Discrepancy,
                s.Status.ToString());
        }).ToList();

        return Result.Success<IReadOnlyList<TenantCashSessionAdminDto>>(dtos);
    }
}

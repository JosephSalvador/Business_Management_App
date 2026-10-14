using BusinessOS.Application.Features.Purchasing.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Reports.Queries;

// ── Tax Summary ──────────────────────────────────────────────────
public sealed record TaxSummaryQuery(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<TaxSummaryDto>>, IRequiresTenantAdvisoryLock;

public sealed class TaxSummaryQueryHandler
    : IRequestHandler<TaxSummaryQuery, Result<TaxSummaryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public TaxSummaryQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<TaxSummaryDto>> Handle(
        TaxSummaryQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var lines = await _reports.GetTaxSummaryAsync(
            tenantId, query.From, query.To, query.BranchId, cancellationToken);

        var lineDtos = lines.Select(l => new TaxSummaryLineDto(
            l.TaxCode, l.AppliedRate,
            l.TotalBaseAmount, l.TotalTaxAmount, l.TotalLineTotal, l.SaleCount)).ToList();

        return Result.Success(new TaxSummaryDto(
            query.From, query.To, lineDtos,
            lineDtos.Sum(l => l.TotalBaseAmount),
            lineDtos.Sum(l => l.TotalTaxAmount),
            lineDtos.Sum(l => l.TotalLineTotal)));
    }
}

// ── Sales Summary ────────────────────────────────────────────────
public sealed record SalesSummaryQuery(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<SalesSummaryDto>>, IRequiresTenantAdvisoryLock;

public sealed class SalesSummaryQueryHandler
    : IRequestHandler<SalesSummaryQuery, Result<SalesSummaryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public SalesSummaryQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<SalesSummaryDto>> Handle(
        SalesSummaryQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var (totalSales, totalRevenue, totalTax, totalDiscount, averageSale, byBranch) =
            await _reports.GetSalesSummaryAsync(
                tenantId, query.From, query.To, query.BranchId, cancellationToken);

        var branchDtos = byBranch.Select(b => new SalesByBranchSummaryDto(
            b.BranchId, b.BranchName, b.TotalSales, b.TotalRevenue)).ToList();

        return Result.Success(new SalesSummaryDto(
            query.From, query.To,
            totalSales, totalRevenue, totalTax, totalDiscount, averageSale,
            branchDtos));
    }
}

// ── Top Products ─────────────────────────────────────────────────
public sealed record TopProductsQuery(DateTime From, DateTime To, int Limit, Guid? BranchId)
    : IRequest<Result<TopProductsDto>>, IRequiresTenantAdvisoryLock;

public sealed class TopProductsQueryHandler
    : IRequestHandler<TopProductsQuery, Result<TopProductsDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public TopProductsQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<TopProductsDto>> Handle(
        TopProductsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var rows = await _reports.GetTopProductsAsync(
            tenantId, query.From, query.To, query.Limit, query.BranchId, cancellationToken);

        var productDtos = rows.Select(r => new TopProductDto(
            r.ProductId, r.ProductName, r.Sku,
            r.TotalQuantity, r.TotalRevenue, r.TotalTax, r.Rank,
            r.TotalCost, r.TotalProfit, r.MarginPercent)).ToList();

        return Result.Success(new TopProductsDto(query.From, query.To, productDtos));
    }
}

// ── Dashboard Tax KPIs ───────────────────────────────────────────
public sealed record DashboardTaxKpisQuery()
    : IRequest<Result<DashboardTaxKpisDto>>, IRequiresTenantAdvisoryLock;

public sealed class DashboardTaxKpisQueryHandler
    : IRequestHandler<DashboardTaxKpisQuery, Result<DashboardTaxKpisDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public DashboardTaxKpisQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<DashboardTaxKpisDto>> Handle(
        DashboardTaxKpisQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var now = DateTime.UtcNow;
        var from = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = from.AddMonths(1).AddTicks(-1);

        var taxLines = await _reports.GetTaxSummaryAsync(tenantId, from, to, null, cancellationToken);
        var topProducts = await _reports.GetTopProductsAsync(tenantId, from, to, 5, null, cancellationToken);

        var taxLineDtos = taxLines.Select(l => new TaxSummaryLineDto(
            l.TaxCode, l.AppliedRate,
            l.TotalBaseAmount, l.TotalTaxAmount, l.TotalLineTotal, l.SaleCount)).ToList();

        var topProductDtos = topProducts.Select(r => new TopProductDto(
            r.ProductId, r.ProductName, r.Sku,
            r.TotalQuantity, r.TotalRevenue, r.TotalTax, r.Rank,
            r.TotalCost, r.TotalProfit, r.MarginPercent)).ToList();

        return Result.Success(new DashboardTaxKpisDto(
            taxLineDtos.Sum(l => l.TotalBaseAmount),
            taxLineDtos.Sum(l => l.TotalTaxAmount),
            taxLineDtos,
            topProductDtos));
    }
}

// ── Sales Trend ──────────────────────────────────────────────────
public sealed record SalesTrendQuery(int Days, Guid? BranchId)
    : IRequest<Result<SalesTrendDto>>, IRequiresTenantAdvisoryLock;

public sealed class SalesTrendQueryHandler
    : IRequestHandler<SalesTrendQuery, Result<SalesTrendDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public SalesTrendQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<SalesTrendDto>> Handle(
        SalesTrendQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var now = DateTime.UtcNow;
        var from = now.Date.AddDays(-query.Days + 1);
        var to = now.Date.AddDays(1).AddTicks(-1);

        var points = await _reports.GetSalesTrendAsync(
            tenantId, from, to, query.BranchId, cancellationToken);

        var pointDtos = points.Select(p => new SalesTrendPointDto(
            p.Label, p.SaleCount, p.Revenue, p.Tax)).ToList();

        return Result.Success(new SalesTrendDto(from, to, query.Days, pointDtos));
    }
}

// ── Export Tax Summary ───────────────────────────────────────────
public sealed record ExportTaxSummaryCommand(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<ExportResultDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExportTaxSummaryCommandHandler
    : IRequestHandler<ExportTaxSummaryCommand, Result<ExportResultDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;
    private readonly ICsvExportService _csv;

    public ExportTaxSummaryCommandHandler(
        ITenantContext tenantContext, IReportRepository reports, ICsvExportService csv)
    {
        _tenantContext = tenantContext;
        _reports = reports;
        _csv = csv;
    }

    public async Task<Result<ExportResultDto>> Handle(
        ExportTaxSummaryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var lines = await _reports.GetTaxSummaryAsync(
            tenantId, command.From, command.To, command.BranchId, cancellationToken);

        var headers = new[] { "Tax Code", "Rate %", "Base Amount", "Tax Amount", "Line Total", "Sale Count" };
        var bytes = _csv.Export(lines, headers, l => new object[]
        {
            l.TaxCode, l.AppliedRate * 100, l.TotalBaseAmount, l.TotalTaxAmount, l.TotalLineTotal, l.SaleCount
        });

        var fileName = $"tax-summary-{command.From:yyyyMMdd}-{command.To:yyyyMMdd}.csv";
        return Result.Success(new ExportResultDto(bytes, "text/csv", fileName));
    }
}

// ── Export Sales Summary ─────────────────────────────────────────
public sealed record ExportSalesSummaryCommand(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<ExportResultDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExportSalesSummaryCommandHandler
    : IRequestHandler<ExportSalesSummaryCommand, Result<ExportResultDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;
    private readonly ICsvExportService _csv;

    public ExportSalesSummaryCommandHandler(
        ITenantContext tenantContext, IReportRepository reports, ICsvExportService csv)
    {
        _tenantContext = tenantContext;
        _reports = reports;
        _csv = csv;
    }

    public async Task<Result<ExportResultDto>> Handle(
        ExportSalesSummaryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var (totalSales, totalRevenue, totalTax, totalDiscount, averageSale, byBranch) =
            await _reports.GetSalesSummaryAsync(
                tenantId, command.From, command.To, command.BranchId, cancellationToken);

        var headers = new[] { "Branch", "Total Sales", "Total Revenue" };
        var bytes = _csv.Export(byBranch, headers, b => new object[]
        {
            b.BranchName, b.TotalSales, b.TotalRevenue
        });

        var fileName = $"sales-summary-{command.From:yyyyMMdd}-{command.To:yyyyMMdd}.csv";
        return Result.Success(new ExportResultDto(bytes, "text/csv", fileName));
    }
}

// ── Export Top Products ──────────────────────────────────────────
public sealed record ExportTopProductsCommand(DateTime From, DateTime To, int Limit, Guid? BranchId)
    : IRequest<Result<ExportResultDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExportTopProductsCommandHandler
    : IRequestHandler<ExportTopProductsCommand, Result<ExportResultDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;
    private readonly ICsvExportService _csv;

    public ExportTopProductsCommandHandler(
        ITenantContext tenantContext, IReportRepository reports, ICsvExportService csv)
    {
        _tenantContext = tenantContext;
        _reports = reports;
        _csv = csv;
    }

    public async Task<Result<ExportResultDto>> Handle(
        ExportTopProductsCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var rows = await _reports.GetTopProductsAsync(
            tenantId, command.From, command.To, command.Limit, command.BranchId, cancellationToken);

        var headers = new[] { "Rank", "Product", "SKU", "Quantity", "Revenue", "Tax", "Cost", "Profit", "Margin %" };
        var bytes = _csv.Export(rows, headers, r => new object[]
        {
            r.Rank, r.ProductName, r.Sku ?? "", r.TotalQuantity, r.TotalRevenue, r.TotalTax, r.TotalCost, r.TotalProfit, $"{r.MarginPercent}%"
        });

        var fileName = $"top-products-{command.From:yyyyMMdd}-{command.To:yyyyMMdd}.csv";
        return Result.Success(new ExportResultDto(bytes, "text/csv", fileName));
    }
}

// ── Business Overview ───────────────────────────────────────────
public sealed record BusinessOverviewQuery(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<BusinessOverviewDto>>, IRequiresTenantAdvisoryLock;

public sealed class BusinessOverviewQueryHandler
    : IRequestHandler<BusinessOverviewQuery, Result<BusinessOverviewDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;
    private readonly IExpenseRepository _expenses;
    private readonly IMoneyAccountRepository _moneyAccounts;

    public BusinessOverviewQueryHandler(
        ITenantContext tenantContext, IReportRepository reports,
        IExpenseRepository expenses, IMoneyAccountRepository moneyAccounts)
    {
        _tenantContext = tenantContext;
        _reports = reports;
        _expenses = expenses;
        _moneyAccounts = moneyAccounts;
    }

    public async Task<Result<BusinessOverviewDto>> Handle(
        BusinessOverviewQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        // Current period
        var (totalSales, totalRevenue, _, _, _, _) = await _reports.GetSalesSummaryAsync(
            tenantId, query.From, query.To, query.BranchId, cancellationToken);
        var topProducts = await _reports.GetTopProductsAsync(
            tenantId, query.From, query.To, 5, query.BranchId, cancellationToken);
        var trend = await _reports.GetSalesTrendAsync(
            tenantId, query.From, query.To, query.BranchId, cancellationToken);

        // Previous period (same duration)
        var duration = query.To - query.From;
        var prevFrom = query.From - duration;
        var prevTo = query.From;
        var (_, prevRevenue, _, _, _, _) = await _reports.GetSalesSummaryAsync(
            tenantId, prevFrom, prevTo, query.BranchId, cancellationToken);

        // Gross profit = revenue - COGS (cost of goods sold via weighted avg purchase price)
        var cogs = await _reports.GetCogsAsync(tenantId, query.From, query.To, cancellationToken);

        // Previous period COGS
        var prevCogs = await _reports.GetCogsAsync(tenantId, prevFrom, prevTo, cancellationToken);

        // Expenses (operating expenses, NOT COGS)
        var expenseSummary = await _expenses.GetSummaryAsync(
            tenantId, query.From, query.To, cancellationToken);
        var prevExpenseSummary = await _expenses.GetSummaryAsync(
            tenantId, prevFrom, prevTo, cancellationToken);

        // Money balance
        var accounts = await _moneyAccounts.ListAsync(tenantId, cancellationToken);
        var moneyBalance = accounts.Sum(a => a.Balance);

        // Gross profit = revenue - COGS
        var grossProfit = totalRevenue - cogs;
        var prevGrossProfit = prevRevenue - prevCogs;

        // Net profit = gross profit - operating expenses
        var netProfit = grossProfit - expenseSummary.Total;

        decimal CalcChange(decimal current, decimal previous) =>
            previous == 0 ? 0 : Math.Round((current - previous) / Math.Abs(previous) * 100, 1);

        return Result.Success(new BusinessOverviewDto(
            new BusinessOverviewKpiDto(totalRevenue, prevRevenue, CalcChange(totalRevenue, prevRevenue), totalRevenue >= prevRevenue),
            new BusinessOverviewKpiDto(grossProfit, prevGrossProfit, CalcChange(grossProfit, prevGrossProfit), grossProfit >= prevGrossProfit),
            new BusinessOverviewKpiDto(expenseSummary.Total, prevExpenseSummary.Total, CalcChange(expenseSummary.Total, prevExpenseSummary.Total), expenseSummary.Total <= prevExpenseSummary.Total),
            new BusinessOverviewKpiDto(moneyBalance, 0, 0, true),
            trend.Select(t => new SalesTrendPointDto(t.Label, t.SaleCount, t.Revenue, t.Tax)).ToList(),
            topProducts.Select(p => new TopProductDto(p.ProductId, p.ProductName, p.Sku, p.TotalQuantity, p.TotalRevenue, p.TotalTax, p.Rank, p.TotalCost, p.TotalProfit, p.MarginPercent)).ToList()));
    }
}

// ── Money Movement ──────────────────────────────────────────────
public sealed record MoneyMovementQuery(DateTime From, DateTime To)
    : IRequest<Result<MoneyMovementDto>>, IRequiresTenantAdvisoryLock;

public sealed class MoneyMovementQueryHandler
    : IRequestHandler<MoneyMovementQuery, Result<MoneyMovementDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;
    private readonly IExpenseRepository _expenses;
    private readonly IMoneyAccountRepository _moneyAccounts;
    private readonly ISender _sender;

    public MoneyMovementQueryHandler(
        ITenantContext tenantContext, IReportRepository reports,
        IExpenseRepository expenses, IMoneyAccountRepository moneyAccounts,
        ISender sender)
    {
        _tenantContext = tenantContext;
        _reports = reports;
        _expenses = expenses;
        _moneyAccounts = moneyAccounts;
        _sender = sender;
    }

    public async Task<Result<MoneyMovementDto>> Handle(
        MoneyMovementQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var accounts = await _moneyAccounts.ListAsync(tenantId, cancellationToken);
        var currentBalance = accounts.Sum(a => a.Balance);

        var (_, totalRevenue, _, _, _, _) = await _reports.GetSalesSummaryAsync(
            tenantId, query.From, query.To, null, cancellationToken);

        var expenseSummary = await _expenses.GetSummaryAsync(
            tenantId, query.From, query.To, cancellationToken);

        var ordersResult = await _sender.Send(
            new ListPurchaseOrdersQuery(1, 1000), cancellationToken);
        var totalPurchases = ordersResult.IsSuccess
            ? ordersResult.Value.Items
                .Where(po => po.CreatedAt >= query.From && po.CreatedAt <= query.To)
                .Sum(po => po.TotalAmount)
            : 0m;

        var startingBalance = currentBalance - totalRevenue + totalPurchases + expenseSummary.Total;

        var moneyIn = new List<MoneyMovementLineDto>
        {
            new("Sales", totalRevenue),
        };
        var moneyOut = new List<MoneyMovementLineDto>
        {
            new("Purchases", totalPurchases),
            new("Expenses", expenseSummary.Total),
        };

        return Result.Success(new MoneyMovementDto(
            startingBalance, moneyIn, moneyOut, currentBalance));
    }
}

// ── Purchases Summary ──────────────────────────────────────────
public sealed record PurchasesSummaryQuery(DateTime From, DateTime To)
    : IRequest<Result<PurchasesSummaryDto>>, IRequiresTenantAdvisoryLock;

public sealed class PurchasesSummaryQueryHandler
    : IRequestHandler<PurchasesSummaryQuery, Result<PurchasesSummaryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISender _sender;

    public PurchasesSummaryQueryHandler(ITenantContext tenantContext, ISender sender)
    {
        _tenantContext = tenantContext;
        _sender = sender;
    }

    public async Task<Result<PurchasesSummaryDto>> Handle(
        PurchasesSummaryQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var result = await _sender.Send(
            new ListPurchaseOrdersQuery(1, 1000), cancellationToken);
        if (result.IsFailure)
            return Result.Failure<PurchasesSummaryDto>(result.Error);

        var filtered = result.Value.Items
            .Where(po => po.CreatedAt >= query.From && po.CreatedAt <= query.To)
            .ToList();

        var totalPurchased = filtered.Sum(po => po.TotalAmount);
        var supplierCount = filtered.Select(po => po.SupplierName).Distinct().Count();
        var itemsReceived = filtered.Count(po => po.Status == Domain.Purchasing.PurchaseOrderStatus.Received);
        var pendingCount = filtered.Count(po => po.Status == Domain.Purchasing.PurchaseOrderStatus.Draft || po.Status == Domain.Purchasing.PurchaseOrderStatus.Submitted);
        var topSupplier = filtered
            .GroupBy(po => po.SupplierName)
            .OrderByDescending(g => g.Sum(po => po.TotalAmount))
            .FirstOrDefault()?.Key;

        return Result.Success(new PurchasesSummaryDto(
            totalPurchased, supplierCount, itemsReceived, topSupplier, pendingCount, itemsReceived));
    }
}

// ── Sales by Payment Method ────────────────────────────────────
public sealed record SalesByPaymentMethodQuery(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<SalesByPaymentMethodReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class SalesByPaymentMethodQueryHandler
    : IRequestHandler<SalesByPaymentMethodQuery, Result<SalesByPaymentMethodReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public SalesByPaymentMethodQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<SalesByPaymentMethodReportDto>> Handle(
        SalesByPaymentMethodQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _reports.GetSalesByPaymentMethodAsync(
            tenantId, query.From, query.To, query.BranchId, cancellationToken);

        var dtos = items.Select(i => new SalesByPaymentMethodDto(
            i.PaymentMethod, i.Amount, i.Count)).ToList();

        return Result.Success(new SalesByPaymentMethodReportDto(query.From, query.To, dtos));
    }
}

// ── Sales by Category ──────────────────────────────────────────
public sealed record SalesByCategoryQuery(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<SalesByCategoryReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class SalesByCategoryQueryHandler
    : IRequestHandler<SalesByCategoryQuery, Result<SalesByCategoryReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public SalesByCategoryQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<SalesByCategoryReportDto>> Handle(
        SalesByCategoryQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _reports.GetSalesByCategoryAsync(
            tenantId, query.From, query.To, query.BranchId, cancellationToken);

        var dtos = items.Select(i => new SalesByCategoryDto(
            i.CategoryName, i.Amount, i.Quantity)).ToList();

        return Result.Success(new SalesByCategoryReportDto(query.From, query.To, dtos));
    }
}

// ── Sales by Staff ─────────────────────────────────────────────
public sealed record SalesByStaffQuery(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<SalesByStaffReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class SalesByStaffQueryHandler
    : IRequestHandler<SalesByStaffQuery, Result<SalesByStaffReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public SalesByStaffQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<SalesByStaffReportDto>> Handle(
        SalesByStaffQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _reports.GetSalesByStaffAsync(
            tenantId, query.From, query.To, query.BranchId, cancellationToken);

        var dtos = items.Select(i => new SalesByStaffDto(
            i.StaffId, i.StaffName, i.SaleCount, i.Revenue)).ToList();

        return Result.Success(new SalesByStaffReportDto(query.From, query.To, dtos));
    }
}

// ── Sales by Customer ──────────────────────────────────────────
public sealed record SalesByCustomerQuery(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<SalesByCustomerReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class SalesByCustomerQueryHandler
    : IRequestHandler<SalesByCustomerQuery, Result<SalesByCustomerReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;

    public SalesByCustomerQueryHandler(ITenantContext tenantContext, IReportRepository reports)
    {
        _tenantContext = tenantContext;
        _reports = reports;
    }

    public async Task<Result<SalesByCustomerReportDto>> Handle(
        SalesByCustomerQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _reports.GetSalesByCustomerAsync(
            tenantId, query.From, query.To, query.BranchId, cancellationToken);

        var dtos = items.Select(i => new SalesByCustomerDto(
            i.CustomerId, i.CustomerName, i.SaleCount, i.Revenue)).ToList();

        return Result.Success(new SalesByCustomerReportDto(query.From, query.To, dtos));
    }
}

// ── Stock Summary ──────────────────────────────────────────────
public sealed record StockSummaryQuery(DateTime From, DateTime To, Guid? WarehouseId)
    : IRequest<Result<StockSummaryReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class StockSummaryQueryHandler
    : IRequestHandler<StockSummaryQuery, Result<StockSummaryReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockRepository _stock;

    public StockSummaryQueryHandler(ITenantContext tenantContext, IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _stock = stock;
    }

    public async Task<Result<StockSummaryReportDto>> Handle(
        StockSummaryQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var rows = await _stock.GetStockSummaryAsync(
            tenantId, query.From, query.To, query.WarehouseId, cancellationToken);

        var dtos = rows.Select(r => new StockSummaryRowDto(
            r.ProductId, r.ProductName, r.Sku,
            r.Opening, r.Purchased, r.Sold, r.Adjusted, r.Closing)).ToList();

        return Result.Success(new StockSummaryReportDto(query.From, query.To, dtos));
    }
}

// ── Stock Movement Summary ─────────────────────────────────────
public sealed record StockMovementSummaryQuery(DateTime From, DateTime To, Guid? WarehouseId)
    : IRequest<Result<StockMovementSummaryReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class StockMovementSummaryQueryHandler
    : IRequestHandler<StockMovementSummaryQuery, Result<StockMovementSummaryReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockRepository _stock;

    public StockMovementSummaryQueryHandler(ITenantContext tenantContext, IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _stock = stock;
    }

    public async Task<Result<StockMovementSummaryReportDto>> Handle(
        StockMovementSummaryQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _stock.GetStockMovementSummaryAsync(
            tenantId, query.From, query.To, query.WarehouseId, cancellationToken);

        var dtos = items.Select(i => new StockMovementSummaryDto(
            i.MovementType, i.Count, i.TotalQuantity)).ToList();

        return Result.Success(new StockMovementSummaryReportDto(query.From, query.To, dtos));
    }
}

// ── Low Stock Report ───────────────────────────────────────────
public sealed record LowStockReportQuery(decimal? Threshold, Guid? WarehouseId)
    : IRequest<Result<LowStockReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class LowStockReportQueryHandler
    : IRequestHandler<LowStockReportQuery, Result<LowStockReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockRepository _stock;

    public LowStockReportQueryHandler(ITenantContext tenantContext, IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _stock = stock;
    }

    public async Task<Result<LowStockReportDto>> Handle(
        LowStockReportQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _stock.GetLowStockReportAsync(
            tenantId, query.Threshold ?? 10, query.WarehouseId, cancellationToken);

        var dtos = items.Select(i => new LowStockReportItemDto(
            i.ProductId, i.ProductName, i.Sku, i.OnHand, i.WarehouseName)).ToList();

        return Result.Success(new LowStockReportDto(dtos));
    }
}

// ── Stock Velocity ─────────────────────────────────────────────
public sealed record StockVelocityQuery(DateTime From, DateTime To)
    : IRequest<Result<StockVelocityReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class StockVelocityQueryHandler
    : IRequestHandler<StockVelocityQuery, Result<StockVelocityReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockRepository _stock;

    public StockVelocityQueryHandler(ITenantContext tenantContext, IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _stock = stock;
    }

    public async Task<Result<StockVelocityReportDto>> Handle(
        StockVelocityQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _stock.GetStockVelocityAsync(
            tenantId, query.From, query.To, cancellationToken);

        var dtos = items.Select(i => new StockVelocityDto(
            i.ProductId, i.ProductName, i.Sku, i.Sold, i.OnHand, i.VelocityPerDay)).ToList();

        return Result.Success(new StockVelocityReportDto(query.From, query.To, dtos));
    }
}

// ── Expense Trend ──────────────────────────────────────────────
public sealed record ExpenseTrendQuery(DateTime From, DateTime To)
    : IRequest<Result<ExpenseTrendReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExpenseTrendQueryHandler
    : IRequestHandler<ExpenseTrendQuery, Result<ExpenseTrendReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IExpenseRepository _expenses;

    public ExpenseTrendQueryHandler(ITenantContext tenantContext, IExpenseRepository expenses)
    {
        _tenantContext = tenantContext;
        _expenses = expenses;
    }

    public async Task<Result<ExpenseTrendReportDto>> Handle(
        ExpenseTrendQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _expenses.GetExpenseTrendAsync(
            tenantId, query.From, query.To, cancellationToken);

        var dtos = items.Select(i => new ExpenseTrendPointDto(i.Label, i.Amount)).ToList();

        return Result.Success(new ExpenseTrendReportDto(query.From, query.To, dtos));
    }
}

// ── Expense by Payment Method ──────────────────────────────────
public sealed record ExpenseByPaymentMethodQuery(DateTime From, DateTime To)
    : IRequest<Result<ExpenseByPaymentMethodReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExpenseByPaymentMethodQueryHandler
    : IRequestHandler<ExpenseByPaymentMethodQuery, Result<ExpenseByPaymentMethodReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IExpenseRepository _expenses;

    public ExpenseByPaymentMethodQueryHandler(ITenantContext tenantContext, IExpenseRepository expenses)
    {
        _tenantContext = tenantContext;
        _expenses = expenses;
    }

    public async Task<Result<ExpenseByPaymentMethodReportDto>> Handle(
        ExpenseByPaymentMethodQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _expenses.GetExpenseByPaymentMethodAsync(
            tenantId, query.From, query.To, cancellationToken);

        var dtos = items.Select(i => new ExpenseByPaymentMethodDto(i.PaymentMethod, i.Amount)).ToList();

        return Result.Success(new ExpenseByPaymentMethodReportDto(query.From, query.To, dtos));
    }
}

// ── Purchases by Supplier ──────────────────────────────────────
public sealed record PurchasesBySupplierQuery(DateTime From, DateTime To)
    : IRequest<Result<PurchasesBySupplierReportDto>>, IRequiresTenantAdvisoryLock;

public sealed class PurchasesBySupplierQueryHandler
    : IRequestHandler<PurchasesBySupplierQuery, Result<PurchasesBySupplierReportDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISender _sender;

    public PurchasesBySupplierQueryHandler(ITenantContext tenantContext, ISender sender)
    {
        _tenantContext = tenantContext;
        _sender = sender;
    }

    public async Task<Result<PurchasesBySupplierReportDto>> Handle(
        PurchasesBySupplierQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var result = await _sender.Send(
            new ListPurchaseOrdersQuery(1, 1000), cancellationToken);
        if (result.IsFailure)
            return Result.Failure<PurchasesBySupplierReportDto>(result.Error);

        var items = result.Value.Items
            .Where(po => po.CreatedAt >= query.From && po.CreatedAt <= query.To)
            .GroupBy(po => po.SupplierName)
            .Select(g => new PurchasesBySupplierDto(
                Guid.Empty, g.Key,
                g.Sum(po => po.TotalAmount), g.Count()))
            .OrderByDescending(x => x.TotalAmount)
            .ToList();

        return Result.Success(new PurchasesBySupplierReportDto(query.From, query.To, items));
    }
}

// ── Export Sales by Payment Method ─────────────────────────────
public sealed record ExportSalesByPaymentMethodCommand(DateTime From, DateTime To, Guid? BranchId)
    : IRequest<Result<ExportResultDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExportSalesByPaymentMethodCommandHandler
    : IRequestHandler<ExportSalesByPaymentMethodCommand, Result<ExportResultDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IReportRepository _reports;
    private readonly ICsvExportService _csv;

    public ExportSalesByPaymentMethodCommandHandler(
        ITenantContext tenantContext, IReportRepository reports, ICsvExportService csv)
    {
        _tenantContext = tenantContext;
        _reports = reports;
        _csv = csv;
    }

    public async Task<Result<ExportResultDto>> Handle(
        ExportSalesByPaymentMethodCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _reports.GetSalesByPaymentMethodAsync(
            tenantId, command.From, command.To, command.BranchId, cancellationToken);

        var headers = new[] { "Payment Method", "Amount", "Count" };
        var bytes = _csv.Export(items, headers, i => new object[]
        {
            i.PaymentMethod, i.Amount, i.Count
        });

        var fileName = $"sales-by-payment-{command.From:yyyyMMdd}-{command.To:yyyyMMdd}.csv";
        return Result.Success(new ExportResultDto(bytes, "text/csv", fileName));
    }
}

// ── Export Stock Summary ───────────────────────────────────────
public sealed record ExportStockSummaryCommand(DateTime From, DateTime To, Guid? WarehouseId)
    : IRequest<Result<ExportResultDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExportStockSummaryCommandHandler
    : IRequestHandler<ExportStockSummaryCommand, Result<ExportResultDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockRepository _stock;
    private readonly ICsvExportService _csv;

    public ExportStockSummaryCommandHandler(
        ITenantContext tenantContext, IStockRepository stock, ICsvExportService csv)
    {
        _tenantContext = tenantContext;
        _stock = stock;
        _csv = csv;
    }

    public async Task<Result<ExportResultDto>> Handle(
        ExportStockSummaryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var rows = await _stock.GetStockSummaryAsync(
            tenantId, command.From, command.To, command.WarehouseId, cancellationToken);

        var headers = new[] { "Product", "SKU", "Opening", "Purchased", "Sold", "Adjusted", "Closing" };
        var bytes = _csv.Export(rows, headers, r => new object[]
        {
            r.ProductName, r.Sku ?? "", r.Opening, r.Purchased, r.Sold, r.Adjusted, r.Closing
        });

        var fileName = $"stock-summary-{command.From:yyyyMMdd}-{command.To:yyyyMMdd}.csv";
        return Result.Success(new ExportResultDto(bytes, "text/csv", fileName));
    }
}

// ── Export Expenses ────────────────────────────────────────────
public sealed record ExportExpenseSummaryCommand(DateTime From, DateTime To)
    : IRequest<Result<ExportResultDto>>, IRequiresTenantAdvisoryLock;

public sealed class ExportExpenseSummaryCommandHandler
    : IRequestHandler<ExportExpenseSummaryCommand, Result<ExportResultDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IExpenseRepository _expenses;
    private readonly ICsvExportService _csv;

    public ExportExpenseSummaryCommandHandler(
        ITenantContext tenantContext, IExpenseRepository expenses, ICsvExportService csv)
    {
        _tenantContext = tenantContext;
        _expenses = expenses;
        _csv = csv;
    }

    public async Task<Result<ExportResultDto>> Handle(
        ExportExpenseSummaryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var summary = await _expenses.GetSummaryAsync(
            tenantId, command.From, command.To, cancellationToken);

        var headers = new[] { "Category", "Amount" };
        var bytes = _csv.Export(summary.ByCategory, headers, c => new object[]
        {
            c.CategoryName ?? "Other", c.Total
        });

        var fileName = $"expenses-{command.From:yyyyMMdd}-{command.To:yyyyMMdd}.csv";
        return Result.Success(new ExportResultDto(bytes, "text/csv", fileName));
    }
}

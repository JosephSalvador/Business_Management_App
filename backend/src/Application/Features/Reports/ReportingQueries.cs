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
            r.TotalQuantity, r.TotalRevenue, r.TotalTax, r.Rank)).ToList();

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
            r.TotalQuantity, r.TotalRevenue, r.TotalTax, r.Rank)).ToList();

        return Result.Success(new DashboardTaxKpisDto(
            taxLineDtos.Sum(l => l.TotalBaseAmount),
            taxLineDtos.Sum(l => l.TotalTaxAmount),
            taxLineDtos,
            topProductDtos));
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

        var headers = new[] { "Rank", "Product", "SKU", "Quantity", "Revenue", "Tax" };
        var bytes = _csv.Export(rows, headers, r => new object[]
        {
            r.Rank, r.ProductName, r.Sku ?? "", r.TotalQuantity, r.TotalRevenue, r.TotalTax
        });

        var fileName = $"top-products-{command.From:yyyyMMdd}-{command.To:yyyyMMdd}.csv";
        return Result.Success(new ExportResultDto(bytes, "text/csv", fileName));
    }
}

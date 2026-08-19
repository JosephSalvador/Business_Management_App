using BusinessOS.Application.Features.Reports.Queries;
using BusinessOS.Application.Features.Reports.Validators;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Reporting;

internal static class ReportingTestHelper
{
    private static readonly Guid DefaultTenantId = new("11111111-1111-1111-1111-111111111111");
    public static ITenantContext StubTenant() => new StubTenantContext(DefaultTenantId);
}

internal sealed class StubTenantContext(Guid tenantId) : ITenantContext
{
    public Guid TenantId => tenantId;
    public Guid? UserId => Guid.NewGuid();
    public string? IpAddress => "127.0.0.1";
}

internal sealed class StubReportRepository : IReportRepository
{
    private readonly List<TaxSummaryLine> _taxSummary = [];
    private readonly List<TopProductRow> _topProducts = [];
    private readonly List<SalesByBranchSummary> _branchSummary = [];

    public void SeedTaxSummary(params TaxSummaryLine[] lines) => _taxSummary.AddRange(lines);
    public void SeedTopProducts(params TopProductRow[] rows) => _topProducts.AddRange(rows);
    public void SeedBranchSummary(params SalesByBranchSummary[] branches) => _branchSummary.AddRange(branches);

    public int TotalSales { get; set; }
    public decimal TotalRevenue { get; set; }
    public decimal TotalTax { get; set; }
    public decimal TotalDiscount { get; set; }

    public Task<IReadOnlyList<TaxSummaryLine>> GetTaxSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<TaxSummaryLine>>(_taxSummary);

    public Task<(int TotalSales, decimal TotalRevenue, decimal TotalTax, decimal TotalDiscount, decimal AverageSale,
        IReadOnlyList<SalesByBranchSummary> ByBranch)> GetSalesSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var avg = TotalSales > 0 ? Math.Round(TotalRevenue / TotalSales, 2) : 0m;
        return Task.FromResult((TotalSales, TotalRevenue, TotalTax, TotalDiscount, avg, (IReadOnlyList<SalesByBranchSummary>)_branchSummary));
    }

    public Task<IReadOnlyList<TopProductRow>> GetTopProductsAsync(
        Guid tenantId, DateTime from, DateTime to, int limit, Guid? branchId, CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<TopProductRow>>(_topProducts.Take(limit).ToList());
}

internal sealed class StubCsvExportService : ICsvExportService
{
    public byte[] Export<T>(IReadOnlyList<T> rows, string[] headers, Func<T, object[]> mapRow)
    {
        var lines = new System.Text.StringBuilder();
        lines.AppendLine(string.Join(",", headers));
        foreach (var row in rows)
        {
            var values = mapRow(row).Select(v => v?.ToString() ?? "");
            lines.AppendLine(string.Join(",", values));
        }
        return System.Text.Encoding.UTF8.GetBytes(lines.ToString());
    }
}

// ── Tax Summary Tests ──────────────────────────────────────────
public sealed class TaxSummaryQueryTests
{
    [Fact]
    public async Task Handle_ReturnsEmptyTaxSummary()
    {
        var tenant = ReportingTestHelper.StubTenant();
        var repo = new StubReportRepository();
        var handler = new TaxSummaryQueryHandler(tenant, repo);

        var from = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2025, 1, 31, 23, 59, 59, DateTimeKind.Utc);
        var result = await handler.Handle(new TaxSummaryQuery(from, to, null), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Empty(result.Value.Lines);
        Assert.Equal(0m, result.Value.TotalBaseAmount);
    }

    [Fact]
    public async Task Handle_ReturnsTaxLinesAggregated()
    {
        var tenant = ReportingTestHelper.StubTenant();
        var repo = new StubReportRepository();
        repo.SeedTaxSummary(
            new TaxSummaryLine("STD", 0.16m, 1000m, 160m, 1160m, 10),
            new TaxSummaryLine("EXM", 0m, 500m, 0m, 500m, 5));
        var handler = new TaxSummaryQueryHandler(tenant, repo);

        var from = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2025, 1, 31, 23, 59, 59, DateTimeKind.Utc);
        var result = await handler.Handle(new TaxSummaryQuery(from, to, null), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.Lines.Count);
        Assert.Equal(1500m, result.Value.TotalBaseAmount);
        Assert.Equal(160m, result.Value.TotalTaxAmount);
        Assert.Equal(1660m, result.Value.TotalLineTotal);
    }

    [Fact]
    public async Task TaxSummaryQueryValidator_FailsWhenFromAfterTo()
    {
        var validator = new TaxSummaryQueryValidator();
        var query = new TaxSummaryQuery(
            new DateTime(2025, 2, 1, 0, 0, 0, DateTimeKind.Utc),
            new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            null);

        var result = await validator.ValidateAsync(query);
        Assert.False(result.IsValid);
    }
}

// ── Sales Summary Tests ────────────────────────────────────────
public sealed class SalesSummaryQueryTests
{
    [Fact]
    public async Task Handle_ReturnsCorrectAverages()
    {
        var tenant = ReportingTestHelper.StubTenant();
        var repo = new StubReportRepository
        {
            TotalSales = 4,
            TotalRevenue = 2000m,
            TotalTax = 320m,
            TotalDiscount = 100m
        };
        var handler = new SalesSummaryQueryHandler(tenant, repo);

        var from = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2025, 1, 31, 23, 59, 59, DateTimeKind.Utc);
        var result = await handler.Handle(new SalesSummaryQuery(from, to, null), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(4, result.Value.TotalSales);
        Assert.Equal(2000m, result.Value.TotalRevenue);
        Assert.Equal(320m, result.Value.TotalTax);
        Assert.Equal(100m, result.Value.TotalDiscount);
        Assert.Equal(500m, result.Value.AverageSale);
    }

    [Fact]
    public async Task Handle_IncludesBranchBreakdown()
    {
        var tenant = ReportingTestHelper.StubTenant();
        var repo = new StubReportRepository
        {
            TotalSales = 10,
            TotalRevenue = 5000m,
            TotalTax = 800m,
            TotalDiscount = 200m
        };
        repo.SeedBranchSummary(
            new SalesByBranchSummary(Guid.NewGuid(), "Branch A", 7, 3500m),
            new SalesByBranchSummary(Guid.NewGuid(), "Branch B", 3, 1500m));
        var handler = new SalesSummaryQueryHandler(tenant, repo);

        var from = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2025, 1, 31, 23, 59, 59, DateTimeKind.Utc);
        var result = await handler.Handle(new SalesSummaryQuery(from, to, null), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.ByBranch.Count);
        Assert.Equal("Branch A", result.Value.ByBranch[0].BranchName);
    }

    [Fact]
    public async Task SalesSummaryQueryValidator_FailsWhenFromAfterTo()
    {
        var validator = new SalesSummaryQueryValidator();
        var query = new SalesSummaryQuery(
            new DateTime(2025, 2, 1, 0, 0, 0, DateTimeKind.Utc),
            new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            null);

        var result = await validator.ValidateAsync(query);
        Assert.False(result.IsValid);
    }
}

// ── Top Products Tests ─────────────────────────────────────────
public sealed class TopProductsQueryTests
{
    [Fact]
    public async Task Handle_ReturnsRankedProducts()
    {
        var tenant = ReportingTestHelper.StubTenant();
        var repo = new StubReportRepository();
        repo.SeedTopProducts(
            new TopProductRow(Guid.NewGuid(), "Widget A", "WA-001", 100m, 5000m, 800m, 1),
            new TopProductRow(Guid.NewGuid(), "Widget B", "WB-001", 80m, 4000m, 640m, 2),
            new TopProductRow(Guid.NewGuid(), "Widget C", "WC-001", 50m, 2500m, 400m, 3));
        var handler = new TopProductsQueryHandler(tenant, repo);

        var from = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2025, 1, 31, 23, 59, 59, DateTimeKind.Utc);
        var result = await handler.Handle(new TopProductsQuery(from, to, 10, null), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(3, result.Value.Products.Count);
        Assert.Equal(1, result.Value.Products[0].Rank);
        Assert.Equal(2, result.Value.Products[1].Rank);
    }

    [Fact]
    public async Task Handle_LimitsResults()
    {
        var tenant = ReportingTestHelper.StubTenant();
        var repo = new StubReportRepository();
        repo.SeedTopProducts(
            new TopProductRow(Guid.NewGuid(), "A", "A-1", 10m, 100m, 16m, 0),
            new TopProductRow(Guid.NewGuid(), "B", "B-1", 20m, 200m, 32m, 0),
            new TopProductRow(Guid.NewGuid(), "C", "C-1", 30m, 300m, 48m, 0));
        var handler = new TopProductsQueryHandler(tenant, repo);

        var from = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2025, 1, 31, 23, 59, 59, DateTimeKind.Utc);
        var result = await handler.Handle(new TopProductsQuery(from, to, 2, null), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.Products.Count);
    }

    [Fact]
    public async Task TopProductsQueryValidator_RejectsLimitAbove100()
    {
        var validator = new TopProductsQueryValidator();
        var query = new TopProductsQuery(
            new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            new DateTime(2025, 1, 31, 23, 59, 59, DateTimeKind.Utc),
            101, null);

        var result = await validator.ValidateAsync(query);
        Assert.False(result.IsValid);
    }
}

// ── Dashboard Tax KPIs Tests ───────────────────────────────────
public sealed class DashboardTaxKpisQueryTests
{
    [Fact]
    public async Task Handle_ReturnsCurrentMonthKpis()
    {
        var tenant = ReportingTestHelper.StubTenant();
        var repo = new StubReportRepository();
        repo.SeedTaxSummary(
            new TaxSummaryLine("STD", 0.16m, 1000m, 160m, 1160m, 10));
        repo.SeedTopProducts(
            new TopProductRow(Guid.NewGuid(), "Widget", "W-1", 100m, 1000m, 160m, 1));
        var handler = new DashboardTaxKpisQueryHandler(tenant, repo);

        var result = await handler.Handle(new DashboardTaxKpisQuery(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1000m, result.Value.TotalRevenue);
        Assert.Equal(160m, result.Value.TotalTaxCollected);
        Assert.Single(result.Value.TaxByCode);
        Assert.Single(result.Value.TopProducts);
    }
}

// ── CSV Export Tests ───────────────────────────────────────────
public sealed class CsvExportServiceTests
{
    [Fact]
    public void Export_ProducesValidCsv()
    {
        var csv = new StubCsvExportService();
        var data = new List<(string Name, int Count)>
        {
            ("Alice", 5),
            ("Bob", 10),
        };

        var result = csv.Export(data, new[] { "Name", "Count" }, d => new object[] { d.Name, d.Count });
        var text = System.Text.Encoding.UTF8.GetString(result);

        Assert.Contains("Name,Count", text);
        Assert.Contains("Alice,5", text);
        Assert.Contains("Bob,10", text);
    }

    [Fact]
    public void Export_EscapesCsvValues()
    {
        var csv = new BusinessOS.Application.Ports.CsvExportService();
        var data = new List<string> { "with,comma", "with\"quote" };

        var result = csv.Export(data, new[] { "Value" }, d => new object[] { d });
        var text = System.Text.Encoding.UTF8.GetString(result);

        Assert.Contains("\"with,comma\"", text);
        Assert.Contains("\"with\"\"quote\"", text);
    }
}

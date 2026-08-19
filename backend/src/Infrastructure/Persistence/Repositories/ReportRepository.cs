using BusinessOS.Application.Ports;
using BusinessOS.Domain.Sales;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Infrastructure.Persistence.Repositories;

internal sealed class ReportRepository : IReportRepository
{
    private readonly BusinessDbContext _context;

    public ReportRepository(BusinessDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<TaxSummaryLine>> GetTaxSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var salesQuery = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= from
                && s.SaleDate <= to
                && s.Status != SaleStatus.Voided);

        if (branchId.HasValue)
            salesQuery = salesQuery.Where(s => s.BranchId == branchId.Value);

        var validSaleIds = await salesQuery.Select(s => s.Id).ToListAsync(cancellationToken);

        var lines = await _context.Set<SaleLine>()
            .AsNoTracking()
            .Where(sl => validSaleIds.Contains(sl.SaleId))
            .ToListAsync(cancellationToken);

        return lines
            .GroupBy(sl => new { sl.TaxCode, sl.AppliedRate })
            .Select(g => new TaxSummaryLine(
                g.Key.TaxCode,
                g.Key.AppliedRate,
                g.Sum(x => x.BaseAmount),
                g.Sum(x => x.TaxAmount),
                g.Sum(x => x.LineTotal),
                g.Select(x => x.SaleId).Distinct().Count()))
            .OrderByDescending(t => t.TotalTaxAmount)
            .ToList();
    }

    public async Task<(int TotalSales, decimal TotalRevenue, decimal TotalTax, decimal TotalDiscount, decimal AverageSale,
        IReadOnlyList<SalesByBranchSummary> ByBranch)> GetSalesSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var query = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= from
                && s.SaleDate <= to
                && s.Status != SaleStatus.Voided)
            .AsQueryable();

        if (branchId.HasValue)
            query = query.Where(s => s.BranchId == branchId.Value);

        var sales = await query.ToListAsync(cancellationToken);

        var totalSales = sales.Count;
        var totalRevenue = sales.Sum(s => s.TotalAmount);
        var totalTax = sales.Sum(s => s.TaxAmount);
        var totalDiscount = sales.Sum(s => s.DiscountAmount);
        var averageSale = totalSales > 0 ? Math.Round(totalRevenue / totalSales, 2) : 0m;

        // Resolve branch names from the Branches table
        var branchIds = sales.Select(s => s.BranchId).Distinct().ToList();
        var branches = await _context.Branches
            .AsNoTracking()
            .Where(b => branchIds.Contains(b.Id))
            .ToListAsync(cancellationToken);
        var branchLookup = branches.ToDictionary(b => b.Id, b => b.Name);

        var byBranch = sales
            .GroupBy(s => s.BranchId)
            .Select(g => new SalesByBranchSummary(
                g.Key,
                branchLookup.GetValueOrDefault(g.Key, "Unknown"),
                g.Count(),
                g.Sum(s => s.TotalAmount)))
            .OrderByDescending(b => b.TotalRevenue)
            .ToList();

        return (totalSales, totalRevenue, totalTax, totalDiscount, averageSale, byBranch);
    }

    public async Task<IReadOnlyList<TopProductRow>> GetTopProductsAsync(
        Guid tenantId, DateTime from, DateTime to, int limit, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var salesQuery = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= from
                && s.SaleDate <= to
                && s.Status != SaleStatus.Voided);

        if (branchId.HasValue)
            salesQuery = salesQuery.Where(s => s.BranchId == branchId.Value);

        var validSaleIds = await salesQuery.Select(s => s.Id).ToListAsync(cancellationToken);

        var lines = await _context.Set<SaleLine>()
            .AsNoTracking()
            .Where(sl => validSaleIds.Contains(sl.SaleId))
            .ToListAsync(cancellationToken);

        var rows = lines
            .GroupBy(sl => new { sl.ProductId, sl.ProductName, sl.Sku })
            .Select(g => new TopProductRow(
                g.Key.ProductId,
                g.Key.ProductName,
                g.Key.Sku,
                g.Sum(x => x.Quantity),
                g.Sum(x => x.LineTotal),
                g.Sum(x => x.TaxAmount),
                0))
            .OrderByDescending(t => t.TotalRevenue)
            .Take(limit)
            .ToList();

        // Assign rank after ordering
        var ranked = rows.Select((r, i) => new TopProductRow(
            r.ProductId, r.ProductName, r.Sku,
            r.TotalQuantity, r.TotalRevenue, r.TotalTax, i + 1)).ToList();

        return ranked;
    }
}

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

    private static (DateTime From, DateTime To) NormalizeRangeUtc(DateTime from, DateTime to)
        => (DateTime.SpecifyKind(from, DateTimeKind.Utc), DateTime.SpecifyKind(to, DateTimeKind.Utc));

    public async Task<IReadOnlyList<TaxSummaryLine>> GetTaxSummaryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        (var fromUtc, var toUtc) = NormalizeRangeUtc(from, to);
        var salesQuery = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= fromUtc
                && s.SaleDate <= toUtc
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
        (var fromUtc, var toUtc) = NormalizeRangeUtc(from, to);
        var query = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= fromUtc
                && s.SaleDate <= toUtc
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
        (var fromUtc, var toUtc) = NormalizeRangeUtc(from, to);
        var salesQuery = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= fromUtc
                && s.SaleDate <= toUtc
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

    public async Task<IReadOnlyList<SalesTrendPoint>> GetSalesTrendAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        (var fromUtc, var toUtc) = NormalizeRangeUtc(from, to);
        var query = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= fromUtc
                && s.SaleDate <= toUtc
                && s.Status != SaleStatus.Voided)
            .AsQueryable();

        if (branchId.HasValue)
            query = query.Where(s => s.BranchId == branchId.Value);

        var sales = await query.ToListAsync(cancellationToken);

        var isSingleDay = (toUtc.Date - fromUtc.Date).TotalDays <= 1;

        var grouped = isSingleDay
            ? sales
                .GroupBy(s => new DateTime(s.SaleDate.Year, s.SaleDate.Month, s.SaleDate.Day, s.SaleDate.Hour, 0, 0, DateTimeKind.Utc))
                .Select(g => new SalesTrendPoint(
                    g.Key.ToString("HH:mm"),
                    g.Count(),
                    g.Sum(s => s.TotalAmount),
                    g.Sum(s => s.TaxAmount)))
                .OrderBy(p => p.Label)
                .ToList()
            : sales
                .GroupBy(s => s.SaleDate.Date)
                .Select(g => new SalesTrendPoint(
                    g.Key.ToString("yyyy-MM-dd"),
                    g.Count(),
                    g.Sum(s => s.TotalAmount),
                    g.Sum(s => s.TaxAmount)))
                .OrderBy(p => p.Label)
                .ToList();

        var result = new List<SalesTrendPoint>();

        if (isSingleDay)
        {
            var lookup = grouped.ToDictionary(p => p.Label);
            for (var h = fromUtc.Hour; h <= toUtc.Hour; h++)
            {
                var key = new DateTime(2000, 1, 1, h, 0, 0, DateTimeKind.Utc).ToString("HH:mm");
                result.Add(lookup.TryGetValue(key, out var existing)
                    ? existing
                    : new SalesTrendPoint(key, 0, 0m, 0m));
            }
        }
        else
        {
            var lookup = grouped.ToDictionary(p => p.Label);
            var current = fromUtc.Date;
            while (current <= toUtc.Date)
            {
                var key = current.ToString("yyyy-MM-dd");
                result.Add(lookup.TryGetValue(key, out var existing)
                    ? existing
                    : new SalesTrendPoint(key, 0, 0m, 0m));
                current = current.AddDays(1);
            }
        }

        return result;
    }

    public async Task<IReadOnlyList<SalesByPaymentMethodRow>> GetSalesByPaymentMethodAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var query = _context.Sales
            .Where(s => s.TenantId == tenantId && s.SaleDate >= from && s.SaleDate <= to && s.Status != SaleStatus.Voided);
        if (branchId.HasValue)
            query = query.Where(s => s.BranchId == branchId.Value);

        var sales = await query.ToListAsync(cancellationToken);
        var saleIds = sales.Select(s => s.Id).ToList();

        var payments = await _context.Set<SalePayment>()
            .Where(p => saleIds.Contains(p.SaleId))
            .ToListAsync(cancellationToken);

        return sales
            .SelectMany(s => payments.Where(p => p.SaleId == s.Id).DefaultIfEmpty(),
                (s, p) => new { s, p })
            .GroupBy(x => x.p?.Method.ToString() ?? "Unknown")
            .Select(g => new SalesByPaymentMethodRow(
                g.Key, g.Sum(x => x.s.TotalAmount), g.Count(x => x.p != null)))
            .OrderByDescending(x => x.Amount)
            .ToList();
    }

    public async Task<IReadOnlyList<SalesByCategoryRow>> GetSalesByCategoryAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var query = _context.Sales
            .Where(s => s.TenantId == tenantId && s.SaleDate >= from && s.SaleDate <= to && s.Status != SaleStatus.Voided);
        if (branchId.HasValue)
            query = query.Where(s => s.BranchId == branchId.Value);

        return await query
            .SelectMany(s => s.Lines)
            .GroupBy(l => l.ProductName)
            .Select(g => new SalesByCategoryRow(
                g.Key, g.Sum(l => l.LineTotal), g.Sum(l => l.Quantity)))
            .OrderByDescending(x => x.Amount)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<SalesByStaffRow>> GetSalesByStaffAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var query = _context.Sales
            .Where(s => s.TenantId == tenantId && s.SaleDate >= from && s.SaleDate <= to && s.Status != SaleStatus.Voided);
        if (branchId.HasValue)
            query = query.Where(s => s.BranchId == branchId.Value);

        var sales = await query.ToListAsync(cancellationToken);
        var cashierIds = sales.Select(s => s.CashierId).Distinct().ToList();

        var users = await _context.Users
            .Where(u => cashierIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.FullName, cancellationToken);

        return sales
            .GroupBy(s => new { s.CashierId, Name = users.GetValueOrDefault(s.CashierId, "System") })
            .Select(g => new SalesByStaffRow(
                g.Key.CashierId, g.Key.Name, g.Count(), g.Sum(s => s.TotalAmount)))
            .OrderByDescending(x => x.Revenue)
            .ToList();
    }

    public async Task<IReadOnlyList<SalesByCustomerRow>> GetSalesByCustomerAsync(
        Guid tenantId, DateTime from, DateTime to, Guid? branchId, CancellationToken cancellationToken = default)
    {
        var query = _context.Sales
            .Where(s => s.TenantId == tenantId && s.SaleDate >= from && s.SaleDate <= to && s.Status != SaleStatus.Voided);
        if (branchId.HasValue)
            query = query.Where(s => s.BranchId == branchId.Value);

        return await query
            .GroupBy(s => new { s.CustomerId, CustomerName = s.CustomerName ?? "Walk-in" })
            .Select(g => new SalesByCustomerRow(
                g.Key.CustomerId, g.Key.CustomerName, g.Count(), g.Sum(s => s.TotalAmount)))
            .OrderByDescending(x => x.Revenue)
            .ToListAsync(cancellationToken);
    }

    public async Task<decimal> GetCogsAsync(
        Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default)
    {
        (var fromUtc, var toUtc) = NormalizeRangeUtc(from, to);

        var salesQuery = _context.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                && s.SaleDate >= fromUtc
                && s.SaleDate <= toUtc
                && s.Status != SaleStatus.Voided);
        var validSaleIds = await salesQuery.Select(s => s.Id).ToListAsync(cancellationToken);

        if (validSaleIds.Count == 0) return 0m;

        var cogs = await _context.Set<SaleLine>()
            .AsNoTracking()
            .Where(sl => validSaleIds.Contains(sl.SaleId) && sl.UnitCost.HasValue)
            .SumAsync(sl => sl.UnitCost!.Value * sl.Quantity, cancellationToken);

        return Math.Round(cogs, 2);
    }
}

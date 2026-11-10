using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Application.Features.Tenants;

public sealed record FleetSummaryDto(
    int TotalTenants,
    int ActiveSubscriptions,
    int TrialTenants,
    int ExpiredOrDebt,
    decimal TodayPlatformGmv,
    int TodayTotalSalesCount,
    int AtRiskTenantsCount,
    int StalledOnboardingCount);

public sealed record TenantFleetItemDto(
    Guid Id,
    string Name,
    string Currency,
    string CountryCode,
    string? BusinessType,
    string? ContactEmail,
    string? ContactPhone,
    DateTime CreatedAt,
    bool IsActive,
    string PlanCode,
    string SubscriptionStatus,
    int TrialDaysLeft,
    DateTime? PaidUntilUtc,
    int MilestoneStep,
    int TotalBranches,
    int TotalUsers,
    int TotalProducts,
    int TotalSales,
    decimal TodaySalesAmount,
    DateTime? LastSaleAtUtc,
    DateTime? LastActiveAtUtc,
    string HealthStatus);

public sealed record PagedFleetResult(
    IReadOnlyList<TenantFleetItemDto> Items,
    int TotalCount,
    int Page,
    int PageSize);

public sealed record TenantDetailAdminDto(
    Guid Id,
    string Name,
    string Currency,
    string CountryCode,
    string? BusinessType,
    string? ContactEmail,
    string? ContactPhone,
    string? Address,
    string? TaxId,
    DateTime CreatedAt,
    bool IsActive,
    string PlanCode,
    string SubscriptionStatus,
    int TrialDaysLeft,
    DateTime? PaidUntilUtc,
    int MilestoneStep,
    IReadOnlyList<TenantBranchDto> Branches,
    IReadOnlyList<TenantUserDto> Users,
    IReadOnlyList<TenantDailySalesDto> RecentSalesTrend,
    IReadOnlyList<string> EnabledFeatures,
    IReadOnlyList<TenantAuditActivityDto> RecentActivity);

public sealed record TenantBranchDto(Guid Id, string Name, string Code, bool IsActive);
public sealed record TenantUserDto(Guid Id, string Email, string FullName, string? Phone, bool IsActive, string Role);
public sealed record TenantDailySalesDto(string Date, decimal TotalAmount, int SalesCount);
public sealed record TenantAuditActivityDto(string Action, string EntityType, string? PerformedBy, DateTime Timestamp);

// ── 1. Get Fleet Summary ─────────────────────────────────────────
public sealed record GetFleetSummaryQuery : IRequest<Result<FleetSummaryDto>>;

public sealed class GetFleetSummaryQueryHandler : IRequestHandler<GetFleetSummaryQuery, Result<FleetSummaryDto>>
{
    private readonly BusinessDbContext _db;

    public GetFleetSummaryQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<FleetSummaryDto>> Handle(
        GetFleetSummaryQuery request, CancellationToken cancellationToken)
    {
        var totalTenants = await _db.Tenants.CountAsync(cancellationToken);

        var subs = await _db.Set<Subscription>()
            .Select(s => new { s.Status, s.TrialEndsAtUtc, s.PaidUntilUtc })
            .ToListAsync(cancellationToken);

        var now = DateTime.UtcNow;
        var activeSubs = subs.Count(s => s.Status == SubscriptionStatus.Active && (s.PaidUntilUtc == null || s.PaidUntilUtc > now));
        var trialSubs = subs.Count(s => s.Status == SubscriptionStatus.Trial && s.TrialEndsAtUtc > now);
        var expiredOrDebt = subs.Count(s => (s.Status == SubscriptionStatus.Expired || s.Status == SubscriptionStatus.GracePeriod) || (s.TrialEndsAtUtc <= now && s.Status == SubscriptionStatus.Trial));

        var todayUtcStart = DateTime.UtcNow.Date;
        var todaySalesData = await _db.Sales
            .Where(s => s.CreatedAt >= todayUtcStart && s.Status == Domain.Sales.SaleStatus.Completed)
            .GroupBy(s => 1)
            .Select(g => new
            {
                TotalGmv = g.Sum(x => x.TotalAmount),
                Count = g.Count()
            })
            .FirstOrDefaultAsync(cancellationToken);

        var gmv = todaySalesData?.TotalGmv ?? 0m;
        var salesCount = todaySalesData?.Count ?? 0;

        // Tenants stalled at onboarding: created > 2 days ago, but 0 products or 0 sales
        var cutoff = DateTime.UtcNow.AddDays(-2);
        var activeTenantIds = await _db.Tenants
            .Where(t => t.CreatedAt <= cutoff && t.IsActive)
            .Select(t => t.Id)
            .ToListAsync(cancellationToken);

        var tenantsWithSales = await _db.Sales
            .Where(s => activeTenantIds.Contains(s.TenantId))
            .Select(s => s.TenantId)
            .Distinct()
            .ToListAsync(cancellationToken);

        var tenantsWithProducts = await _db.Products
            .Where(p => activeTenantIds.Contains(p.TenantId))
            .Select(p => p.TenantId)
            .Distinct()
            .ToListAsync(cancellationToken);

        var stalled = activeTenantIds.Count(id => !tenantsWithSales.Contains(id) || !tenantsWithProducts.Contains(id));
        var atRisk = expiredOrDebt + (stalled / 2);

        return Result.Success(new FleetSummaryDto(
            totalTenants,
            activeSubs,
            trialSubs,
            expiredOrDebt,
            gmv,
            salesCount,
            atRisk,
            stalled));
    }
}

// ── 2. List Tenants Fleet ─────────────────────────────────────────
public sealed record ListTenantsAdminQuery(
    string? Search = null,
    string? Status = null,
    string? Health = null,
    int Page = 1,
    int PageSize = 25)
    : IRequest<Result<PagedFleetResult>>;

public sealed class ListTenantsAdminQueryHandler : IRequestHandler<ListTenantsAdminQuery, Result<PagedFleetResult>>
{
    private readonly BusinessDbContext _db;

    public ListTenantsAdminQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<PagedFleetResult>> Handle(
        ListTenantsAdminQuery request, CancellationToken cancellationToken)
    {
        var page = request.Page > 0 ? request.Page : 1;
        var pageSize = request.PageSize is > 0 and <= 100 ? request.PageSize : 25;

        var query = _db.Tenants.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var s = request.Search.Trim().ToLowerInvariant();
            query = query.Where(t =>
                t.Name.ToLower().Contains(s) ||
                (t.ContactEmail != null && t.ContactEmail.ToLower().Contains(s)) ||
                (t.ContactPhone != null && t.ContactPhone.Contains(s)));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var tenants = await query
            .OrderByDescending(t => t.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var tenantIds = tenants.Select(t => t.Id).ToList();

        // Batch aggregate operational stats for these tenants
        var branchesCounts = await _db.Branches
            .Where(b => tenantIds.Contains(b.TenantId))
            .GroupBy(b => b.TenantId)
            .Select(g => new { TenantId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.TenantId, x => x.Count, cancellationToken);

        var usersCounts = await _db.Users
            .Where(u => tenantIds.Contains(u.TenantId))
            .GroupBy(u => u.TenantId)
            .Select(g => new { TenantId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.TenantId, x => x.Count, cancellationToken);

        var productsCounts = await _db.Products
            .Where(p => tenantIds.Contains(p.TenantId))
            .GroupBy(p => p.TenantId)
            .Select(g => new { TenantId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.TenantId, x => x.Count, cancellationToken);

        var stockCounts = await _db.StockBalances
            .Where(s => tenantIds.Contains(s.TenantId) && s.Quantity > 0)
            .GroupBy(s => s.TenantId)
            .Select(g => new { TenantId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.TenantId, x => x.Count, cancellationToken);

        var salesStats = await _db.Sales
            .Where(s => tenantIds.Contains(s.TenantId) && s.Status == Domain.Sales.SaleStatus.Completed)
            .GroupBy(s => s.TenantId)
            .Select(g => new
            {
                TenantId = g.Key,
                TotalSales = g.Count(),
                LastSaleAt = g.Max(x => (DateTime?)x.CreatedAt),
                TodaySales = g.Where(x => x.CreatedAt >= DateTime.UtcNow.Date).Sum(x => (decimal?)x.TotalAmount) ?? 0m
            })
            .ToDictionaryAsync(x => x.TenantId, cancellationToken);

        var subs = await _db.Set<Subscription>()
            .Where(s => tenantIds.Contains(s.TenantId))
            .ToDictionaryAsync(s => s.TenantId, cancellationToken);

        var now = DateTime.UtcNow;
        var items = new List<TenantFleetItemDto>();

        foreach (var t in tenants)
        {
            subs.TryGetValue(t.Id, out var sub);
            var planCode = sub?.PlanCode ?? "Starter";
            var statusStr = sub?.Status.ToString() ?? (t.IsActive ? "Active" : "Suspended");

            var trialDaysLeft = 0;
            if (sub?.Status == SubscriptionStatus.Trial && sub.TrialEndsAtUtc > now)
            {
                trialDaysLeft = (int)Math.Ceiling((sub.TrialEndsAtUtc - now).TotalDays);
            }

            branchesCounts.TryGetValue(t.Id, out var bCount);
            usersCounts.TryGetValue(t.Id, out var uCount);
            productsCounts.TryGetValue(t.Id, out var pCount);
            stockCounts.TryGetValue(t.Id, out var sCount);
            salesStats.TryGetValue(t.Id, out var saleData);

            var totalSales = saleData?.TotalSales ?? 0;
            var todaySalesAmount = saleData?.TodaySales ?? 0m;
            var lastSaleAt = saleData?.LastSaleAt;

            // Compute Milestone Step (1 to 5)
            var milestone = 1; // 1: Profile created
            if (bCount > 0) milestone = 2; // 2: Branches set
            if (pCount > 0) milestone = 3; // 3: Products added
            if (sCount > 0) milestone = 4; // 4: Inventory initialized
            if (totalSales > 0) milestone = 5; // 5: Live sales occurring

            // Compute Health Status
            string health;
            if (!t.IsActive)
            {
                health = "Suspended";
            }
            else if (sub?.Status == SubscriptionStatus.Expired || (sub?.Status == SubscriptionStatus.Trial && sub.TrialEndsAtUtc <= now))
            {
                health = "Expired";
            }
            else if (milestone < 3 && t.CreatedAt < now.AddDays(-2))
            {
                health = "StalledOnboarding";
            }
            else if (totalSales > 0 && lastSaleAt.HasValue && lastSaleAt.Value < now.AddDays(-4))
            {
                health = "AtRiskOfChurn";
            }
            else
            {
                health = "Healthy";
            }

            // Filter by requested status if specified
            if (!string.IsNullOrWhiteSpace(request.Status) && !string.Equals(statusStr, request.Status, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            // Filter by requested health if specified
            if (!string.IsNullOrWhiteSpace(request.Health) && !string.Equals(health, request.Health, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            items.Add(new TenantFleetItemDto(
                t.Id,
                t.Name,
                t.Currency,
                t.CountryCode,
                t.BusinessType,
                t.ContactEmail,
                t.ContactPhone,
                t.CreatedAt,
                t.IsActive,
                planCode,
                statusStr,
                trialDaysLeft,
                sub?.PaidUntilUtc,
                milestone,
                bCount,
                uCount,
                pCount,
                totalSales,
                todaySalesAmount,
                lastSaleAt,
                lastSaleAt ?? t.CreatedAt,
                health));
        }

        return Result.Success(new PagedFleetResult(items, totalCount, page, pageSize));
    }
}

// ── 3. Get Tenant Deep-Dive Detail ────────────────────────────────
public sealed record GetTenantDetailAdminQuery(Guid TenantId) : IRequest<Result<TenantDetailAdminDto>>;

public sealed class GetTenantDetailAdminQueryHandler : IRequestHandler<GetTenantDetailAdminQuery, Result<TenantDetailAdminDto>>
{
    private readonly BusinessDbContext _db;

    public GetTenantDetailAdminQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<TenantDetailAdminDto>> Handle(
        GetTenantDetailAdminQuery request, CancellationToken cancellationToken)
    {
        var t = await _db.Tenants.FirstOrDefaultAsync(x => x.Id == request.TenantId, cancellationToken);
        if (t is null)
        {
            return Error.NotFound("Tenant not found.");
        }

        var sub = await _db.Set<Subscription>()
            .FirstOrDefaultAsync(s => s.TenantId == t.Id, cancellationToken);

        var now = DateTime.UtcNow;
        var trialDays = 0;
        if (sub?.Status == SubscriptionStatus.Trial && sub.TrialEndsAtUtc > now)
        {
            trialDays = (int)Math.Ceiling((sub.TrialEndsAtUtc - now).TotalDays);
        }

        var branches = await _db.Branches
            .Where(b => b.TenantId == t.Id)
            .Select(b => new TenantBranchDto(b.Id, b.Name, b.Code, b.IsActive))
            .ToListAsync(cancellationToken);

        var users = await _db.Users
            .Include(u => u.Roles)
            .Where(u => u.TenantId == t.Id)
            .Select(u => new TenantUserDto(
                u.Id,
                u.Email,
                u.FullName,
                u.Phone,
                u.IsActive,
                u.Roles.Select(r => r.Name).FirstOrDefault() ?? "Staff"))
            .ToListAsync(cancellationToken);

        // 7-day sales trend
        var sevenDaysAgo = DateTime.UtcNow.Date.AddDays(-6);
        var salesRaw = await _db.Sales
            .Where(s => s.TenantId == t.Id && s.CreatedAt >= sevenDaysAgo && s.Status == Domain.Sales.SaleStatus.Completed)
            .GroupBy(s => s.CreatedAt.Date)
            .Select(g => new { Date = g.Key, Total = g.Sum(x => x.TotalAmount), Count = g.Count() })
            .ToListAsync(cancellationToken);

        var trend = new List<TenantDailySalesDto>();
        for (int i = 0; i < 7; i++)
        {
            var day = sevenDaysAgo.AddDays(i);
            var item = salesRaw.FirstOrDefault(x => x.Date == day);
            trend.Add(new TenantDailySalesDto(
                day.ToString("yyyy-MM-dd"),
                item?.Total ?? 0m,
                item?.Count ?? 0));
        }

        var enabledFeatures = await _db.FeatureFlags
            .Where(f => f.TenantId == t.Id && f.IsEnabled)
            .Select(f => f.FeatureKey)
            .ToListAsync(cancellationToken);

        var recentAudits = await _db.AuditLogs
            .Where(a => a.TenantId == t.Id)
            .OrderByDescending(a => a.CreatedAt)
            .Take(12)
            .Select(a => new TenantAuditActivityDto(
                a.Action,
                a.EntityType,
                a.UserId.ToString(),
                a.CreatedAt))
            .ToListAsync(cancellationToken);

        var pCount = await _db.Products.CountAsync(p => p.TenantId == t.Id, cancellationToken);
        var sCount = await _db.Sales.CountAsync(s => s.TenantId == t.Id, cancellationToken);
        var milestone = 1;
        if (branches.Count > 0) milestone = 2;
        if (pCount > 0) milestone = 3;
        if (sCount > 0) milestone = 5;

        return Result.Success(new TenantDetailAdminDto(
            t.Id,
            t.Name,
            t.Currency,
            t.CountryCode,
            t.BusinessType,
            t.ContactEmail,
            t.ContactPhone,
            t.Address,
            t.TaxId,
            t.CreatedAt,
            t.IsActive,
            sub?.PlanCode ?? "Starter",
            sub?.Status.ToString() ?? (t.IsActive ? "Active" : "Suspended"),
            trialDays,
            sub?.PaidUntilUtc,
            milestone,
            branches,
            users,
            trend,
            enabledFeatures,
            recentAudits));
    }
}

using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Finance;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Domain.Pricing;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Infrastructure.Repositories;

public sealed class FleetAdminRepository : IFleetAdminRepository
{
    private readonly BusinessDbContext _db;

    public FleetAdminRepository(BusinessDbContext db) => _db = db;

    public async Task<FleetSummaryDto> GetFleetSummaryAsync(CancellationToken cancellationToken = default)
    {
        var totalTenants = await _db.Tenants.CountAsync(cancellationToken);
        var activeSubscriptions = await _db.Subscriptions.CountAsync(s => s.Status == SubscriptionStatus.Active, cancellationToken);
        var trials = await _db.Subscriptions.CountAsync(s => s.Status == SubscriptionStatus.Trial, cancellationToken);

        var sevenDaysFromNow = DateTime.UtcNow.AddDays(7);
        var expiringIn7Days = await _db.Subscriptions.CountAsync(
            s => (s.Status == SubscriptionStatus.Active && s.PaidUntilUtc != null && s.PaidUntilUtc <= sevenDaysFromNow) ||
                 (s.Status == SubscriptionStatus.Trial && s.TrialEndedAtUtc <= sevenDaysFromNow),
            cancellationToken);

        var thirtyDaysAgo = DateTime.UtcNow.AddDays(-30);
        var gmv = await _db.Sales
            .Where(s => s.SaleDate >= thirtyDaysAgo && s.Status == SaleStatus.Completed)
            .SumAsync(s => (decimal?)s.TotalAmount, cancellationToken) ?? 0m;

        var salesCount = await _db.Sales
            .CountAsync(s => s.SaleDate >= thirtyDaysAgo && s.Status == SaleStatus.Completed, cancellationToken);

        var productsCount = await _db.Products.CountAsync(cancellationToken);

        return new FleetSummaryDto(
            totalTenants,
            activeSubscriptions,
            trials,
            expiringIn7Days,
            atRiskTenants: expiringIn7Days,
            TotalGmv30Days: gmv,
            TotalSalesCount30Days: salesCount,
            TotalProductsCount: productsCount);
    }

    public async Task<PagedResult<TenantAdminSummaryDto>> ListTenantsAsync(
        string? search, string? status, string? health, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = _db.Tenants.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(t => t.Name.ToLower().Contains(s) || (t.Phone != null && t.Phone.Contains(s)));
        }

        var total = await query.CountAsync(cancellationToken);

        var tenants = await query
            .OrderByDescending(t => t.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var thirtyDaysAgo = DateTime.UtcNow.AddDays(-30);
        var todayStart = DateTime.UtcNow.Date;

        var items = new List<TenantAdminSummaryDto>();
        foreach (var t in tenants)
        {
            var sub = await _db.Subscriptions.AsNoTracking().FirstOrDefaultAsync(s => s.TenantId == t.Id, cancellationToken);
            var totalProducts = await _db.Products.AsNoTracking().CountAsync(p => p.TenantId == t.Id, cancellationToken);
            var salesCount = await _db.Sales.AsNoTracking().CountAsync(s => s.TenantId == t.Id && s.SaleDate >= thirtyDaysAgo && s.Status == SaleStatus.Completed, cancellationToken);
            var invCount = await _db.CustomerInvoices.IgnoreQueryFilters().AsNoTracking().CountAsync(i => i.TenantId == t.Id, cancellationToken);

            var todaySalesAmount = await _db.Sales.AsNoTracking()
                .Where(s => s.TenantId == t.Id && s.SaleDate >= todayStart && s.Status == SaleStatus.Completed)
                .SumAsync(s => (decimal?)s.TotalAmount, cancellationToken) ?? 0m;

            var gmv = await _db.Sales.AsNoTracking()
                .Where(s => s.TenantId == t.Id && s.SaleDate >= thirtyDaysAgo && s.Status == SaleStatus.Completed)
                .SumAsync(s => (decimal?)s.TotalAmount, cancellationToken) ?? 0m;

            var subStatus = sub?.Status.ToString() ?? "Trial";
            var daysLeft = sub != null
                ? (int)Math.Max(0, (sub.TrialEndedAtUtc - DateTime.UtcNow).TotalDays)
                : 14;

            var paidUntilStr = sub?.PaidUntilUtc?.ToString("yyyy-MM-dd");

            string healthStatus = "Good";
            if (subStatus == "Active" && salesCount > 20) healthStatus = "Excellent";
            else if (subStatus != "Active" && daysLeft <= 2) healthStatus = "AtRisk";

            if (!string.IsNullOrWhiteSpace(status) && !string.Equals(subStatus, status, StringComparison.OrdinalIgnoreCase))
                continue;

            if (!string.IsNullOrWhiteSpace(health) && !string.Equals(healthStatus, health, StringComparison.OrdinalIgnoreCase))
                continue;

            items.Add(new TenantAdminSummaryDto(
                t.Id,
                t.Name,
                t.Phone,
                Category: null,
                sub?.PlanCode ?? "Pro",
                subStatus,
                daysLeft,
                paidUntilStr,
                totalProducts,
                salesCount,
                invCount,
                gmv,
                healthStatus,
                TodaySales: $"TZS {todaySalesAmount:N0}",
                t.CreatedAt));
        }

        return new PagedResult<TenantAdminSummaryDto>(items, page, pageSize, total);
    }

    public async Task<TenantAdminDetailDto?> GetTenantDetailAsync(Guid tenantId, CancellationToken cancellationToken = default)
    {
        var tenant = await _db.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == tenantId, cancellationToken);
        if (tenant is null) return null;

        var sub = await _db.Subscriptions.AsNoTracking().FirstOrDefaultAsync(s => s.TenantId == tenantId, cancellationToken);
        var totalProducts = await _db.Products.AsNoTracking().CountAsync(p => p.TenantId == tenantId, cancellationToken);

        var lowStock = await _db.StockBalances.AsNoTracking()
            .CountAsync(sb => sb.TenantId == tenantId && sb.Quantity <= 5, cancellationToken);

        var thirtyDaysAgo = DateTime.UtcNow.AddDays(-30);
        var salesCount = await _db.Sales.AsNoTracking()
            .CountAsync(s => s.TenantId == tenantId && s.SaleDate >= thirtyDaysAgo && s.Status == SaleStatus.Completed, cancellationToken);

        var invCount = await _db.CustomerInvoices.IgnoreQueryFilters().AsNoTracking()
            .CountAsync(i => i.TenantId == tenantId, cancellationToken);

        var todayStart = DateTime.UtcNow.Date;
        var todaySalesAmount = await _db.Sales.AsNoTracking()
            .Where(s => s.TenantId == tenantId && s.SaleDate >= todayStart && s.Status == SaleStatus.Completed)
            .SumAsync(s => (decimal?)s.TotalAmount, cancellationToken) ?? 0m;

        var gmv = await _db.Sales.AsNoTracking()
            .Where(s => s.TenantId == tenantId && s.SaleDate >= thirtyDaysAgo && s.Status == SaleStatus.Completed)
            .SumAsync(s => (decimal?)s.TotalAmount, cancellationToken) ?? 0m;

        var flags = await _db.FeatureFlags.AsNoTracking().Where(f => f.TenantId == tenantId).ToListAsync(cancellationToken);
        var featureDict = flags.ToDictionary(f => f.Key, f => f.IsEnabled);

        var primaryUser = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.TenantId == tenantId, cancellationToken);

        var subStatus = sub?.Status.ToString() ?? "Trial";
        var daysLeft = sub != null
            ? (int)Math.Max(0, (sub.TrialEndedAtUtc - DateTime.UtcNow).TotalDays)
            : 14;

        string healthStatus = "Good";
        if (subStatus == "Active" && salesCount > 20) healthStatus = "Excellent";
        else if (subStatus != "Active" && daysLeft <= 2) healthStatus = "AtRisk";

        return new TenantAdminDetailDto(
            tenant.Id,
            tenant.Name,
            tenant.Phone,
            Category: null,
            sub?.PlanCode ?? "Pro",
            subStatus,
            daysLeft,
            sub?.PaidUntilUtc?.ToString("yyyy-MM-dd"),
            totalProducts,
            lowStock,
            salesCount,
            invCount,
            gmv,
            healthStatus,
            TodaySales: $"TZS {todaySalesAmount:N0}",
            featureDict,
            primaryUser?.Email,
            primaryUser?.FullName,
            tenant.CreatedAt);
    }

    public Task<Tenant?> GetTenantByIdAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.Tenants.FirstOrDefaultAsync(t => t.Id == tenantId, cancellationToken);

    public Task<User?> GetPrimaryOwnerAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => _db.Users.FirstOrDefaultAsync(u => u.TenantId == tenantId, cancellationToken);
}

public sealed class OmniTenantCatalogRepository : IOmniTenantCatalogRepository
{
    private readonly BusinessDbContext _db;

    public OmniTenantCatalogRepository(BusinessDbContext db) => _db = db;

    public async Task<PagedResult<OmniProductDto>> ListTenantProductsAsync(
        Guid tenantId, string? search, bool lowStockOnly, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = _db.Products.AsNoTracking().Where(p => p.TenantId == tenantId);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(p => p.Name.ToLower().Contains(s) || (p.Barcode != null && p.Barcode.Contains(s)) || (p.Sku != null && p.Sku.Contains(s)));
        }

        var total = await query.CountAsync(cancellationToken);

        var products = await query
            .OrderBy(p => p.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var productIds = products.Select(p => p.Id).ToList();

        var stockBalances = await _db.StockBalances.AsNoTracking()
            .Where(sb => sb.TenantId == tenantId && productIds.Contains(sb.ProductId))
            .GroupBy(sb => sb.ProductId)
            .Select(g => new { ProductId = g.Key, TotalStock = g.Sum(sb => sb.Quantity) })
            .ToDictionaryAsync(x => x.ProductId, x => x.TotalStock, cancellationToken);

        var prices = await _db.ProductPrices.AsNoTracking()
            .Where(pp => pp.TenantId == tenantId && productIds.Contains(pp.ProductId) && pp.PriceType == PriceType.Retail && pp.IsActive)
            .ToDictionaryAsync(pp => pp.ProductId, pp => pp.Price, cancellationToken);

        var categoryIds = products.Where(p => p.CategoryId.HasValue).Select(p => p.CategoryId!.Value).Distinct().ToList();
        var categories = await _db.ProductCategories.AsNoTracking()
            .Where(c => c.TenantId == tenantId && categoryIds.Contains(c.Id))
            .ToDictionaryAsync(c => c.Id, c => c.Name, cancellationToken);

        var items = new List<OmniProductDto>();
        foreach (var p in products)
        {
            var stockOnHand = stockBalances.TryGetValue(p.Id, out var s) ? s : 0m;
            var threshold = 5m;
            var stockStatus = stockOnHand <= 0 ? "OutOfStock" : (stockOnHand <= threshold ? "LowStock" : "Normal");

            if (lowStockOnly && stockStatus == "Normal")
                continue;

            var sellingPrice = prices.TryGetValue(p.Id, out var sp) ? sp : 0m;
            var categoryName = p.CategoryId.HasValue && categories.TryGetValue(p.CategoryId.Value, out var cName) ? cName : null;

            items.Add(new OmniProductDto(
                p.Id,
                p.Name,
                p.Barcode,
                p.Sku,
                categoryName,
                Unit: "pcs",
                p.CostPrice ?? 0m,
                sellingPrice,
                stockOnHand,
                threshold,
                stockStatus,
                p.Status == ProductStatus.Active));
        }

        return new PagedResult<OmniProductDto>(items, page, pageSize, total);
    }

    public Task<Product?> GetProductByIdAsync(Guid tenantId, Guid productId, CancellationToken cancellationToken = default)
        => _db.Products.FirstOrDefaultAsync(p => p.TenantId == tenantId && p.Id == productId, cancellationToken);

    public async Task<OmniProductDto?> UpdateProductAsync(
        Guid tenantId,
        Guid productId,
        string name,
        string? barcode,
        decimal buyingPrice,
        decimal sellingPrice,
        string? category,
        bool isActive,
        CancellationToken cancellationToken = default)
    {
        var product = await _db.Products.FirstOrDefaultAsync(p => p.TenantId == tenantId && p.Id == productId, cancellationToken);
        if (product is null) return null;

        Guid? categoryId = product.CategoryId;
        if (!string.IsNullOrWhiteSpace(category))
        {
            var existingCategory = await _db.ProductCategories.FirstOrDefaultAsync(
                c => c.TenantId == tenantId && c.Name.ToLower() == category.Trim().ToLower(), cancellationToken);
            if (existingCategory is null)
            {
                existingCategory = ProductCategory.Create(tenantId, category.Trim(), null);
                await _db.ProductCategories.AddAsync(existingCategory, cancellationToken);
                await _db.SaveChangesAsync(cancellationToken);
            }
            categoryId = existingCategory.Id;
        }

        product.UpdateProfile(
            name,
            product.Description,
            categoryId,
            product.BrandId,
            product.UnitOfMeasureId,
            product.TaxCategoryId,
            buyingPrice);

        product.UpdateIdentifiers(product.Sku, barcode);
        product.SetStatus(isActive ? ProductStatus.Active : ProductStatus.Inactive);

        var defaultPriceList = await _db.PriceLists.FirstOrDefaultAsync(pl => pl.TenantId == tenantId && pl.IsDefault, cancellationToken);
        if (defaultPriceList is null)
        {
            defaultPriceList = PriceList.Create(tenantId, "Standard Retail", "TZS", isDefault: true);
            await _db.PriceLists.AddAsync(defaultPriceList, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var price = await _db.ProductPrices.FirstOrDefaultAsync(
            pp => pp.TenantId == tenantId && pp.ProductId == productId && pp.PriceType == PriceType.Retail, cancellationToken);

        if (price != null)
        {
            price.Update(sellingPrice > 0 ? sellingPrice : 1m, defaultPriceList.Currency, minQuantity: 1m, effectiveFrom: null, effectiveTo: null, isActive: true);
        }
        else if (sellingPrice > 0)
        {
            price = ProductPrice.Assign(
                tenantId,
                defaultPriceList.Id,
                Guid.NewGuid(),
                productId,
                variantId: null,
                branchId: null,
                PriceType.Retail,
                sellingPrice,
                defaultPriceList.Currency,
                minQuantity: 1m,
                effectiveFrom: null,
                effectiveTo: null,
                isActive: true);
            await _db.ProductPrices.AddAsync(price, cancellationToken);
        }

        await _db.SaveChangesAsync(cancellationToken);

        var currentStock = await _db.StockBalances.AsNoTracking()
            .Where(sb => sb.TenantId == tenantId && sb.ProductId == productId)
            .SumAsync(sb => (decimal?)sb.Quantity, cancellationToken) ?? 0m;

        return new OmniProductDto(
            product.Id,
            product.Name,
            product.Barcode,
            product.Sku,
            category,
            Unit: "pcs",
            buyingPrice,
            sellingPrice,
            currentStock,
            LowStockThreshold: 5m,
            StockStatus: currentStock <= 0 ? "OutOfStock" : (currentStock <= 5m ? "LowStock" : "Normal"),
            product.Status == ProductStatus.Active);
    }

    public async Task AdjustProductStockAsync(
        Guid tenantId, Guid productId, decimal newStockQuantity, string reason, Guid? operatorUserId, CancellationToken cancellationToken = default)
    {
        var product = await _db.Products.FirstOrDefaultAsync(p => p.TenantId == tenantId && p.Id == productId, cancellationToken);
        if (product is null) return;

        var branch = await _db.Branches.FirstOrDefaultAsync(b => b.TenantId == tenantId, cancellationToken);
        var branchId = branch?.Id ?? Guid.NewGuid();

        var warehouse = await _db.Warehouses.FirstOrDefaultAsync(w => w.TenantId == tenantId, cancellationToken);
        if (warehouse is null)
        {
            warehouse = Warehouse.Create(tenantId, branchId, "Main Store", "WH-MAIN", null);
            await _db.Warehouses.AddAsync(warehouse, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var balance = await _db.StockBalances.FirstOrDefaultAsync(
            sb => sb.TenantId == tenantId && sb.ProductId == productId && sb.WarehouseId == warehouse.Id, cancellationToken);

        var currentQty = balance?.Quantity ?? 0m;
        var delta = newStockQuantity - currentQty;

        if (balance is null)
        {
            balance = StockBalance.Create(tenantId, warehouse.Id, Guid.Empty, productId, null);
            balance.Apply(newStockQuantity);
            await _db.StockBalances.AddAsync(balance, cancellationToken);
        }
        else if (delta != 0)
        {
            balance.Apply(delta);
        }

        if (delta != 0)
        {
            var movement = StockMovement.Record(
                tenantId,
                branchId,
                warehouse.Id,
                Guid.Empty,
                productId,
                null,
                StockMovementType.Adjustment,
                delta,
                product.UnitOfMeasureId,
                DateTime.UtcNow,
                reason: $"[Platform Back-Office] {reason}",
                createdBy: operatorUserId);

            await _db.StockMovements.AddAsync(movement, cancellationToken);
        }

        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task SeedStarterCatalogAsync(
        Guid tenantId, string templateType, Guid? operatorUserId, CancellationToken cancellationToken = default)
    {
        var starterItems = templateType switch
        {
            "Pharmacy" => new (string Name, string Barcode, decimal Buying, decimal Selling, decimal Stock)[]
            {
                ("Panadol Extra Tablets (Pack)", "8901030456123", 3500m, 5000m, 50m),
                ("Amoxicillin Capsules 500mg", "8901030998877", 4000m, 6500m, 30m),
                ("Cold Cap Multi-Symptom", "8901030112233", 2500m, 4000m, 40m),
                ("Antiseptic Liquid 250ml", "8901030445566", 4500m, 6000m, 20m),
            },
            "Hardware" => new (string Name, string Barcode, decimal Buying, decimal Selling, decimal Stock)[]
            {
                ("Misumari Inch 3 (1kg)", "6161103333333", 3000m, 4000m, 100m),
                ("Rangi ya Weather Guard 20L", "6161104444444", 85000m, 105000m, 15m),
                ("Soketi ya Ukutani (Double Socket)", "6161105555555", 4500m, 6500m, 45m),
                ("Tape ya Umeme (PVC Electrical Tape)", "6161106666666", 1000m, 1500m, 60m),
            },
            _ => new (string Name, string Barcode, decimal Buying, decimal Selling, decimal Stock)[]
            {
                ("Azam Wheat Flour 1kg", "6161101234567", 1800m, 2200m, 50m),
                ("Kilombero Pure Rice 5kg", "6161109876543", 12000m, 14500m, 30m),
                ("Mafuta ya Kula Korie 1L", "6161107777777", 4200m, 5000m, 40m),
                ("Sukari ya Kilombero 1kg", "6161108888888", 2600m, 3000m, 80m),
                ("Maji ya Uhai 500ml", "6161102222222", 400m, 600m, 120m),
            }
        };

        var branch = await _db.Branches.FirstOrDefaultAsync(b => b.TenantId == tenantId, cancellationToken);
        var branchId = branch?.Id ?? Guid.NewGuid();

        var warehouse = await _db.Warehouses.FirstOrDefaultAsync(w => w.TenantId == tenantId, cancellationToken);
        if (warehouse is null)
        {
            warehouse = Warehouse.Create(tenantId, branchId, "Main Store", "WH-MAIN", null);
            await _db.Warehouses.AddAsync(warehouse, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var pieceUnit = await _db.UnitsOfMeasure.FirstOrDefaultAsync(u => u.TenantId == tenantId && u.Abbreviation == "PCS", cancellationToken);
        if (pieceUnit is null)
        {
            pieceUnit = UnitOfMeasure.Create(tenantId, "Pieces", "PCS");
            await _db.UnitsOfMeasure.AddAsync(pieceUnit, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var defaultPriceList = await _db.PriceLists.FirstOrDefaultAsync(pl => pl.TenantId == tenantId && pl.IsDefault, cancellationToken);
        if (defaultPriceList is null)
        {
            defaultPriceList = PriceList.Create(tenantId, "Standard Retail", "TZS", isDefault: true);
            await _db.PriceLists.AddAsync(defaultPriceList, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        foreach (var item in starterItems)
        {
            var existing = await _db.Products.FirstOrDefaultAsync(
                p => p.TenantId == tenantId && p.Barcode == item.Barcode, cancellationToken);

            if (existing != null) continue;

            var product = Product.Create(
                tenantId: tenantId,
                name: item.Name,
                description: $"Starter pack item: {item.Name}",
                sku: $"SKU-{Random.Shared.Next(10000, 99999)}",
                barcode: item.Barcode,
                categoryId: null,
                brandId: null,
                unitOfMeasureId: pieceUnit.Id,
                productType: ProductType.Product,
                status: ProductStatus.Active,
                taxCategoryId: null,
                costPrice: item.Buying);

            await _db.Products.AddAsync(product, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);

            var productPrice = ProductPrice.Assign(
                tenantId,
                defaultPriceList.Id,
                Guid.NewGuid(),
                product.Id,
                variantId: null,
                branchId: null,
                PriceType.Retail,
                item.Selling,
                defaultPriceList.Currency,
                minQuantity: 1m,
                effectiveFrom: null,
                effectiveTo: null,
                isActive: true);

            await _db.ProductPrices.AddAsync(productPrice, cancellationToken);

            var balance = StockBalance.Create(tenantId, warehouse.Id, Guid.Empty, product.Id, null);
            balance.Apply(item.Stock);
            await _db.StockBalances.AddAsync(balance, cancellationToken);

            var movement = StockMovement.Record(
                tenantId,
                branchId,
                warehouse.Id,
                Guid.Empty,
                product.Id,
                null,
                StockMovementType.Adjustment,
                item.Stock,
                pieceUnit.Id,
                DateTime.UtcNow,
                reason: $"[Starter Pack Seed] {templateType}",
                createdBy: operatorUserId);

            await _db.StockMovements.AddAsync(movement, cancellationToken);
        }

        await _db.SaveChangesAsync(cancellationToken);
    }
}

public sealed class OmniTenantSalesRepository : IOmniTenantSalesRepository
{
    private readonly BusinessDbContext _db;

    public OmniTenantSalesRepository(BusinessDbContext db) => _db = db;

    public async Task<PagedResult<OmniSaleSummaryDto>> ListTenantSalesAsync(
        Guid tenantId, string? search, DateTime? startDate, DateTime? endDate, Guid? cashierId, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = _db.Sales.AsNoTracking().Where(s => s.TenantId == tenantId);

        if (startDate.HasValue) query = query.Where(s => s.SaleDate >= startDate.Value);
        if (endDate.HasValue) query = query.Where(s => s.SaleDate <= endDate.Value);
        if (cashierId.HasValue) query = query.Where(s => s.CashierId == cashierId.Value);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(sale => sale.Number.ToLower().Contains(s));
        }

        var total = await query.CountAsync(cancellationToken);

        var sales = await query
            .OrderByDescending(s => s.SaleDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var items = new List<OmniSaleSummaryDto>();
        foreach (var s in sales)
        {
            var cashier = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == s.CashierId, cancellationToken);
            var customerName = s.CustomerName ?? "Walk-in Customer";
            var paymentMethod = s.Payments.FirstOrDefault()?.Method.ToString() ?? "Cash";

            items.Add(new OmniSaleSummaryDto(
                s.Id,
                s.Number,
                s.SaleDate,
                s.TotalAmount,
                customerName,
                cashier?.FullName ?? "Cashier",
                s.Status.ToString(),
                paymentMethod));
        }

        return new PagedResult<OmniSaleSummaryDto>(items, page, pageSize, total);
    }

    public async Task<OmniSaleDetailDto?> GetTenantSaleDetailAsync(Guid tenantId, Guid saleId, CancellationToken cancellationToken = default)
    {
        var s = await _db.Sales.AsNoTracking().FirstOrDefaultAsync(x => x.TenantId == tenantId && x.Id == saleId, cancellationToken);
        if (s is null) return null;

        var cashier = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == s.CashierId, cancellationToken);
        var customerName = s.CustomerName ?? "Walk-in Customer";

        var lines = s.Lines.Select(l => new OmniSaleLineDto(
            l.ProductName,
            l.Quantity,
            l.UnitPrice,
            l.LineTotal)).ToList();

        var paymentMethod = s.Payments.FirstOrDefault()?.Method.ToString() ?? "Cash";

        return new OmniSaleDetailDto(
            s.Id,
            s.Number,
            s.SaleDate,
            s.TotalAmount,
            customerName,
            cashier?.FullName ?? "Cashier",
            s.Status.ToString(),
            paymentMethod,
            lines);
    }

    public Task<Sale?> GetSaleByIdAsync(Guid tenantId, Guid saleId, CancellationToken cancellationToken = default)
        => _db.Sales.FirstOrDefaultAsync(s => s.TenantId == tenantId && s.Id == saleId, cancellationToken);

    public async Task VoidSaleAsync(Sale sale, string reason, Guid? operatorUserId, CancellationToken cancellationToken = default)
    {
        var operatorId = operatorUserId.HasValue && operatorUserId.Value != Guid.Empty ? operatorUserId.Value : Guid.NewGuid();
        sale.Void(reason, operatorId, DateTime.UtcNow);

        var warehouse = await _db.Warehouses.FirstOrDefaultAsync(w => w.TenantId == sale.TenantId, cancellationToken);
        if (warehouse != null)
        {
            foreach (var line in sale.Lines)
            {
                var balance = await _db.StockBalances.FirstOrDefaultAsync(
                    sb => sb.TenantId == sale.TenantId && sb.ProductId == line.ProductId && sb.WarehouseId == warehouse.Id, cancellationToken);

                if (balance != null)
                {
                    balance.Apply(line.Quantity);
                }

                var movement = StockMovement.Record(
                    sale.TenantId,
                    sale.BranchId,
                    warehouse.Id,
                    Guid.Empty,
                    line.ProductId,
                    line.VariantId,
                    StockMovementType.SaleVoid,
                    line.Quantity,
                    line.UnitOfMeasureId,
                    DateTime.UtcNow,
                    reason: $"[Sale Voided: {sale.Number}] {reason}",
                    createdBy: operatorUserId);

                await _db.StockMovements.AddAsync(movement, cancellationToken);
            }
        }

        _db.Sales.Update(sale);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task<PagedResult<OmniCashSessionDto>> ListTenantCashSessionsAsync(
        Guid tenantId, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = _db.CashSessions.AsNoTracking().Where(cs => cs.TenantId == tenantId);
        var total = await query.CountAsync(cancellationToken);

        var sessions = await query
            .OrderByDescending(cs => cs.OpenedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var items = new List<OmniCashSessionDto>();
        foreach (var cs in sessions)
        {
            var account = await _db.MoneyAccounts.AsNoTracking().FirstOrDefaultAsync(a => a.Id == cs.AccountId, cancellationToken);

            items.Add(new OmniCashSessionDto(
                cs.Id,
                account?.Name ?? "Main Till",
                account?.Name ?? "Cashier",
                cs.OpenedAt,
                cs.ClosedAt,
                cs.OpeningCash,
                (cs.ClosingCash ?? cs.ExpectedCash ?? cs.OpeningCash) - cs.OpeningCash,
                cs.ClosingCash,
                cs.Variance ?? 0m,
                cs.Status == CashSessionStatus.Open));
        }

        return new PagedResult<OmniCashSessionDto>(items, page, pageSize, total);
    }
}

public sealed class OmniTenantInvoicesRepository : IOmniTenantInvoicesRepository
{
    private readonly BusinessDbContext _db;

    public OmniTenantInvoicesRepository(BusinessDbContext db) => _db = db;

    public async Task<PagedResult<OmniInvoiceSummaryDto>> ListTenantInvoicesAsync(
        Guid tenantId, string? search, string? status, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = _db.CustomerInvoices.IgnoreQueryFilters().AsNoTracking().Where(i => i.TenantId == tenantId);

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<CustomerInvoiceStatus>(status, true, out var sEnum))
        {
            query = query.Where(i => i.Status == sEnum);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(i => i.Number.ToLower().Contains(s) || (i.CustomerName != null && i.CustomerName.ToLower().Contains(s)));
        }

        var total = await query.CountAsync(cancellationToken);

        var invoices = await query
            .OrderByDescending(i => i.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var items = invoices.Select(inv => new OmniInvoiceSummaryDto(
            inv.Id,
            inv.Number,
            inv.CustomerName ?? "Customer",
            inv.IssueDate,
            inv.DueDate,
            inv.TotalAmount,
            inv.AmountPaid,
            inv.Status.ToString())).ToList();

        return new PagedResult<OmniInvoiceSummaryDto>(items, page, pageSize, total);
    }

    public Task<CustomerInvoice?> GetInvoiceByIdAsync(Guid tenantId, Guid invoiceId, CancellationToken cancellationToken = default)
        => _db.CustomerInvoices.IgnoreQueryFilters().FirstOrDefaultAsync(i => i.TenantId == tenantId && i.Id == invoiceId, cancellationToken);

    public async Task UpdateInvoiceStatusAsync(CustomerInvoice invoice, CustomerInvoiceStatus newStatus, CancellationToken cancellationToken = default)
    {
        if (newStatus == CustomerInvoiceStatus.Void)
        {
            invoice.Void();
        }
        else if (newStatus == CustomerInvoiceStatus.Paid)
        {
            invoice.RecordPayment(invoice.BalanceDue, "Direct Clearance", "Platform Back-Office Payment");
        }

        _db.CustomerInvoices.Update(invoice);
        await _db.SaveChangesAsync(cancellationToken);
    }
}

public sealed class PlatformTeamRepository : IPlatformTeamRepository
{
    private readonly BusinessDbContext _db;

    public PlatformTeamRepository(BusinessDbContext db) => _db = db;

    public async Task<IReadOnlyList<PlatformOperatorDto>> ListPlatformOperatorsAsync(CancellationToken cancellationToken = default)
    {
        var operators = await _db.PlatformOperators.AsNoTracking().ToListAsync(cancellationToken);
        var userIds = operators.Select(o => o.UserId).Distinct().ToList();
        var users = await _db.Users.AsNoTracking().Where(u => userIds.Contains(u.Id)).ToDictionaryAsync(u => u.Id, cancellationToken);

        return operators.Select(op => new PlatformOperatorDto(
            op.Id,
            op.UserId,
            users.TryGetValue(op.UserId, out var u) ? u.Email : "Unknown",
            op.Role.ToString(),
            op.IsActive,
            op.AssignedAtUtc)).ToList();
    }

    public Task<User?> FindUserByEmailAsync(string email, CancellationToken cancellationToken = default)
        => _db.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email.Trim().ToLower(), cancellationToken);

    public async Task AssignPlatformRoleAsync(Guid userId, PlatformRoleType role, CancellationToken cancellationToken = default)
    {
        var existing = await _db.PlatformOperators.FirstOrDefaultAsync(o => o.UserId == userId, cancellationToken);
        if (existing != null)
        {
            existing.ChangeRole(role, Guid.Empty);
            _db.PlatformOperators.Update(existing);
        }
        else
        {
            var op = PlatformOperator.Create(userId, role, Guid.Empty);
            await _db.PlatformOperators.AddAsync(op, cancellationToken);
        }

        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task RevokePlatformRoleAsync(Guid operatorId, CancellationToken cancellationToken = default)
    {
        var op = await _db.PlatformOperators.FirstOrDefaultAsync(o => o.Id == operatorId, cancellationToken);
        if (op != null)
        {
            op.Deactivate();
            _db.PlatformOperators.Update(op);
            await _db.SaveChangesAsync(cancellationToken);
        }
    }
}

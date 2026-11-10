using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Pricing;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Shared;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Application.Features.Tenants;

public sealed record TenantProductAdminDto(
    Guid Id,
    string Name,
    string? Sku,
    string? Barcode,
    string Unit,
    string? Category,
    decimal SellingPrice,
    decimal? CostPrice,
    decimal TotalStock,
    bool IsActive);

public sealed record PagedTenantProductsResult(
    IReadOnlyList<TenantProductAdminDto> Items,
    int TotalCount,
    int Page,
    int PageSize);

// ── 1. List Products for Tenant ──────────────────────────────────
public sealed record ListTenantProductsAdminQuery(
    Guid TenantId,
    string? Search = null,
    int Page = 1,
    int PageSize = 50)
    : IRequest<Result<PagedTenantProductsResult>>;

public sealed class ListTenantProductsAdminQueryHandler
    : IRequestHandler<ListTenantProductsAdminQuery, Result<PagedTenantProductsResult>>
{
    private readonly BusinessDbContext _db;

    public ListTenantProductsAdminQueryHandler(BusinessDbContext db) => _db = db;

    public async Task<Result<PagedTenantProductsResult>> Handle(
        ListTenantProductsAdminQuery request, CancellationToken cancellationToken)
    {
        var page = request.Page > 0 ? request.Page : 1;
        var pageSize = request.PageSize is > 0 and <= 100 ? request.PageSize : 50;

        var query = _db.Products
            .Where(p => p.TenantId == request.TenantId);

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var s = request.Search.Trim().ToLowerInvariant();
            query = query.Where(p =>
                p.Name.ToLower().Contains(s) ||
                (p.Sku != null && p.Sku.ToLower().Contains(s)) ||
                (p.Barcode != null && p.Barcode.Contains(s)));
        }

        var total = await query.CountAsync(cancellationToken);

        var products = await query
            .OrderBy(p => p.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var productIds = products.Select(p => p.Id).ToList();

        var unitIds = products.Select(p => p.UnitOfMeasureId).Distinct().ToList();
        var units = await _db.UnitsOfMeasure
            .Where(u => unitIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.Abbreviation, cancellationToken);

        var categoryIds = products.Where(p => p.CategoryId.HasValue).Select(p => p.CategoryId!.Value).Distinct().ToList();
        var categories = await _db.ProductCategories
            .Where(c => categoryIds.Contains(c.Id))
            .ToDictionaryAsync(c => c.Id, c => c.Name, cancellationToken);

        var prices = await _db.ProductPrices
            .Where(p => p.TenantId == request.TenantId && productIds.Contains(p.ProductId))
            .GroupBy(p => p.ProductId)
            .Select(g => new { ProductId = g.Key, Price = g.OrderByDescending(x => x.CreatedAt).Select(x => x.Price).FirstOrDefault() })
            .ToDictionaryAsync(x => x.ProductId, x => x.Price, cancellationToken);

        var stocks = await _db.StockBalances
            .Where(s => s.TenantId == request.TenantId && productIds.Contains(s.ProductId))
            .GroupBy(s => s.ProductId)
            .Select(g => new { ProductId = g.Key, TotalQuantity = g.Sum(x => x.Quantity) })
            .ToDictionaryAsync(x => x.ProductId, x => x.TotalQuantity, cancellationToken);

        var dtos = products.Select(p =>
        {
            units.TryGetValue(p.UnitOfMeasureId, out var unitName);
            string? catName = null;
            if (p.CategoryId.HasValue) categories.TryGetValue(p.CategoryId.Value, out catName);

            prices.TryGetValue(p.Id, out var price);
            stocks.TryGetValue(p.Id, out var stockQty);

            return new TenantProductAdminDto(
                p.Id,
                p.Name,
                p.Sku,
                p.Barcode,
                unitName ?? "PCS",
                catName,
                price,
                p.CostPrice,
                stockQty,
                p.Status == ProductStatus.Active);
        }).ToList();

        return Result.Success(new PagedTenantProductsResult(dtos, total, page, pageSize));
    }
}

// ── 2. Update Product for Tenant ──────────────────────────────────
public sealed record UpdateTenantProductAdminCommand(
    Guid TenantId,
    Guid ProductId,
    string Name,
    decimal SellingPrice,
    decimal? CostPrice,
    string? Barcode)
    : IRequest<Result<TenantProductAdminDto>>;

public sealed class UpdateTenantProductAdminCommandHandler
    : IRequestHandler<UpdateTenantProductAdminCommand, Result<TenantProductAdminDto>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public UpdateTenantProductAdminCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<TenantProductAdminDto>> Handle(
        UpdateTenantProductAdminCommand command, CancellationToken cancellationToken)
    {
        var product = await _db.Products
            .FirstOrDefaultAsync(p => p.TenantId == command.TenantId && p.Id == command.ProductId, cancellationToken);

        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        var oldPrice = product.CostPrice;
        product.Update(
            command.Name,
            product.Description,
            product.CategoryId,
            product.BrandId,
            product.UnitOfMeasureId,
            command.CostPrice,
            product.TaxCategoryId);

        if (!string.IsNullOrWhiteSpace(command.Barcode))
        {
            product.UpdateBarcode(command.Barcode);
        }

        // Update default price list
        var defaultPriceList = await _db.PriceLists
            .FirstOrDefaultAsync(p => p.TenantId == command.TenantId && p.IsDefault, cancellationToken);

        if (defaultPriceList is not null)
        {
            var productPrice = await _db.ProductPrices
                .FirstOrDefaultAsync(p => p.PriceListId == defaultPriceList.Id && p.ProductId == product.Id, cancellationToken);

            if (productPrice is null)
            {
                var newPrice = ProductPrice.Create(
                    defaultPriceList.Id,
                    command.TenantId,
                    product.Id,
                    null,
                    null,
                    command.SellingPrice,
                    "RETAIL",
                    1);
                await _db.ProductPrices.AddAsync(newPrice, cancellationToken);
            }
            else
            {
                productPrice.UpdatePrice(command.SellingPrice);
            }
        }

        await _db.SaveChangesAsync(cancellationToken);

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        await _auditLogs.AddAsync(AuditLog.Create(
            command.TenantId,
            operatorUserId,
            "Platform.ProductUpdate",
            "Product",
            product.Id.ToString()),
            cancellationToken);

        var unit = await _db.UnitsOfMeasure
            .Where(u => u.Id == product.UnitOfMeasureId)
            .Select(u => u.Abbreviation)
            .FirstOrDefaultAsync(cancellationToken);

        var stockQty = await _db.StockBalances
            .Where(s => s.TenantId == command.TenantId && s.ProductId == product.Id)
            .SumAsync(s => s.Quantity, cancellationToken);

        return Result.Success(new TenantProductAdminDto(
            product.Id,
            product.Name,
            product.Sku,
            product.Barcode,
            unit ?? "PCS",
            null,
            command.SellingPrice,
            product.CostPrice,
            stockQty,
            product.Status == ProductStatus.Active));
    }
}

// ── 3. Adjust Stock for Tenant ───────────────────────────────────
public sealed record AdjustTenantStockAdminCommand(
    Guid TenantId,
    Guid ProductId,
    Guid? WarehouseId,
    decimal NewQuantity,
    string Reason)
    : IRequest<Result<decimal>>;

public sealed class AdjustTenantStockAdminCommandHandler
    : IRequestHandler<AdjustTenantStockAdminCommand, Result<decimal>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public AdjustTenantStockAdminCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<decimal>> Handle(
        AdjustTenantStockAdminCommand command, CancellationToken cancellationToken)
    {
        var product = await _db.Products
            .FirstOrDefaultAsync(p => p.TenantId == command.TenantId && p.Id == command.ProductId, cancellationToken);
        if (product is null) return Error.NotFound("Product not found.");

        var warehouseId = command.WarehouseId;
        if (!warehouseId.HasValue)
        {
            var firstWarehouse = await _db.Warehouses
                .FirstOrDefaultAsync(w => w.TenantId == command.TenantId && w.IsActive, cancellationToken);
            warehouseId = firstWarehouse?.Id;
        }

        if (!warehouseId.HasValue)
        {
            return Error.NotFound("No warehouse found for this tenant.");
        }

        var stockLoc = await _db.StockLocations
            .FirstOrDefaultAsync(l => l.WarehouseId == warehouseId.Value, cancellationToken);
        var locationId = stockLoc?.Id ?? Guid.NewGuid();

        var balance = await _db.StockBalances
            .FirstOrDefaultAsync(b => b.TenantId == command.TenantId && b.ProductId == product.Id && b.WarehouseId == warehouseId.Value, cancellationToken);

        var currentQty = balance?.Quantity ?? 0m;
        var delta = command.NewQuantity - currentQty;

        if (balance is null)
        {
            balance = StockBalance.Create(command.TenantId, product.Id, null, warehouseId.Value, locationId, command.NewQuantity);
            await _db.StockBalances.AddAsync(balance, cancellationToken);
        }
        else
        {
            balance.Adjust(delta);
        }

        var movement = StockMovement.Create(
            command.TenantId,
            product.Id,
            null,
            warehouseId.Value,
            locationId,
            StockMovementType.Adjustment,
            delta,
            "Platform Operator Adjustment: " + command.Reason,
            "PLATFORM",
            _tenantContext.UserId?.ToString());

        await _db.StockMovements.AddAsync(movement, cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        await _auditLogs.AddAsync(AuditLog.Create(
            command.TenantId,
            operatorUserId,
            "Platform.StockAdjust",
            "StockBalance",
            balance.Id.ToString()),
            cancellationToken);

        return Result.Success(command.NewQuantity);
    }
}

// ── 4. Seed Starter Catalog Pack ─────────────────────────────────
public sealed record SeedTenantStarterCatalogCommand(
    Guid TenantId,
    string TemplateType)
    : IRequest<Result<int>>;

public sealed class SeedTenantStarterCatalogCommandHandler
    : IRequestHandler<SeedTenantStarterCatalogCommand, Result<int>>
{
    private readonly BusinessDbContext _db;
    private readonly ITenantContext _tenantContext;
    private readonly IAuditLogRepository _auditLogs;

    public SeedTenantStarterCatalogCommandHandler(
        BusinessDbContext db,
        ITenantContext tenantContext,
        IAuditLogRepository auditLogs)
    {
        _db = db;
        _tenantContext = tenantContext;
        _auditLogs = auditLogs;
    }

    public async Task<Result<int>> Handle(
        SeedTenantStarterCatalogCommand command, CancellationToken cancellationToken)
    {
        var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.Id == command.TenantId, cancellationToken);
        if (tenant is null) return Error.NotFound("Tenant not found.");

        var warehouse = await _db.Warehouses
            .Include(w => w.Locations)
            .FirstOrDefaultAsync(w => w.TenantId == command.TenantId && w.IsActive, cancellationToken);

        if (warehouse is null)
        {
            var branch = await _db.Branches.FirstOrDefaultAsync(b => b.TenantId == command.TenantId, cancellationToken);
            if (branch is null)
            {
                branch = Domain.Identity.Branch.Create(command.TenantId, "Duka Kuu", "MAIN");
                await _db.Branches.AddAsync(branch, cancellationToken);
                await _db.SaveChangesAsync(cancellationToken);
            }

            warehouse = Warehouse.Create(command.TenantId, branch.Id, "Stoo Kuu", "MAIN", "Stoo Kuu");
            await _db.Warehouses.AddAsync(warehouse, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var stockLocation = warehouse.Locations.FirstOrDefault() ??
            StockLocation.Create(warehouse.Id, "MAIN", "Eneo Kuu");

        var defaultPriceList = await _db.PriceLists
            .FirstOrDefaultAsync(p => p.TenantId == command.TenantId && p.IsDefault, cancellationToken);

        if (defaultPriceList is null)
        {
            defaultPriceList = PriceList.Create(command.TenantId, "Bei za Rejareja", tenant.Currency, true);
            await _db.PriceLists.AddAsync(defaultPriceList, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var pieceUnit = await _db.UnitsOfMeasure
            .FirstOrDefaultAsync(u => u.TenantId == command.TenantId && u.Abbreviation == "PCS", cancellationToken);
        if (pieceUnit is null)
        {
            pieceUnit = UnitOfMeasure.Create(command.TenantId, "Kipande", "PCS");
            await _db.UnitsOfMeasure.AddAsync(pieceUnit, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        // Templates definition
        var itemsToSeed = command.TemplateType.ToLowerInvariant() switch
        {
            "pharmacy" => new[]
            {
                ("Paracetamol 500mg Tabs", 1000m, 600m, "PH-001"),
                ("Amoxicillin 250mg Caps", 2500m, 1800m, "PH-002"),
                ("Cold & Flu Syrup 100ml", 3500m, 2200m, "PH-003"),
                ("Diclofenac Gel 30g", 4000m, 2500m, "PH-004"),
                ("Vitamin C 1000mg Tabs", 5000m, 3200m, "PH-005"),
                ("Bandage Roll 10cm", 1500m, 900m, "PH-006"),
                ("Surgical Spirit 200ml", 3000m, 1900m, "PH-007"),
                ("Hand Sanitizer 500ml", 4500m, 2800m, "PH-008"),
            },
            "hardware" => new[]
            {
                ("Saruji Dangote 50kg", 18500m, 16500m, "HW-001"),
                ("Misumari Nchi 3 (1kg)", 3500m, 2600m, "HW-002"),
                ("Misumari Nchi 4 (1kg)", 3500m, 2600m, "HW-003"),
                ("Bomba la Maji PVC 1/2", 6500m, 4800m, "HW-004"),
                ("Rangi ya Maji Weatherguard 20L", 65000m, 52000m, "HW-005"),
                ("Brashi ya Rangi Nchi 4", 3000m, 1800m, "HW-006"),
                ("Komeo ya Mlango Chuma", 4500m, 3000m, "HW-007"),
                ("Koleo ya Umeme", 8500m, 6000m, "HW-008"),
            },
            _ => new[] // Retail / Grocery (Default)
            {
                ("Sukari ya Kilombero 1kg", 3200m, 2700m, "GR-001"),
                ("Unga wa Ngano Azam 1kg", 2200m, 1800m, "GR-002"),
                ("Unga wa Sembe Taifa 1kg", 1800m, 1400m, "GR-003"),
                ("Mafuta ya Kula Korie 1L", 5500m, 4600m, "GR-004"),
                ("Mchele Super Kyela 1kg", 3000m, 2400m, "GR-005"),
                ("Sabuni ya Kufulia Omo 500g", 3500m, 2800m, "GR-006"),
                ("Sabuni ya Kipande Ushindi", 1500m, 1100m, "GR-007"),
                ("Chumvi ya Mawe 1kg", 800m, 500m, "GR-008"),
                ("Maji ya Kunywa Kilimanjaro 500ml", 600m, 400m, "GR-009"),
                ("Soda Coca-Cola 350ml", 800m, 600m, "GR-010"),
                ("Chai ya Majani Chai Bora 100g", 1200m, 850m, "GR-011"),
                ("Maziwa Fresh Azam 500ml", 1500m, 1150m, "GR-012"),
            }
        };

        var seededCount = 0;
        foreach (var (name, sellPrice, costPrice, sku) in itemsToSeed)
        {
            var existing = await _db.Products
                .FirstOrDefaultAsync(p => p.TenantId == command.TenantId && (p.Name == name || p.Sku == sku), cancellationToken);

            if (existing is not null) continue;

            var product = Product.Create(
                command.TenantId,
                name,
                pieceUnit.Id,
                ProductType.Goods,
                sku,
                null,
                null,
                null,
                costPrice);

            await _db.Products.AddAsync(product, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);

            var price = ProductPrice.Create(
                defaultPriceList.Id,
                command.TenantId,
                product.Id,
                null,
                null,
                sellPrice,
                "RETAIL",
                1);

            await _db.ProductPrices.AddAsync(price, cancellationToken);

            // Add starter opening stock of 25 units
            var initialStock = 25m;
            var balance = StockBalance.Create(
                command.TenantId,
                product.Id,
                null,
                warehouse.Id,
                stockLocation.Id,
                initialStock);

            await _db.StockBalances.AddAsync(balance, cancellationToken);

            var movement = StockMovement.Create(
                command.TenantId,
                product.Id,
                null,
                warehouse.Id,
                stockLocation.Id,
                StockMovementType.OpeningStock,
                initialStock,
                "Starter Catalog Pre-Seeded by Platform Admin",
                "STARTER_SEED",
                _tenantContext.UserId?.ToString());

            await _db.StockMovements.AddAsync(movement, cancellationToken);
            seededCount++;
        }

        await _db.SaveChangesAsync(cancellationToken);

        var operatorUserId = _tenantContext.UserId ?? Guid.Empty;
        await _auditLogs.AddAsync(AuditLog.Create(
            command.TenantId,
            operatorUserId,
            "Platform.SeedCatalog",
            "Tenant",
            command.TemplateType),
            cancellationToken);

        return Result.Success(seededCount);
    }
}

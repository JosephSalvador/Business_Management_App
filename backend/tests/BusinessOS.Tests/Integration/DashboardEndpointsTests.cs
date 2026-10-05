using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Pricing;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class DashboardEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public DashboardEndpointsTests(BusinessOsApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public Task DisposeAsync()
    {
        _client.Dispose();
        return Task.CompletedTask;
    }

    private static JsonElement Body(string json) => JsonSerializer.Deserialize<JsonElement>(json);

    private static string GetProperty(JsonElement doc, params string[] path)
    {
        JsonElement current = doc;
        foreach (var part in path)
        {
            if (current.ValueKind == JsonValueKind.Array && int.TryParse(part, out var index))
            {
                current = current[index];
            }
            else
            {
                current = current.GetProperty(part);
            }
        }

        return current.ToString();
    }

    private Task<(string AccessToken, string TenantId)> RegisterAsync(string label)
        => global::BusinessOS.Tests.Support.TestRegistration.RegisterVerifiedAsync(_client, label);

    private async Task<string> RegisterLimitedViewerAsync(
        string email, Guid tenantId, IReadOnlyList<string> permissions)
    {
        using var db = CreateDbContext();
        var viewPermissions = await db.Permissions
            .Where(p => permissions.Contains(p.Name))
            .ToListAsync();
        var role = Role.Create(tenantId, $"Viewer-{Guid.NewGuid():N}");
        role.Grant(viewPermissions);
        await db.Roles.AddAsync(role);

        var hash = await db.Users
            .Where(u => u.TenantId == tenantId)
            .Select(u => u.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, email, hash, "Dashboard Viewer", phone: null);
        user.AssignRole(role);
        user.MarkEmailVerified();
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "accessToken");
    }

    private void Authorize(string token) => _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    private async Task<Guid> GetDefaultBranchIdAsync(Guid tenantId)
    {
        using var db = CreateDbContext();
        return await db.Branches
            .Where(b => b.TenantId == tenantId)
            .Select(b => b.Id)
            .FirstAsync();
    }

    private async Task<string> CreateUnitAsync(string token, string name)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/units", new { name, abbreviation = name[..3] });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private async Task<string> CreateProductAsync(
        string token, string name, string unitId, string? sku = null, int status = 1, int productType = 0)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name,
            sku = sku ?? $"SKU-{Guid.NewGuid():N}",
            unitOfMeasureId = unitId,
            productType,
            status,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private async Task<Guid> CreateWarehouseAsync(string token, Guid branchId, string code)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/warehouses", new
        {
            name = $"Warehouse {code}",
            code,
            branchId,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return Guid.Parse(GetProperty(Body(await response.Content.ReadAsStringAsync()), "id"));
    }

    private async Task RecordOpeningStockAsync(
        string token, Guid warehouseId, string productId, string unitId, decimal quantity, Guid? variantId = null)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId,
            variantId,
            unitOfMeasureId = unitId,
            quantity,
            effectiveAt = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private async Task<string> CreatePriceListAsync(string token, string name)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name,
            currency = "TZS",
            isDefault = true,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private async Task SetPricesAsync(
        string token, string priceListId, string productId, Guid? branchId = null, Guid? variantId = null)
    {
        Authorize(token);
        var response = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new object[]
            {
                new { productId, variantId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m },
                new { productId, variantId, priceType = 0, price = 90m, currency = "TZS", minQuantity = 1m, branchId },
            },
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Summary_KpisReflectSeededTenant()
    {
        var (token, tenantId) = await RegisterAsync("dashsummary");
        var tenantGuid = Guid.Parse(tenantId);
        var branchId = await GetDefaultBranchIdAsync(tenantGuid);
        var unitId = await CreateUnitAsync(token, "Bottles");

        Authorize(token);
        var activeProduct = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Active Product",
            unitOfMeasureId = unitId,
            productType = 0,
            status = 1,
        });
        var productId = GetProperty(Body(await activeProduct.Content.ReadAsStringAsync()), "id");
        await CreateProductAsync(token, "Draft Product", unitId, status: 0);
        await CreateProductAsync(token, "Inactive Product", unitId, status: 2);
        await CreateProductAsync(token, "Service Product", unitId, productType: 1);

        Authorize(token);
        var setVariants = await _client.PutAsJsonAsync($"/api/v1/products/{productId}/variants", new
        {
            variants = new[] { new { id = (string?)null, name = "Small", sku = $"DV-{Guid.NewGuid():N}" } },
        });
        Assert.Equal(HttpStatusCode.OK, setVariants.StatusCode);

        var warehouseId = await CreateWarehouseAsync(token, branchId, "MAIN");

        Guid? variantId;
        using (var db = CreateDbContext())
        {
            variantId = await db.ProductVariants
                .Where(v => v.ProductId == Guid.Parse(productId))
                .Select(v => (Guid?)v.Id)
                .SingleAsync();
        }

        await RecordOpeningStockAsync(token, warehouseId, productId, unitId, 10, variantId);

        var priceListId = await CreatePriceListAsync(token, "Default");
        await SetPricesAsync(token, priceListId, productId, branchId, variantId);

        using (var db = CreateDbContext())
        {
            var priceList = await db.PriceLists.SingleAsync(pl => pl.Id == Guid.Parse(priceListId));
            var draftProductId = await db.Products
                .Where(p => p.TenantId == tenantGuid && p.Name == "Draft Product")
                .Select(p => p.Id)
                .SingleAsync();
            db.ProductPrices.Add(ProductPrice.Assign(
                tenantGuid, priceList.Id, Guid.NewGuid(), draftProductId, variantId: null, branchId: null,
                BusinessOS.Domain.Pricing.PriceType.Retail, 50m, "TZS", 1m, null, null, isActive: false));
            await db.SaveChangesAsync();
        }

        Authorize(token);
        var response = await _client.GetAsync("/api/v1/dashboard/summary");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var summary = Body(await response.Content.ReadAsStringAsync());

        Assert.Equal("4", GetProperty(summary, "catalog", "totalProducts"));
        Assert.Equal("2", GetProperty(summary, "catalog", "activeProducts"));
        Assert.Equal("1", GetProperty(summary, "catalog", "draftProducts"));
        Assert.Equal("1", GetProperty(summary, "catalog", "inactiveProducts"));
        Assert.Equal("1", GetProperty(summary, "catalog", "serviceProducts"));
        Assert.Equal("1", GetProperty(summary, "catalog", "totalVariants"));
        Assert.Equal("0", GetProperty(summary, "catalog", "totalCategories"));

        Assert.Equal("1", GetProperty(summary, "inventory", "totalWarehouses"));
        Assert.Equal("1", GetProperty(summary, "inventory", "totalStockLines"));
        Assert.Equal(10m, decimal.Parse(GetProperty(summary, "inventory", "totalOnHandUnits")));
        Assert.Equal("1", GetProperty(summary, "inventory", "stockedProducts"));
        Assert.Equal("0", GetProperty(summary, "inventory", "zeroStockLines"));
        Assert.Equal("1", GetProperty(summary, "inventory", "totalMovements"));

        Assert.Equal("1", GetProperty(summary, "pricing", "totalPriceLists"));
        Assert.Equal("Default", GetProperty(summary, "pricing", "defaultPriceListName"));
        Assert.Equal("1", GetProperty(summary, "pricing", "activePriceProducts"));
        Assert.Equal("1", GetProperty(summary, "pricing", "branchOverrideProducts"));

        Assert.Equal("1", GetProperty(summary, "organization", "totalBranches"));
        Assert.Equal("1", GetProperty(summary, "organization", "totalUsers"));
        Assert.Equal("1", GetProperty(summary, "organization", "activeUsers"));
        Assert.True(int.Parse(GetProperty(summary, "organization", "totalRoles")) >= 1);
    }

    [Fact]
    public async Task LowStock_OrdersByOnHandAndHonorsThreshold_AndValidates()
    {
        var (token, tenantId) = await RegisterAsync("dashlow");
        var tenantGuid = Guid.Parse(tenantId);
        var branchId = await GetDefaultBranchIdAsync(tenantGuid);
        var unitId = await CreateUnitAsync(token, "Bottles");
        var lowId = await CreateProductAsync(token, "Low Stock", unitId);
        var highId = await CreateProductAsync(token, "High Stock", unitId);
        var zeroId = await CreateProductAsync(token, "Zero Stock", unitId);
        var warehouseId = await CreateWarehouseAsync(token, branchId, "MAIN");
        await RecordOpeningStockAsync(token, warehouseId, lowId, unitId, 10);
        await RecordOpeningStockAsync(token, warehouseId, highId, unitId, 100);

        using (var db = CreateDbContext())
        {
            var locationId = await db.StockLocations
                .Where(l => l.WarehouseId == warehouseId)
                .Select(l => l.Id)
                .FirstAsync();
            db.StockBalances.Add(StockBalance.Create(
                tenantGuid, warehouseId, locationId, Guid.Parse(zeroId), variantId: null));
            await db.SaveChangesAsync();
        }

        Authorize(token);

        var zeroOnly = await _client.GetAsync("/api/v1/dashboard/low-stock");
        Assert.Equal(HttpStatusCode.OK, zeroOnly.StatusCode);
        var zeroDoc = Body(await zeroOnly.Content.ReadAsStringAsync());
        Assert.Equal(1, zeroDoc.GetProperty("items").GetArrayLength());
        Assert.Equal("Zero Stock", GetProperty(zeroDoc, "items", "0", "productName"));
        Assert.Equal(0m, decimal.Parse(GetProperty(zeroDoc, "items", "0", "onHand")));

        var upToFifty = await _client.GetAsync("/api/v1/dashboard/low-stock?maxQuantity=50");
        Assert.Equal(HttpStatusCode.OK, upToFifty.StatusCode);
        var fiftyDoc = Body(await upToFifty.Content.ReadAsStringAsync());
        Assert.Equal(2, fiftyDoc.GetProperty("items").GetArrayLength());
        Assert.Equal("Zero Stock", GetProperty(fiftyDoc, "items", "0", "productName"));
        Assert.Equal("Low Stock", GetProperty(fiftyDoc, "items", "1", "productName"));
        Assert.Equal(10m, decimal.Parse(GetProperty(fiftyDoc, "items", "1", "onHand")));

        var upToHundred = await _client.GetAsync("/api/v1/dashboard/low-stock?maxQuantity=100");
        Assert.Equal(HttpStatusCode.OK, upToHundred.StatusCode);
        Assert.Equal(3, Body(await upToHundred.Content.ReadAsStringAsync()).GetProperty("items").GetArrayLength());

        var limited = await _client.GetAsync("/api/v1/dashboard/low-stock?maxQuantity=50&limit=1");
        Assert.Equal(HttpStatusCode.OK, limited.StatusCode);
        Assert.Equal(1, Body(await limited.Content.ReadAsStringAsync()).GetProperty("items").GetArrayLength());

        var negativeThreshold = await _client.GetAsync("/api/v1/dashboard/low-stock?maxQuantity=-1");
        Assert.Equal(HttpStatusCode.BadRequest, negativeThreshold.StatusCode);

        var badLimit = await _client.GetAsync("/api/v1/dashboard/low-stock?limit=0");
        Assert.Equal(HttpStatusCode.BadRequest, badLimit.StatusCode);
    }

    [Fact]
    public async Task RecentActivity_NewestFirst_WithActorEmail()
    {
        var (token, _) = await RegisterAsync("dashactivity");
        var unitId = await CreateUnitAsync(token, "Bottles");
        await CreateProductAsync(token, "Activity Product", unitId);

        Authorize(token);

        // Product creation is the newest meaningful action for the tenant; it is
        // audited by AuditBehavior (entity type "Command") with the actor's email.
        var response = await _client.GetAsync("/api/v1/dashboard/recent-activity?limit=10");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var items = Body(await response.Content.ReadAsStringAsync()).GetProperty("items");
        Assert.True(items.GetArrayLength() >= 2);

        Assert.Equal("CreateProductCommand", GetProperty(items, "0", "action"));
        Assert.Equal("Command", GetProperty(items, "0", "entityType"));
        Assert.True(!string.IsNullOrWhiteSpace(GetProperty(items, "0", "actorEmail")));
    }

    [Fact]
    public async Task DashboardReads_RequireDashboardViewPermission()
    {
        var (_, tenantId) = await RegisterAsync("dashviewer");
        var viewerToken = await RegisterLimitedViewerAsync(
            $"dsv-{Guid.NewGuid():N}@test.local",
            Guid.Parse(tenantId),
            new[] { PermissionNames.ProductsView });

        Authorize(viewerToken);
        var summary = await _client.GetAsync("/api/v1/dashboard/summary");
        Assert.Equal(HttpStatusCode.Forbidden, summary.StatusCode);

        var lowStock = await _client.GetAsync("/api/v1/dashboard/low-stock");
        Assert.Equal(HttpStatusCode.Forbidden, lowStock.StatusCode);

        var activity = await _client.GetAsync("/api/v1/dashboard/recent-activity");
        Assert.Equal(HttpStatusCode.Forbidden, activity.StatusCode);
    }

    [Fact]
    public async Task TenantIsolation_SummaryAndLowStockDoNotLeak()
    {
        var (tokenA, tenantIdA) = await RegisterAsync("dashA");
        var branchIdA = await GetDefaultBranchIdAsync(Guid.Parse(tenantIdA));
        var unitIdA = await CreateUnitAsync(tokenA, "Bottles");
        var productA = await CreateProductAsync(tokenA, "Secret Product", unitIdA);
        var warehouseA = await CreateWarehouseAsync(tokenA, branchIdA, "MAIN");
        await RecordOpeningStockAsync(tokenA, warehouseA, productA, unitIdA, 25);
        var priceListA = await CreatePriceListAsync(tokenA, "Default");
        await SetPricesAsync(tokenA, priceListA, productA, branchIdA);

        var (tokenB, tenantIdB) = await RegisterAsync("dashB");
        Authorize(tokenB);

        var summary = await _client.GetAsync("/api/v1/dashboard/summary");
        Assert.Equal(HttpStatusCode.OK, summary.StatusCode);
        var doc = Body(await summary.Content.ReadAsStringAsync());
        Assert.Equal("0", GetProperty(doc, "catalog", "totalProducts"));
        Assert.Equal(0m, decimal.Parse(GetProperty(doc, "inventory", "totalOnHandUnits")));
        Assert.Equal("0", GetProperty(doc, "pricing", "totalPriceLists"));
        Assert.Equal("1", GetProperty(doc, "organization", "totalBranches"));
        Assert.Equal("1", GetProperty(doc, "organization", "totalUsers"));

        var lowStock = await _client.GetAsync("/api/v1/dashboard/low-stock?maxQuantity=100");
        Assert.Equal(HttpStatusCode.OK, lowStock.StatusCode);
        Assert.Equal(0, Body(await lowStock.Content.ReadAsStringAsync()).GetProperty("items").GetArrayLength());

        var activity = await _client.GetAsync("/api/v1/dashboard/recent-activity?limit=50");
        Assert.Equal(HttpStatusCode.OK, activity.StatusCode);
        var items = Body(await activity.Content.ReadAsStringAsync()).GetProperty("items");
        for (var i = 0; i < items.GetArrayLength(); i++)
        {
            Assert.NotEqual("CreateProductCommand", GetProperty(items, i.ToString(), "action"));
        }
    }

    [Fact]
    public async Task DashboardReads_WriteNoAuditRows()
    {
        var (token, tenantId) = await RegisterAsync("dashaudit");
        var tenantGuid = Guid.Parse(tenantId);
        await CreateUnitAsync(token, "Bottles");

        int CountAuditRows()
        {
            using var db = CreateDbContext();
            return db.AuditLogs.Count(l => l.TenantId == tenantGuid);
        }

        var before = CountAuditRows();
        Assert.True(before >= 1);

        Authorize(token);
        await _client.GetAsync("/api/v1/dashboard/summary");
        await _client.GetAsync("/api/v1/dashboard/low-stock");
        await _client.GetAsync("/api/v1/dashboard/recent-activity");

        Assert.Equal(before, CountAuditRows());
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}

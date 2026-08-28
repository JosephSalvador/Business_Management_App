using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class InventoryEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public InventoryEndpointsTests(BusinessOsApiFactory factory)
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
            current = current.GetProperty(part);
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
        var user = User.Create(Guid.NewGuid(), tenantId, email, hash, "Inventory Viewer", phone: null);
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

    private async Task<string> CreateProductAsync(string token, string name, string unitId, string? sku = null)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name,
            sku = sku ?? $"SKU-{Guid.NewGuid():N}",
            unitOfMeasureId = unitId,
            productType = 0,
            status = 1,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private async Task<string> CreateWarehouseAsync(string token, Guid tenantId, string code)
    {
        var branchId = await GetDefaultBranchIdAsync(tenantId);
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/warehouses", new
        {
            name = $"{code} Store",
            code,
            branchId,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private async Task RecordOpeningAsync(
        string token, string warehouseId, string productId, string unitId, decimal quantity)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId,
            quantity,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task WarehouseCrud_StatusLocations_AndDuplicateCodeConflict()
    {
        var (token, tenantId) = await RegisterAsync("whcrud");
        var branchId = await GetDefaultBranchIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var code = $"WH-{Guid.NewGuid():N}";
        var created = await _client.PostAsJsonAsync("/api/v1/warehouses", new
        {
            name = " Main Store ",
            code,
            branchId,
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Main Store", GetProperty(createdDoc, "name"));
        Assert.Equal(code.ToUpperInvariant(), GetProperty(createdDoc, "code"));
        var warehouseId = GetProperty(createdDoc, "id");

        var locations = createdDoc.GetProperty("locations");
        var location = Assert.Single(locations.EnumerateArray());
        Assert.Equal("MAIN", location.GetProperty("code").ToString());
        Assert.Equal("Main", location.GetProperty("name").ToString());

        var duplicate = await _client.PostAsJsonAsync("/api/v1/warehouses", new
        {
            name = "Clone",
            code,
            branchId,
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);

        var fetched = await _client.GetAsync($"/api/v1/warehouses/{warehouseId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal(branchId.ToString(), GetProperty(Body(await fetched.Content.ReadAsStringAsync()), "branchId"));

        var updated = await _client.PutAsJsonAsync($"/api/v1/warehouses/{warehouseId}", new
        {
            name = "Main Store 2",
            description = "Downtown",
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal("Main Store 2", GetProperty(Body(await updated.Content.ReadAsStringAsync()), "name"));

        var locationsUpdated = await _client.PutAsJsonAsync($"/api/v1/warehouses/{warehouseId}/locations", new
        {
            locations = new[]
            {
                new { id = (string?)null, code = "A", name = "Zone A" },
                new { id = (string?)null, code = "B", name = "Zone B" },
            },
        });
        Assert.Equal(HttpStatusCode.OK, locationsUpdated.StatusCode);
        Assert.Equal(2, Body(await locationsUpdated.Content.ReadAsStringAsync()).GetArrayLength());

        var deactivated = await _client.PatchAsJsonAsync($"/api/v1/warehouses/{warehouseId}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.OK, deactivated.StatusCode);
        Assert.Equal("False", GetProperty(Body(await deactivated.Content.ReadAsStringAsync()), "isActive"));

        var deleted = await _client.DeleteAsync($"/api/v1/warehouses/{warehouseId}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var afterDelete = await _client.GetAsync($"/api/v1/warehouses/{warehouseId}");
        Assert.Equal(HttpStatusCode.OK, afterDelete.StatusCode);
        Assert.Equal("False", GetProperty(Body(await afterDelete.Content.ReadAsStringAsync()), "isActive"));

        var listed = await _client.GetAsync("/api/v1/warehouses?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
    }

    [Fact]
    public async Task OpeningStock_RecordsBalanceAndMovement_AndDuplicateOpeningConflicts()
    {
        var (token, tenantId) = await RegisterAsync("opening");
        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Opening Product", unitId);

        Authorize(token);
        await RecordOpeningAsync(token, warehouseId, productId, unitId, quantity: 20m);

        var balances = await _client.GetAsync($"/api/v1/inventory/stock?page=1&pageSize=10&warehouseId={warehouseId}");
        Assert.Equal(HttpStatusCode.OK, balances.StatusCode);
        var balancesDoc = Body(await balances.Content.ReadAsStringAsync());
        Assert.Equal("1", GetProperty(balancesDoc, "total"));
        var balance = balancesDoc.GetProperty("items")[0];
        Assert.Equal("20", balance.GetProperty("quantity").ToString());
        Assert.Equal(productId, balance.GetProperty("productId").ToString());

        var movements = await _client.GetAsync($"/api/v1/inventory/movements?page=1&pageSize=10&warehouseId={warehouseId}");
        Assert.Equal(HttpStatusCode.OK, movements.StatusCode);
        var movementsDoc = Body(await movements.Content.ReadAsStringAsync());
        Assert.Equal("1", GetProperty(movementsDoc, "total"));
        var movement = movementsDoc.GetProperty("items")[0];
        Assert.Equal("0", movement.GetProperty("type").ToString());
        Assert.Equal("20", movement.GetProperty("quantityDelta").ToString());

        var duplicate = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId,
            quantity = 5m,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-02T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
    }

    [Fact]
    public async Task OpeningStock_VariantConsistencyAndValidation()
    {
        var (token, tenantId) = await RegisterAsync("openvariant");
        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        var unitId = await CreateUnitAsync(token, "Bottles");
        Authorize(token);

        var simpleProductId = await CreateProductAsync(token, "Simple Product", unitId);

        var variantProduct = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Variant Product",
            unitOfMeasureId = unitId,
            productType = 0,
            status = 1,
        });
        var variantProductId = GetProperty(Body(await variantProduct.Content.ReadAsStringAsync()), "id");
        var setVariants = await _client.PutAsJsonAsync($"/api/v1/products/{variantProductId}/variants", new
        {
            variants = new[] { new { id = (string?)null, name = "Small", sku = $"VS-{Guid.NewGuid():N}" } },
        });
        Assert.Equal(HttpStatusCode.OK, setVariants.StatusCode);
        var fetchedVariants = await _client.GetAsync($"/api/v1/products/{variantProductId}/variants");
        var variantId = Body(await fetchedVariants.Content.ReadAsStringAsync())[0].GetProperty("id").ToString();

        var missingVariant = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId = variantProductId,
            quantity = 10m,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.BadRequest, missingVariant.StatusCode);

        var wrongVariant = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId = variantProductId,
            variantId = Guid.NewGuid(),
            quantity = 10m,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.BadRequest, wrongVariant.StatusCode);

        var simpleWithVariant = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId = simpleProductId,
            variantId = Guid.NewGuid(),
            quantity = 10m,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.BadRequest, simpleWithVariant.StatusCode);

        var withVariant = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId = variantProductId,
            variantId,
            quantity = 10m,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.OK, withVariant.StatusCode);
        Assert.Equal(variantId, GetProperty(Body(await withVariant.Content.ReadAsStringAsync()), "variantId"));

        var negativeQuantity = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId = simpleProductId,
            quantity = -1m,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.BadRequest, negativeQuantity.StatusCode);
    }

    [Fact]
    public async Task TenantIsolation_OtherTenantCannotReadWarehouseOrStock()
    {
        var (tokenA, tenantIdA) = await RegisterAsync("tenantA-inv");
        var warehouseId = await CreateWarehouseAsync(tokenA, Guid.Parse(tenantIdA), $"WH-{Guid.NewGuid():N}");
        var unitId = await CreateUnitAsync(tokenA, "Bottles");
        var productId = await CreateProductAsync(tokenA, "Secret Stock", unitId);
        await RecordOpeningAsync(tokenA, warehouseId, productId, unitId, quantity: 7m);

        var (tokenB, _) = await RegisterAsync("tenantB-inv");
        Authorize(tokenB);

        var read = await _client.GetAsync($"/api/v1/warehouses/{warehouseId}");
        Assert.Equal(HttpStatusCode.NotFound, read.StatusCode);

        var update = await _client.PutAsJsonAsync($"/api/v1/warehouses/{warehouseId}", new { name = "Hijacked" });
        Assert.Equal(HttpStatusCode.NotFound, update.StatusCode);

        var opening = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId,
            productId,
            quantity = 1m,
            unitOfMeasureId = unitId,
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.NotFound, opening.StatusCode);

        var stock = await _client.GetAsync($"/api/v1/inventory/stock?page=1&pageSize=10&warehouseId={warehouseId}");
        Assert.Equal(HttpStatusCode.OK, stock.StatusCode);
        Assert.Equal("0", GetProperty(Body(await stock.Content.ReadAsStringAsync()), "total"));
    }

    [Fact]
    public async Task LimitedViewer_CanReadButCannotMutateInventory()
    {
        var (_, tenantId) = await RegisterAsync("inventoryviewer");
        var viewerToken = await RegisterLimitedViewerAsync(
            $"inv-{Guid.NewGuid():N}@test.local",
            Guid.Parse(tenantId),
            new[] { PermissionNames.WarehousesView, PermissionNames.InventoryView });

        Authorize(viewerToken);
        var read = await _client.GetAsync("/api/v1/warehouses?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, read.StatusCode);

        var readStock = await _client.GetAsync("/api/v1/inventory/stock?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, readStock.StatusCode);

        var create = await _client.PostAsJsonAsync("/api/v1/warehouses", new
        {
            name = "Blocked",
            code = $"WH-{Guid.NewGuid():N}",
            branchId = Guid.NewGuid(),
        });
        Assert.Equal(HttpStatusCode.Forbidden, create.StatusCode);

        var opening = await _client.PostAsJsonAsync("/api/v1/inventory/stock/opening", new
        {
            warehouseId = Guid.NewGuid(),
            productId = Guid.NewGuid(),
            quantity = 1m,
            unitOfMeasureId = Guid.NewGuid(),
            effectiveAt = "2026-08-01T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.Forbidden, opening.StatusCode);
    }

    [Fact]
    public async Task InventoryMutations_WriteAuditRows()
    {
        var (token, tenantId) = await RegisterAsync("inventoryaudit");
        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Audited Stock", unitId);
        await RecordOpeningAsync(token, warehouseId, productId, unitId, quantity: 5m);

        using var db = CreateDbContext();
        foreach (var action in new[] { "CreateWarehouseCommand", "RecordOpeningStockCommand" })
        {
            Assert.NotNull(await db.AuditLogs.FirstOrDefaultAsync(l => l.Action == action));
        }
    }

    [Fact]
    public async Task OpeningStock_PersistsAndDispatchesOutboxEvents()
    {
        var (token, tenantId) = await RegisterAsync("inventoryoutbox");
        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Outbox Stock", unitId);
        await RecordOpeningAsync(token, warehouseId, productId, unitId, quantity: 3m);

        using var db = CreateDbContext();
        foreach (var type in new[]
        {
            "BusinessOS.Domain.Events.OpeningStockRecordedEvent",
            "BusinessOS.Domain.Events.StockMovementRecordedEvent",
        })
        {
            var outbox = await db.OutboxMessages
                .Where(o => o.Type == type)
                .OrderByDescending(o => o.OccurredAt)
                .FirstOrDefaultAsync();
            Assert.NotNull(outbox);
            Assert.NotNull(outbox.ProcessedAt);
        }
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}

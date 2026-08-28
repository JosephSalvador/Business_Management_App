using System.Net;
using System.Net.Http.Json;
using BusinessOS.Domain.Inventory;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// Sub-slice 6c-void — <c>POST /api/v1/sales/{id}/void</c> over the real API + Postgres:
/// status transition, compensating <see cref="StockMovementType.SaleVoid"/> add-back, outbox
/// event, audit row, already-voided conflict, tenant isolation, and permission enforcement.
/// </summary>
public sealed class VoidSaleTests : SalesTestBase
{
    public VoidSaleTests(BusinessOsApiFactory factory) : base(factory)
    {
    }

    private async Task<(string Token, Guid TenantId, Guid BranchId, string ProductId, string WarehouseId)>
        FixtureAsync(string label)
    {
        var (token, tenantId) = await RegisterVerifiedAsync(label);
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Fanta 500ml", unitId);
        var priceListId = await CreatePriceListAsync(token, "Default");
        await SetPriceAsync(token, priceListId, productId, 100m);

        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        await RecordOpeningAsync(token, warehouseId, productId, unitId, 5m);

        return (token, Guid.Parse(tenantId), await GetDefaultBranchIdAsync(Guid.Parse(tenantId)), productId, warehouseId);
    }

    private async Task<string> CreateSaleAsync(
        string token, Guid branchId, Guid clientSaleId, string productId, string warehouseId)
    {
        var response = await PostSaleAsync(
            token, SaleBody(branchId, clientSaleId, productId, 100m, warehouseId: warehouseId));
        Assert.True(response.StatusCode == HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    [Fact]
    public async Task VoidSale_HappyPath_FlipsStatus_RestoresStock_WritesOutboxAndAudit()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("void-happy");
        var saleId = await CreateSaleAsync(token, branchId, Guid.NewGuid(), productId, warehouseId);

        using (var db = CreateDbContext())
        {
            Assert.Equal(4m, (await db.StockBalances.Where(b => b.TenantId == tenantId).SingleAsync()).Quantity);
        }

        Authorize(token);
        var voided = await _client.PostAsJsonAsync($"/api/v1/sales/{saleId}/void", new { reason = "Wrong item rung up" });
        Assert.True(voided.StatusCode == HttpStatusCode.OK, $"{voided.StatusCode}: {await voided.Content.ReadAsStringAsync()}");
        var doc = Body(await voided.Content.ReadAsStringAsync());
        Assert.Equal("1", GetProperty(doc, "status"));
        Assert.Equal("Wrong item rung up", GetProperty(doc, "voidReason"));
        Assert.False(GetProperty(doc, "voidedAt").Length == 0);
        Assert.False(GetProperty(doc, "voidedBy").Length == 0);

        var fetched = await _client.GetAsync($"/api/v1/sales/{saleId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal("1", GetProperty(Body(await fetched.Content.ReadAsStringAsync()), "status"));

        using (var db = CreateDbContext())
        {
            Assert.Equal(5m, (await db.StockBalances.Where(b => b.TenantId == tenantId).SingleAsync()).Quantity);

            var reversal = await db.StockMovements
                .Where(m => m.TenantId == tenantId && m.MovementType == StockMovementType.SaleVoid)
                .SingleAsync();
            Assert.Equal(1m, reversal.Quantity);
            Assert.Equal("Sale", reversal.ReferenceType);
            Assert.Equal(Guid.Parse(saleId), reversal.ReferenceId);

            Assert.True(await db.AuditLogs.AnyAsync(l => l.TenantId == tenantId && l.Action == "VoidSaleCommand"));

            var outbox = await db.OutboxMessages
                .Where(o => o.TenantId == tenantId && o.Type == "BusinessOS.Domain.Events.SaleVoidedEvent")
                .SingleAsync();
            Assert.NotNull(outbox.ProcessedAt);
        }
    }

    [Fact]
    public async Task VoidSale_ServiceOnlySale_RestoresNoStock_ButVoids()
    {
        var (token, tenantIdString) = await RegisterVerifiedAsync("void-service");
        var tenantId = Guid.Parse(tenantIdString);
        var unitId = await CreateUnitAsync(token, "Hours");
        var serviceId = await CreateProductAsync(token, "Repair", unitId, productType: 1);
        var priceListId = await CreatePriceListAsync(token, "Default");
        await SetPriceAsync(token, priceListId, serviceId, 50m);
        var warehouseId = await CreateWarehouseAsync(token, tenantId, $"WH-{Guid.NewGuid():N}");
        var branchId = await GetDefaultBranchIdAsync(tenantId);

        var serviceSale = await PostSaleAsync(token, SaleBody(branchId, Guid.NewGuid(), serviceId, 50m, warehouseId: warehouseId));
        Assert.True(serviceSale.StatusCode == HttpStatusCode.OK, $"{serviceSale.StatusCode}: {await serviceSale.Content.ReadAsStringAsync()}");
        var saleId = GetProperty(Body(await serviceSale.Content.ReadAsStringAsync()), "id");

        Authorize(token);
        var voided = await _client.PostAsJsonAsync($"/api/v1/sales/{saleId}/void", new { reason = "Customer cancelled" });
        Assert.True(voided.StatusCode == HttpStatusCode.OK, $"{voided.StatusCode}: {await voided.Content.ReadAsStringAsync()}");
        Assert.Equal("1", GetProperty(Body(await voided.Content.ReadAsStringAsync()), "status"));

        using var db = CreateDbContext();
        Assert.Equal(0, await db.StockBalances.CountAsync(b => b.TenantId == tenantId));
        Assert.Equal(0, await db.StockMovements.CountAsync(m => m.TenantId == tenantId));
    }

    [Fact]
    public async Task VoidSale_AlreadyVoided_ReturnsConflict_AndNoDoubleRestore()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("void-twice");
        var saleId = await CreateSaleAsync(token, branchId, Guid.NewGuid(), productId, warehouseId);

        Authorize(token);
        var first = await _client.PostAsJsonAsync($"/api/v1/sales/{saleId}/void", new { reason = "First" });
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);

        var second = await _client.PostAsJsonAsync($"/api/v1/sales/{saleId}/void", new { reason = "Second" });
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
        Assert.Equal("Conflict", GetProperty(Body(await second.Content.ReadAsStringAsync()), "code"));

        using var db = CreateDbContext();
        Assert.Equal(1, await db.StockMovements.CountAsync(
            m => m.TenantId == tenantId && m.MovementType == StockMovementType.SaleVoid));
        Assert.Equal(5m, (await db.StockBalances.Where(b => b.TenantId == tenantId).SingleAsync()).Quantity);
    }

    [Fact]
    public async Task VoidSale_UnknownSale_ReturnsNotFound()
    {
        var (token, _, _, _, _) = await FixtureAsync("void-unknown");

        Authorize(token);
        var response = await _client.PostAsJsonAsync($"/api/v1/sales/{Guid.NewGuid()}/void", new { reason = "Reason" });
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("NotFound", GetProperty(Body(await response.Content.ReadAsStringAsync()), "code"));
    }

    [Fact]
    public async Task VoidSale_BlankReason_ReturnsValidation()
    {
        var (token, _, branchId, productId, warehouseId) = await FixtureAsync("void-blank");
        var saleId = await CreateSaleAsync(token, branchId, Guid.NewGuid(), productId, warehouseId);

        Authorize(token);
        var response = await _client.PostAsJsonAsync($"/api/v1/sales/{saleId}/void", new { reason = " " });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Validation", GetProperty(Body(await response.Content.ReadAsStringAsync()), "code"));
    }

    [Fact]
    public async Task VoidSale_ViewOnlyRole_IsForbidden()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("void-viewer");
        var saleId = await CreateSaleAsync(token, branchId, Guid.NewGuid(), productId, warehouseId);
        var viewerToken = await RegisterViewerAsync($"viewer-{Guid.NewGuid():N}@test.local", tenantId);

        Authorize(viewerToken);
        var response = await _client.PostAsJsonAsync($"/api/v1/sales/{saleId}/void", new { reason = "Reason" });
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task VoidSale_IsTenantScoped()
    {
        var (tokenA, _, branchA, productA, warehouseA) = await FixtureAsync("void-iso-a");
        var saleId = await CreateSaleAsync(tokenA, branchA, Guid.NewGuid(), productA, warehouseA);
        var (tokenB, _, _, _, _) = await FixtureAsync("void-iso-b");

        Authorize(tokenB);
        var response = await _client.PostAsJsonAsync($"/api/v1/sales/{saleId}/void", new { reason = "Reason" });
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("NotFound", GetProperty(Body(await response.Content.ReadAsStringAsync()), "code"));
    }
}

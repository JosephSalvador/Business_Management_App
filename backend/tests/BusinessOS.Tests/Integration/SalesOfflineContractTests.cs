using System.Net;
using System.Text.Json;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// Task 014 — offline contract. The offline POS flushes sales later over an unreliable link,
/// so the server must be idempotent on <c>ClientSaleId</c> (and the <c>Idempotency-Key</c>
/// header): a replay returns the original sale with no double stock, numbering, or event work.
/// </summary>
public sealed class SalesOfflineContractTests : SalesTestBase
{
    public SalesOfflineContractTests(BusinessOsApiFactory factory) : base(factory)
    {
    }

    private async Task<(string Token, Guid TenantId, Guid BranchId, string ProductId, string WarehouseId)>
        FixtureAsync(string label, decimal opening = 5m, decimal price = 100m)
    {
        var (token, tenantId) = await RegisterVerifiedAsync(label);
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Fanta 500ml", unitId);
        var priceListId = await CreatePriceListAsync(token, "Default");
        await SetPriceAsync(token, priceListId, productId, price);
        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        await RecordOpeningAsync(token, warehouseId, productId, unitId, opening);
        return (token, Guid.Parse(tenantId), await GetDefaultBranchIdAsync(Guid.Parse(tenantId)), productId, warehouseId);
    }

    [Fact]
    public async Task Replay_SameClientSaleId_ReturnsOriginalWithNoDoubleStockNumberOrEvent()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-replay");
        var clientSaleId = Guid.NewGuid();
        var body = SaleBody(branchId, clientSaleId, productId, 100m, warehouseId: warehouseId);

        var first = await PostSaleAsync(token, body);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var firstDoc = Body(await first.Content.ReadAsStringAsync());
        var saleId = GetProperty(firstDoc, "id");
        var number = GetProperty(firstDoc, "number");
        Assert.Equal(clientSaleId.ToString(), GetProperty(firstDoc, "clientSaleId"));

        var replay = await PostSaleAsync(token, body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        var replayDoc = Body(await replay.Content.ReadAsStringAsync());
        Assert.Equal(saleId, GetProperty(replayDoc, "id"));
        Assert.Equal(number, GetProperty(replayDoc, "number"));

        using var db = CreateDbContext();
        Assert.Equal(1, await db.Sales.CountAsync(s => s.TenantId == tenantId));
        var saleIds = db.Sales.Where(s => s.TenantId == tenantId).Select(s => s.Id);
        Assert.Equal(1, await db.SaleLines.CountAsync(l => saleIds.Contains(l.SaleId)));
        var balance = await db.StockBalances
            .Where(b => b.TenantId == tenantId)
            .SingleAsync();
        Assert.Equal(4m, balance.Quantity);
        Assert.Equal(1, await db.StockMovements.CountAsync(
            m => m.TenantId == tenantId && m.MovementType == BusinessOS.Domain.Inventory.StockMovementType.Sale));
        Assert.Equal(1, await db.OutboxMessages.CountAsync(
            o => o.TenantId == tenantId && o.Type == "BusinessOS.Domain.Events.SaleCompletedEvent"));
    }

    [Fact]
    public async Task IdempotencyKeyHeader_IsAuthoritativeClientSaleId()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-header-key");
        var bodyKey = Guid.NewGuid();
        var headerKey = Guid.NewGuid();
        var body = SaleBody(branchId, bodyKey, productId, 100m, warehouseId: warehouseId);

        var first = await PostSaleAsync(token, body, idempotencyKey: headerKey.ToString());
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var firstDoc = Body(await first.Content.ReadAsStringAsync());
        var saleId = GetProperty(firstDoc, "id");
        Assert.Equal(headerKey.ToString(), GetProperty(firstDoc, "clientSaleId"));

        var replayByHeader = await PostSaleAsync(token, body, idempotencyKey: headerKey.ToString());
        Assert.Equal(HttpStatusCode.OK, replayByHeader.StatusCode);
        Assert.Equal(saleId, GetProperty(Body(await replayByHeader.Content.ReadAsStringAsync()), "id"));

        var replayByBody = await PostSaleAsync(token, body);
        Assert.Equal(HttpStatusCode.OK, replayByBody.StatusCode);
        var bodyDoc = Body(await replayByBody.Content.ReadAsStringAsync());
        Assert.NotEqual(saleId, GetProperty(bodyDoc, "id"));
        Assert.Equal(bodyKey.ToString(), GetProperty(bodyDoc, "clientSaleId"));

        using var db = CreateDbContext();
        Assert.Equal(2, await db.Sales.CountAsync(s => s.TenantId == tenantId));
        Assert.Equal(2, await db.StockMovements.CountAsync(
            m => m.TenantId == tenantId && m.MovementType == BusinessOS.Domain.Inventory.StockMovementType.Sale));
    }

    [Fact]
    public async Task DistinctClientSaleIds_ProduceDistinctSalesAndNumbers()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-distinct", opening: 10m);
        Authorize(token);

        var first = await PostSaleAsync(token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var second = await PostSaleAsync(token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);

        var firstDoc = Body(await first.Content.ReadAsStringAsync());
        var secondDoc = Body(await second.Content.ReadAsStringAsync());
        Assert.NotEqual(GetProperty(firstDoc, "id"), GetProperty(secondDoc, "id"));
        Assert.NotEqual(GetProperty(firstDoc, "number"), GetProperty(secondDoc, "number"));

        using var db = CreateDbContext();
        Assert.Equal(2, await db.Sales.CountAsync(s => s.TenantId == tenantId));
        Assert.Equal(8m, (await db.StockBalances.Where(b => b.TenantId == tenantId).SingleAsync()).Quantity);
    }

    [Fact]
    public async Task ClientSaleId_IsUniquePerTenant_ButNotAcrossTenants()
    {
        var (tokenA, tenantA, branchA, productA, warehouseA) = await FixtureAsync("sale-key-a");
        var (tokenB, tenantB, branchB, productB, warehouseB) = await FixtureAsync("sale-key-b");
        var sharedKey = Guid.NewGuid();

        var inA = await PostSaleAsync(tokenA, SaleBody(branchA, sharedKey, productA, 100m, warehouseId: warehouseA));
        Assert.Equal(HttpStatusCode.OK, inA.StatusCode);
        var inB = await PostSaleAsync(tokenB, SaleBody(branchB, sharedKey, productB, 100m, warehouseId: warehouseB));
        Assert.Equal(HttpStatusCode.OK, inB.StatusCode);

        using var db = CreateDbContext();
        Assert.Equal(1, await db.Sales.CountAsync(s => s.TenantId == tenantA && s.ClientSaleId == sharedKey));
        Assert.Equal(1, await db.Sales.CountAsync(s => s.TenantId == tenantB && s.ClientSaleId == sharedKey));
    }
}

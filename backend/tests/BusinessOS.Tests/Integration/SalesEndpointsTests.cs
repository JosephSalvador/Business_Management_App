using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Text.RegularExpressions;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// Task 015 — the sale integration suite over the real API + Postgres: happy path (stock down,
/// number issued, audit row, outbox event), no-price, insufficient stock with full rollback,
/// dual-VAT A/B and zero-rated carts, split cash + mobile money reconciliation, service lines
/// skipping stock, tenant isolation, permission enforcement, and the paged list filters.
/// </summary>
public sealed class SalesEndpointsTests : SalesTestBase
{
    public SalesEndpointsTests(BusinessOsApiFactory factory) : base(factory)
    {
    }

    private async Task<(string Token, Guid TenantId, Guid BranchId, string ProductId, string WarehouseId)>
        FixtureAsync(string label, decimal opening = 5m, decimal price = 100m, int productType = 0, Guid? taxCategoryId = null, bool setPrice = true)
    {
        var (token, tenantId) = await RegisterVerifiedAsync(label);
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Fanta 500ml", unitId, taxCategoryId, productType);
        var priceListId = await CreatePriceListAsync(token, "Default");
        if (setPrice)
        {
            await SetPriceAsync(token, priceListId, productId, price);
        }

        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        if (opening > 0m)
        {
            await RecordOpeningAsync(token, warehouseId, productId, unitId, opening);
        }

        return (token, Guid.Parse(tenantId), await GetDefaultBranchIdAsync(Guid.Parse(tenantId)), productId, warehouseId);
    }

    [Fact]
    public async Task CreateSale_HappyPath_DebitsStock_IssuesNumber_WritesAuditAndOutbox()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-happy");

        var response = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.True(response.StatusCode == HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Matches(new Regex(@"^S-\d{4}-\d{6}$"), GetProperty(doc, "number"));
        Assert.Equal("0", GetProperty(doc, "status"));
        Assert.Equal("0", GetProperty(doc, "source"));
        Assert.Equal(100.00m, decimal.Parse(GetProperty(doc, "subtotal"), CultureInfo.InvariantCulture));
        Assert.Equal(15.25m, decimal.Parse(GetProperty(doc, "taxAmount"), CultureInfo.InvariantCulture));
        Assert.Equal(100.00m, decimal.Parse(GetProperty(doc, "totalAmount"), CultureInfo.InvariantCulture));
        var line = Assert.Single(doc.GetProperty("lines").EnumerateArray());
        Assert.Equal("A", GetProperty(line, "taxCode"));
        Assert.Equal(0.18m, decimal.Parse(GetProperty(line, "appliedRate"), CultureInfo.InvariantCulture));
        Assert.Equal(84.75m, decimal.Parse(GetProperty(line, "baseAmount"), CultureInfo.InvariantCulture));
        Assert.Equal("Walk-in", GetProperty(doc, "customer", "name"));
        var saleId = GetProperty(doc, "id");

        var fetched = await _client.GetAsync($"/api/v1/sales/{saleId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal(GetProperty(doc, "number"), GetProperty(Body(await fetched.Content.ReadAsStringAsync()), "number"));

        using var db = CreateDbContext();
        Assert.Equal(4m, (await db.StockBalances.Where(b => b.TenantId == tenantId).SingleAsync()).Quantity);
        var movement = await db.StockMovements
            .Where(m => m.TenantId == tenantId && m.MovementType == BusinessOS.Domain.Inventory.StockMovementType.Sale)
            .SingleAsync();
        Assert.Equal(BusinessOS.Domain.Inventory.StockMovementType.Sale, movement.MovementType);
        Assert.Equal(await db.Sales.Where(s => s.TenantId == tenantId).Select(s => s.Id).SingleAsync(), movement.ReferenceId);
        Assert.True(await db.AuditLogs.AnyAsync(l => l.TenantId == tenantId && l.Action == "CreateSaleCommand"));
        var outbox = await db.OutboxMessages
            .Where(o => o.TenantId == tenantId && o.Type == "BusinessOS.Domain.Events.SaleCompletedEvent")
            .SingleAsync();
        Assert.NotNull(outbox.ProcessedAt);
    }

    [Fact]
    public async Task CreateSale_NoPrice_ReturnsValidation()
    {
        var (token, _, branchId, productId, _) = await FixtureAsync("sale-noprice", setPrice: false);

        var response = await PostSaleAsync(token, SaleBody(branchId, Guid.NewGuid(), productId, 100m));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Validation", GetProperty(Body(await response.Content.ReadAsStringAsync()), "code"));
    }

    [Fact]
    public async Task CreateSale_QuickSaleLine_UsesClientFixedPrice_NoStockTouched()
    {
        var (token, tenantId, branchId, productId, warehouseId) =
            await FixtureAsync("quick-sale-line", opening: 0m, price: 0m, productType: 1, setPrice: false);

        var response = await PostSaleAsync(token, SaleBody(
            branchId,
            Guid.NewGuid(),
            lines:
            [
                new { productId, quantity = 1m, unitPrice = 250m },
            ],
            payments:
            [
                new { method = 0, amount = 250m, provider = (string?)null, phoneNumber = (string?)null, reference = (string?)null },
            ],
            warehouseId: warehouseId));
        Assert.True(response.StatusCode == HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Equal("250", doc.GetProperty("lines")[0].GetProperty("unitPrice").ToString());
        Assert.Equal(250m, decimal.Parse(GetProperty(doc, "subtotal"), CultureInfo.InvariantCulture));
        Assert.Equal(250m, decimal.Parse(GetProperty(doc, "totalAmount"), CultureInfo.InvariantCulture));
        Assert.Equal(250m, decimal.Parse(GetProperty(doc, "amountPaid"), CultureInfo.InvariantCulture));

        using var db = CreateDbContext();
        Assert.Equal(0, await db.StockMovements.CountAsync(m =>
            m.TenantId == tenantId && m.MovementType == BusinessOS.Domain.Inventory.StockMovementType.Sale));
    }

    private async Task<string> CreateCustomerAsync(string token, string name)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/customers", new { name });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    [Fact]
    public async Task CreateSale_CreditTenderUnderpays_PostsTheBalanceToTheCustomerLedger()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-credit");
        var customerId = await CreateCustomerAsync(token, "Credit Customer");

        var body = new
        {
            branchId,
            warehouseId,
            priceListId = (string?)null,
            clientSaleId = Guid.NewGuid(),
            source = 0,
            effectiveAt = "2026-08-15T12:00:00Z",
            isElectronicPayment = false,
            isVatRegistered = (bool?)null,
            customerId,
            customer = new { name = "Credit Customer", phone = (string?)null, tin = (string?)null },
            lines = new[] { new { productId, quantity = 1m, discountAmount = 0m } },
            payments = new[]
            {
                new { method = 4, amount = 0m, provider = (string?)null, phoneNumber = (string?)null, reference = (string?)null },
            },
        };

        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/sales", body);
        Assert.True(response.StatusCode == HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Equal(100.00m, decimal.Parse(GetProperty(doc, "totalAmount"), CultureInfo.InvariantCulture));
        Assert.Equal(0m, decimal.Parse(GetProperty(doc, "amountPaid"), CultureInfo.InvariantCulture));
        Assert.Equal(0m, decimal.Parse(GetProperty(doc, "change"), CultureInfo.InvariantCulture));
        var saleId = GetProperty(doc, "id");

        var credit = await _client.GetAsync($"/api/v1/customers/{customerId}/credit");
        Assert.Equal(HttpStatusCode.OK, credit.StatusCode);
        Assert.Equal(100m, decimal.Parse(GetProperty(Body(await credit.Content.ReadAsStringAsync()), "balance"), CultureInfo.InvariantCulture));

        var txs = await _client.GetAsync($"/api/v1/customers/{customerId}/credit/transactions?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, txs.StatusCode);
        var tx = Assert.Single(Body(await txs.Content.ReadAsStringAsync()).EnumerateArray());
        Assert.Equal("0", GetProperty(tx, "type"));
        Assert.Equal(100m, decimal.Parse(GetProperty(tx, "amount"), CultureInfo.InvariantCulture));
        Assert.Equal(saleId, GetProperty(tx, "relatedSaleId"));

        using var db = CreateDbContext();
        Assert.Equal(1, await db.CreditTransactions.CountAsync(
            t => t.TenantId == tenantId && t.CustomerId == Guid.Parse(customerId) && t.Type == BusinessOS.Domain.Crm.CreditTransactionType.Sale));
    }

    [Fact]
    public async Task CreateSale_OversellsStock_RecordsSaleWithNegativeBalance()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-oversell", opening: 1m);

        var sale = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, quantity: 2m, amountPaid: 200m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, sale.StatusCode);
        Assert.Equal("S-2026-000001", GetProperty(Body(await sale.Content.ReadAsStringAsync()), "number"));

        using (var db = CreateDbContext())
        {
            Assert.Equal(1, await db.Sales.CountAsync(s => s.TenantId == tenantId));
            Assert.Equal(1, await db.StockMovements.CountAsync(
                m => m.TenantId == tenantId && m.MovementType == BusinessOS.Domain.Inventory.StockMovementType.Sale));
            Assert.Equal(-1m, (await db.StockBalances.Where(b => b.TenantId == tenantId).SingleAsync()).Quantity);
            Assert.Equal(1, await db.OutboxMessages.CountAsync(
                o => o.TenantId == tenantId && o.Type == "BusinessOS.Domain.Events.SaleCompletedEvent"));
        }

        var next = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, next.StatusCode);
        Assert.Equal("S-2026-000002", GetProperty(Body(await next.Content.ReadAsStringAsync()), "number"));
    }

    [Fact]
    public async Task CreateSale_SplitCashAndMobileMoney_Reconciles()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-split");
        var body = SaleBody(
            branchId,
            Guid.NewGuid(),
            lines:
            [
                new { productId, quantity = 1m, discountAmount = 0m },
            ],
            payments:
            [
                new { method = 0, amount = 40m, provider = (string?)null, phoneNumber = (string?)null, reference = (string?)null },
                new { method = 1, amount = 60m, provider = "M-Pesa", phoneNumber = "0712345678", reference = "REF-1", },
            ],
            warehouseId: warehouseId);

        var response = await PostSaleAsync(token, body);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Equal(100.00m, decimal.Parse(GetProperty(doc, "totalAmount"), CultureInfo.InvariantCulture));
        Assert.Equal(100.00m, decimal.Parse(GetProperty(doc, "amountPaid"), CultureInfo.InvariantCulture));
        Assert.Equal(0m, decimal.Parse(GetProperty(doc, "change"), CultureInfo.InvariantCulture));

        var payments = doc.GetProperty("payments").EnumerateArray().ToList();
        Assert.Equal(2, payments.Count);
        Assert.Equal(0m, decimal.Parse(GetProperty(payments[0], "amount"), CultureInfo.InvariantCulture) - 40m);
        Assert.Equal("1", GetProperty(payments[1], "method"));
        Assert.Equal("M-Pesa", GetProperty(payments[1], "provider"));

        using var db = CreateDbContext();
        var saleIds = db.Sales.Where(s => s.TenantId == tenantId).Select(s => s.Id);
        Assert.Equal(2, await db.SalePayments.CountAsync(p => saleIds.Contains(p.SaleId)));
    }

    [Fact]
    public async Task CreateSale_MixedCart_StandardAndZeroRated_Aggregates()
    {
        var (token, tenantId, branchId, _, warehouseId) = await FixtureAsync("sale-mixed");
        var zeroCategoryId = await GetTaxCategoryIdAsync("VAT_ZERO");
        Assert.NotNull(zeroCategoryId);
        var unitId = await CreateUnitAsync(token, "Boxes");
        var zeroRatedProductId = await CreateProductAsync(token, "Maize Flour", unitId, zeroCategoryId);
        await RecordOpeningAsync(token, warehouseId, zeroRatedProductId, unitId, 5m);

        string standardProductId;
        using (var db = CreateDbContext())
        {
            var defaultPriceListId = await db.PriceLists
                .Where(p => p.TenantId == tenantId && p.IsDefault)
                .Select(p => p.Id.ToString())
                .SingleAsync();
            standardProductId = await db.Products
                .Where(p => p.TenantId == tenantId && p.Name == "Fanta 500ml")
                .Select(p => p.Id.ToString())
                .SingleAsync();

            Authorize(token);
            var setPrices = await _client.PutAsJsonAsync($"/api/v1/price-lists/{defaultPriceListId}/prices", new
            {
                prices = new[]
                {
                    new { productId = standardProductId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m },
                    new { productId = zeroRatedProductId, priceType = 0, price = 50m, currency = "TZS", minQuantity = 1m },
                },
            });
            Assert.Equal(HttpStatusCode.OK, setPrices.StatusCode);
        }

        var mixed = SaleBody(
            branchId,
            Guid.NewGuid(),
            lines:
            [
                new { productId = standardProductId, quantity = 1m, discountAmount = 0m },
                new { productId = zeroRatedProductId, quantity = 1m, discountAmount = 0m },
            ],
            payments: [new { method = 0, amount = 150m, provider = (string?)null, phoneNumber = (string?)null, reference = (string?)null }],
            warehouseId: warehouseId);

        var response = await PostSaleAsync(token, mixed);
        Assert.True(response.StatusCode == HttpStatusCode.OK, $"{response.StatusCode}: {await response.Content.ReadAsStringAsync()}");
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Equal(150.00m, decimal.Parse(GetProperty(doc, "subtotal"), CultureInfo.InvariantCulture));
        Assert.Equal(15.25m, decimal.Parse(GetProperty(doc, "taxAmount"), CultureInfo.InvariantCulture));
        Assert.Equal(150.00m, decimal.Parse(GetProperty(doc, "totalAmount"), CultureInfo.InvariantCulture));

        var lines = doc.GetProperty("lines").EnumerateArray().ToList();
        Assert.Equal(2, lines.Count);
        var standard = lines.Single(l => GetProperty(l, "productId") == standardProductId);
        var zeroRated = lines.Single(l => GetProperty(l, "productId") == zeroRatedProductId);
        Assert.Equal("A", GetProperty(standard, "taxCode"));
        Assert.Equal("C", GetProperty(zeroRated, "taxCode"));
        Assert.Equal(0m, decimal.Parse(GetProperty(zeroRated, "taxAmount"), CultureInfo.InvariantCulture));
    }

    [Fact]
    public async Task CreateSale_ElectronicWithoutTin_UsesRateB()
    {
        var (token, _, branchId, productId, warehouseId) = await FixtureAsync("sale-electronic-b");

        var response = await PostSaleAsync(
            token,
            SaleBody(branchId, Guid.NewGuid(), productId, 100m, isElectronicPayment: true, amountPaid: 98.31m, warehouseId: warehouseId));
        Assert.True(response.StatusCode == HttpStatusCode.OK, $"{response.StatusCode}: {await response.Content.ReadAsStringAsync()}");
        var doc = Body(await response.Content.ReadAsStringAsync());
        var line = Assert.Single(doc.GetProperty("lines").EnumerateArray());
        Assert.Equal("B", GetProperty(line, "taxCode"));
        Assert.Equal(0.16m, decimal.Parse(GetProperty(line, "appliedRate"), CultureInfo.InvariantCulture));
        Assert.Equal(98.31m, decimal.Parse(GetProperty(doc, "totalAmount"), CultureInfo.InvariantCulture));
        Assert.Equal(13.56m, decimal.Parse(GetProperty(line, "taxAmount"), CultureInfo.InvariantCulture));
    }

    [Fact]
    public async Task CreateSale_ServiceLine_SkipsStock()
    {
        var (token, tenantId, branchId, productId, _) = await FixtureAsync("sale-service", opening: 0m, productType: 1, price: 50m);

        var response = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 50m));
        Assert.True(response.StatusCode == HttpStatusCode.OK, $"{response.StatusCode}: {await response.Content.ReadAsStringAsync()}");
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Equal(50.00m, decimal.Parse(GetProperty(doc, "totalAmount"), CultureInfo.InvariantCulture));

        using var db = CreateDbContext();
        Assert.Equal(0, await db.StockBalances.CountAsync(b => b.TenantId == tenantId));
        Assert.Equal(0, await db.StockMovements.CountAsync(m => m.TenantId == tenantId));
    }

    [Fact]
    public async Task Sale_IsTenantScoped_ForReadsAndWrites()
    {
        var (tokenA, _, branchA, productA, warehouseA) = await FixtureAsync("sale-iso-a");
        var created = await PostSaleAsync(
            tokenA, SaleBody(branchA, Guid.NewGuid(), productA, 100m, warehouseId: warehouseA));
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var saleId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var (tokenB, tenantB, _, _, _) = await FixtureAsync("sale-iso-b");

        var read = await _client.GetAsync($"/api/v1/sales/{saleId}");
        Assert.Equal(HttpStatusCode.NotFound, read.StatusCode);

        var write = await PostSaleAsync(
            tokenB, SaleBody(branchA, Guid.NewGuid(), productA, 100m));
        Assert.Equal(HttpStatusCode.NotFound, write.StatusCode);
        Assert.Equal("NotFound", GetProperty(Body(await write.Content.ReadAsStringAsync()), "code"));

        using var db = CreateDbContext();
        Assert.Equal(0, await db.Sales.CountAsync(s => s.TenantId == tenantB));
    }

    [Fact]
    public async Task SalesViewOnlyRole_CanRead_ButCannotCreate()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-viewer");
        var viewerToken = await RegisterViewerAsync($"viewer-{Guid.NewGuid():N}@test.local", tenantId);

        Authorize(viewerToken);
        var list = await _client.GetAsync("/api/v1/sales?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, list.StatusCode);

        var forbidden = await PostSaleAsync(
            viewerToken, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
    }

    [Fact]
    public async Task ListSales_FiltersAndPages()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("sale-list", opening: 10m);
        var first = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var second = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);

        Authorize(token);
        var paged = await _client.GetAsync("/api/v1/sales?page=1&pageSize=1");
        Assert.Equal(HttpStatusCode.OK, paged.StatusCode);
        var pagedDoc = Body(await paged.Content.ReadAsStringAsync());
        Assert.Equal(2, int.Parse(GetProperty(pagedDoc, "total"), CultureInfo.InvariantCulture));
        Assert.Equal(1, pagedDoc.GetProperty("items").GetArrayLength());

        var filtered = await _client.GetAsync($"/api/v1/sales?page=1&pageSize=10&branchId={branchId}&status=0");
        Assert.Equal(HttpStatusCode.OK, filtered.StatusCode);
        Assert.Equal(2, int.Parse(GetProperty(Body(await filtered.Content.ReadAsStringAsync()), "total"), CultureInfo.InvariantCulture));

        var byBranch = await _client.GetAsync($"/api/v1/sales?page=1&pageSize=10&branchId={Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.OK, byBranch.StatusCode);
        Assert.Equal(0, int.Parse(GetProperty(Body(await byBranch.Content.ReadAsStringAsync()), "total"), CultureInfo.InvariantCulture));

        using var db = CreateDbContext();
        Assert.Equal(2, await db.Sales.CountAsync(s => s.TenantId == tenantId));
    }
}

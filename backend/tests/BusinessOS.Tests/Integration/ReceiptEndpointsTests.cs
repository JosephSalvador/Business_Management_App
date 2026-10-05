using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// Integration tests for the Receipt Rendering Engine: receipt preview, print event
/// recording, layout seeding, and the fiscal signer canonical payload generation.
/// </summary>
public sealed class ReceiptEndpointsTests : SalesTestBase
{
    public ReceiptEndpointsTests(BusinessOsApiFactory factory) : base(factory)
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

    [Fact]
    public async Task SeedDefaultLayout_CreatesLayout_ReturnsId()
    {
        var (token, _, _, _, _) = await FixtureAsync("receipt-seed");
        Authorize(token);

        var response = await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var doc = Body(await response.Content.ReadAsStringAsync());
        var layoutId = GetProperty(doc, "value");
        Assert.False(string.IsNullOrEmpty(layoutId));

        // Idempotent: second call returns same id
        var response2 = await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });
        Assert.Equal(HttpStatusCode.OK, response2.StatusCode);
        var doc2 = Body(await response2.Content.ReadAsStringAsync());
        Assert.Equal(layoutId, GetProperty(doc2, "value"));
    }

    [Fact]
    public async Task ListLayouts_ReturnsSeededLayout()
    {
        var (token, _, _, _, _) = await FixtureAsync("receipt-list");
        Authorize(token);

        await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });
        var response = await _client.GetAsync("/api/v1/receipts/layouts");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var doc = Body(await response.Content.ReadAsStringAsync());
        var items = doc.GetProperty("value").EnumerateArray().ToList();
        Assert.Single(items);
        Assert.Equal("thermal_80mm_default", items[0].GetProperty("layoutId").GetString());
        Assert.Equal(1, items[0].GetProperty("version").GetInt32());
        Assert.True(items[0].GetProperty("isActive").GetBoolean());
    }

    [Fact]
    public async Task GetReceiptPreview_ForCompletedSale_ReturnsPreviewWithMetadata()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("receipt-preview");
        Authorize(token);

        // Seed layout first
        await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });

        // Create a sale
        var saleResponse = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, saleResponse.StatusCode);
        var saleDoc = Body(await saleResponse.Content.ReadAsStringAsync());
        var saleId = GetProperty(saleDoc, "id");

        // Get receipt preview
        var previewResponse = await _client.GetAsync($"/api/v1/receipts/{saleId}/preview");
        Assert.Equal(HttpStatusCode.OK, previewResponse.StatusCode);

        var previewDoc = Body(await previewResponse.Content.ReadAsStringAsync());
        Assert.Equal(saleId, GetProperty(previewDoc, "saleId"));
        Assert.Equal("Fanta 500ml", GetProperty(previewDoc, "lines", "0", "productName"));
        Assert.Equal("0", GetProperty(previewDoc, "printCount"));
        Assert.Equal("False", GetProperty(previewDoc, "isReprint"));
        Assert.Equal("False", GetProperty(previewDoc, "isVoided"));
    }

    [Fact]
    public async Task GetReceiptPreview_ReturnsIdentityAndSaleProjectionFields()
    {
        var (token, _, branchId, productId, warehouseId) = await FixtureAsync("receipt-projection");
        Authorize(token);

        await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });

        // The business identity is snapshotted at sale time, so set the contact email first
        // (the update command requires the full profile — round-trip the current values).
        var getOrg = await _client.GetAsync("/api/v1/organization");
        Assert.Equal(HttpStatusCode.OK, getOrg.StatusCode);
        var orgDoc = Body(await getOrg.Content.ReadAsStringAsync());
        var putOrg = await _client.PutAsJsonAsync(
            "/api/v1/organization",
            new
            {
                name = GetProperty(orgDoc, "name"),
                contactEmail = "info@receipt-test.local",
                contactPhone = GetProperty(orgDoc, "contactPhone"),
                address = GetProperty(orgDoc, "address"),
                countryCode = GetProperty(orgDoc, "countryCode"),
                taxId = GetProperty(orgDoc, "taxId"),
            });
        Assert.Equal(HttpStatusCode.OK, putOrg.StatusCode);

        var saleResponse = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        Assert.Equal(HttpStatusCode.OK, saleResponse.StatusCode);
        var saleId = GetProperty(Body(await saleResponse.Content.ReadAsStringAsync()), "id");

        var previewResponse = await _client.GetAsync($"/api/v1/receipts/{saleId}/preview");
        Assert.Equal(HttpStatusCode.OK, previewResponse.StatusCode);
        var previewDoc = Body(await previewResponse.Content.ReadAsStringAsync());

        // Identity block: email captured from the tenant profile at sale time.
        Assert.Equal("info@receipt-test.local", GetProperty(previewDoc, "email"));

        // Sale projection: currency, branch and cashier resolve to display names.
        Assert.Equal("TZS", GetProperty(previewDoc, "currency"));
        Assert.False(string.IsNullOrEmpty(GetProperty(previewDoc, "branchName")));
        Assert.False(string.IsNullOrEmpty(GetProperty(previewDoc, "cashierName")));

        // The sale fixture posts a "Walk-in" customer snapshot.
        Assert.Equal("Walk-in", GetProperty(previewDoc, "customerName"));

        // Every payment carries a reference slot (null for cash tenders).
        Assert.True(previewDoc.GetProperty("payments")[0].TryGetProperty(
            "reference", out _));
    }

    [Fact]
    public async Task GetReceiptPreview_ReturnsPaymentReference()
    {
        var (token, _, branchId, productId, warehouseId) = await FixtureAsync("receipt-ref");
        Authorize(token);

        await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });

        var body = SaleBody(
            branchId,
            Guid.NewGuid(),
            new object[] { new { productId, quantity = 1m } },
            new object[] { new { method = 1, amount = 100m, reference = "TXN-56587451236" } },
            warehouseId: warehouseId);
        var saleResponse = await PostSaleAsync(token, body);
        Assert.Equal(HttpStatusCode.OK, saleResponse.StatusCode);
        var saleId = GetProperty(Body(await saleResponse.Content.ReadAsStringAsync()), "id");

        var previewResponse = await _client.GetAsync($"/api/v1/receipts/{saleId}/preview");
        Assert.Equal(HttpStatusCode.OK, previewResponse.StatusCode);
        var previewDoc = Body(await previewResponse.Content.ReadAsStringAsync());

        Assert.Equal(
            "TXN-56587451236",
            GetProperty(previewDoc, "payments", "0", "reference"));
        Assert.Equal("MobileMoney", GetProperty(previewDoc, "payments", "0", "method"));
    }

    [Fact]
    public async Task RecordPrintEvent_OriginalPrint_IncrementsCount()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("receipt-print");
        Authorize(token);

        await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });

        var saleResponse = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        var saleDoc = Body(await saleResponse.Content.ReadAsStringAsync());
        var saleId = GetProperty(saleDoc, "id");

        // Record original print
        var printResponse = await _client.PostAsJsonAsync(
            $"/api/v1/receipts/{saleId}/print",
            new { type = 0 }); // PrintType.Original
        Assert.Equal(HttpStatusCode.OK, printResponse.StatusCode);

        // Verify preview shows print count
        var previewResponse = await _client.GetAsync($"/api/v1/receipts/{saleId}/preview");
        var previewDoc = Body(await previewResponse.Content.ReadAsStringAsync());
        Assert.Equal("1", GetProperty(previewDoc, "printCount"));
        Assert.Equal("False", GetProperty(previewDoc, "isReprint")); // First print, not a reprint
    }

    [Fact]
    public async Task RecordPrintEvent_Reprint_ShowsReprintFlag()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FixtureAsync("receipt-reprint");
        Authorize(token);

        await _client.PostAsJsonAsync("/api/v1/receipts/layouts/seed", new { });

        var saleResponse = await PostSaleAsync(
            token, SaleBody(branchId, Guid.NewGuid(), productId, 100m, warehouseId: warehouseId));
        var saleDoc = Body(await saleResponse.Content.ReadAsStringAsync());
        var saleId = GetProperty(saleDoc, "id");

        // Record original print
        await _client.PostAsJsonAsync(
            $"/api/v1/receipts/{saleId}/print",
            new { type = 0 });

        // Record reprint
        await _client.PostAsJsonAsync(
            $"/api/v1/receipts/{saleId}/print",
            new { type = 2, notes = "Customer requested copy" }); // PrintType.Reprint

        // Verify preview shows reprint flag
        var previewResponse = await _client.GetAsync($"/api/v1/receipts/{saleId}/preview");
        var previewDoc = Body(await previewResponse.Content.ReadAsStringAsync());
        Assert.Equal("2", GetProperty(previewDoc, "printCount"));
        Assert.Equal("True", GetProperty(previewDoc, "isReprint"));
    }

    [Fact]
    public async Task GetReceiptPreview_SaleNotFound_Returns404()
    {
        var (token, _, _, _, _) = await FixtureAsync("receipt-404");
        Authorize(token);

        var response = await _client.GetAsync($"/api/v1/receipts/{Guid.NewGuid()}/preview");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task FiscalSigner_CanonicalPayload_IsDeterministic()
    {
        // Arrange
        var tenantId = Guid.NewGuid();
        var saleId = Guid.NewGuid();
        var saleDate = new DateTime(2026, 9, 7, 10, 30, 0, DateTimeKind.Utc);

        var sale = BusinessOS.Domain.Sales.Sale.Create(
            tenantId,
            Guid.NewGuid(),
            null,
            Guid.NewGuid(),
            Guid.NewGuid(),
            "S-2026-000001",
            BusinessOS.Domain.Sales.SaleSource.Online,
            saleDate,
            saleDate,
            "TZS",
            null,
            isPriceTaxInclusive: true,
            isElectronicPayment: false,
            customerId: null,
            customerName: null,
            customerTin: null,
            isVatRegistered: null,
            subtotal: 100m,
            discountAmount: 0m,
            taxAmount: 15.25m,
            totalAmount: 100m,
            amountPaid: 100m,
            change: 0m,
            lines: [BusinessOS.Domain.Sales.SaleLine.Create(
                Guid.NewGuid(), null, "Fanta 500ml", "FAN-001", null,
                Guid.NewGuid(), "Bottles",
                quantity: 1, unitPrice: 100m, discountAmount: 0,
                taxCode: "A", appliedRate: 0.18m, appliedRuleId: null,
                baseAmount: 84.75m, taxAmount: 15.25m, lineTotal: 100m,
                orderIndex: 0)],
            payments: [BusinessOS.Domain.Sales.SalePayment.Create(
                BusinessOS.Domain.Sales.PaymentMethod.Cash, 100m, null, null, null, 0)]);

        // Act
        var payload1 = BusinessOS.Domain.Sales.FiscalSigner.GenerateCanonicalPayload(sale);
        var payload2 = BusinessOS.Domain.Sales.FiscalSigner.GenerateCanonicalPayload(sale);

        // Assert
        Assert.Equal(payload1, payload2); // Deterministic
        Assert.Contains("Fanta 500ml", payload1);
        Assert.Contains("S-2026-000001", payload1);
    }

    [Fact]
    public void FiscalSigner_Sha256Hash_IsConsistent()
    {
        var payload = "{\"test\":\"value\"}";
        var hash1 = BusinessOS.Domain.Sales.FiscalSigner.ComputeSha256Hash(payload);
        var hash2 = BusinessOS.Domain.Sales.FiscalSigner.ComputeSha256Hash(payload);
        Assert.Equal(hash1, hash2);
        Assert.Matches("^[a-f0-9]{64}$", hash1); // Lowercase hex, 64 chars
    }

    [Fact]
    public void BusinessIdentitySnapshot_RoundTrip()
    {
        var identity = BusinessOS.Domain.Sales.BusinessIdentitySnapshot.Create(
            "Jolinx Shop",
            tin: "123456789",
            address: "Dar es Salaam",
            phone: "+255712345678");

        var json = identity.ToJson();
        var restored = BusinessOS.Domain.Sales.BusinessIdentitySnapshot.FromJson(json);

        Assert.Equal("Jolinx Shop", restored.BusinessName);
        Assert.Equal("123456789", restored.TIN);
        Assert.Equal("Dar es Salaam", restored.Address);
        Assert.Equal("+255712345678", restored.Phone);
    }
}

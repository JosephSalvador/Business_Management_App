using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// M3 coverage: onboarding must leave a fresh tenant ready for its first sale
/// (default warehouse + default price list + default expense categories), tax
/// categories must be readable, and product search must be case-insensitive.
/// </summary>
public sealed class OnboardingDefaultsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public OnboardingDefaultsTests(BusinessOsApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        _client.Dispose();
        await Task.CompletedTask;
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

    private async Task<string> RegisterLoginOnboardAsync(string label)
    {
        var (token, _) = await TestRegistration.RegisterVerifiedAsync(_client, label);
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

        var complete = await PostOnboardingAsync();
        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);
        return token;
    }

    private Task<HttpResponseMessage> PostOnboardingAsync()
        => _client.PostAsJsonAsync("/api/v1/organization/onboarding", new
        {
            name = $"Duka la Mama {Guid.NewGuid():N}",
            businessType = "retail",
            countryCode = "TZ",
            currency = "TZS",
            contactPhone = (string?)null,
            taxId = (string?)null,
        });

    [Fact]
    public async Task CompleteOnboarding_FirstRun_CreatesDefaultWarehouseAndPriceList()
    {
        await RegisterLoginOnboardAsync("Defaults");

        var warehouses = Body(await (await _client.GetAsync("/api/v1/warehouses?page=1&pageSize=50"))
            .Content.ReadAsStringAsync());
        Assert.Equal(1, warehouses.GetProperty("total").GetInt32());
        var warehouse = warehouses.GetProperty("items")[0];
        Assert.Equal("Main Store", GetProperty(warehouse, "name"));
        Assert.Equal("MAINSTORE", GetProperty(warehouse, "code"));
        Assert.True(bool.Parse(GetProperty(warehouse, "isActive")));
        Assert.Equal(1, warehouse.GetProperty("locations").GetArrayLength());
        Assert.Equal("MAIN", GetProperty(warehouse.GetProperty("locations")[0], "code"));

        var priceLists = Body(await (await _client.GetAsync("/api/v1/price-lists"))
            .Content.ReadAsStringAsync());
        Assert.Equal(1, priceLists.GetArrayLength());
        Assert.Equal("Retail Prices", GetProperty(priceLists[0], "name"));
        Assert.Equal("TZS", GetProperty(priceLists[0], "currency"));
        Assert.True(bool.Parse(GetProperty(priceLists[0], "isDefault")));

        using var db = TestRegistration.CreateDbContext();
        Assert.NotNull(await db.PriceLists
            .Where(pl => pl.IsDefault && pl.Name == "Retail Prices")
            .FirstOrDefaultAsync());
    }

    [Fact]
    public async Task CompleteOnboarding_RepeatedRun_DoesNotDuplicateDefaults()
    {
        await RegisterLoginOnboardAsync("Idempotent");

        var again = await PostOnboardingAsync();
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);

        var warehouses = Body(await (await _client.GetAsync("/api/v1/warehouses?page=1&pageSize=50"))
            .Content.ReadAsStringAsync());
        Assert.Equal(1, warehouses.GetProperty("total").GetInt32());

        var priceLists = Body(await (await _client.GetAsync("/api/v1/price-lists"))
            .Content.ReadAsStringAsync());
        Assert.Equal(1, priceLists.GetArrayLength());

        var categories = Body(await (await _client.GetAsync("/api/v1/expenses/categories"))
            .Content.ReadAsStringAsync());
        Assert.Equal(6, categories.GetArrayLength());
    }

    [Fact]
    public async Task CompleteOnboarding_MissingWarehouseButDefaultPriceList_CreatesOnlyWarehouse()
    {
        var token = await RegisterLoginOnboardAsync("PartialDefaults");
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

        var mine = Body(await (await _client.GetAsync("/api/v1/workspaces/mine"))
            .Content.ReadAsStringAsync());
        var tenantId = Guid.Parse(GetProperty(mine[0], "id"));

        // Simulate a tenant onboarded before defaults existed: no warehouse,
        // but the default price list already present.
        using (var db = TestRegistration.CreateDbContext())
        {
            var warehouses = db.Warehouses.Where(w => w.TenantId == tenantId);
            db.Warehouses.RemoveRange(warehouses);
            await db.SaveChangesAsync();
        }

        var repeat = await PostOnboardingAsync();
        Assert.Equal(HttpStatusCode.OK, repeat.StatusCode);

        var warehousesDoc = Body(await (await _client.GetAsync("/api/v1/warehouses?page=1&pageSize=50"))
            .Content.ReadAsStringAsync());
        Assert.Equal(1, warehousesDoc.GetProperty("total").GetInt32());
        Assert.Equal("Main Store", GetProperty(warehousesDoc.GetProperty("items")[0], "name"));

        var priceLists = Body(await (await _client.GetAsync("/api/v1/price-lists"))
            .Content.ReadAsStringAsync());
        Assert.Equal(1, priceLists.GetArrayLength());
    }

    [Fact]
    public async Task CompleteOnboarding_CreatesDefaultExpenseCategories()
    {
        await RegisterLoginOnboardAsync("ExpCatDefaults");

        var response = await _client.GetAsync("/api/v1/expenses/categories");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var categories = Body(await response.Content.ReadAsStringAsync());
        var names = categories.EnumerateArray()
            .Select(c => c.GetProperty("name").GetString())
            .ToArray();
        Assert.Contains("Utilities", names);
        Assert.Contains("Transport", names);
        Assert.Contains("Rent", names);
        Assert.Contains("Supplies", names);
        Assert.Contains("Petty Cash", names);
        Assert.Contains("Other", names);
        foreach (var category in categories.EnumerateArray())
        {
            Assert.False(string.IsNullOrEmpty(category.GetProperty("id").GetString()));
        }
    }

    [Fact]
    public async Task ListTaxCategories_ReturnsSeededCatalog_AndRequiresAuth()
    {
        var token = await RegisterLoginOnboardAsync("TaxCat");
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

        var response = await _client.GetAsync("/api/v1/tax-categories");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var categories = Body(await response.Content.ReadAsStringAsync());
        Assert.True(categories.GetArrayLength() >= 4);
        var codes = categories.EnumerateArray()
            .Select(c => c.GetProperty("code").GetString())
            .ToArray();
        Assert.Contains("VAT_STANDARD", codes);
        Assert.Contains("VAT_ZERO", codes);
        Assert.Contains("EXEMPT", codes);
        foreach (var category in categories.EnumerateArray())
        {
            Assert.False(string.IsNullOrEmpty(category.GetProperty("id").GetString()));
        }

        _client.DefaultRequestHeaders.Authorization = null;
        var anon = await _client.GetAsync("/api/v1/tax-categories");
        Assert.Equal(HttpStatusCode.Unauthorized, anon.StatusCode);
    }

    [Fact]
    public async Task ProductSearch_MatchesCaseInsensitively()
    {
        var token = await RegisterLoginOnboardAsync("SearchCase");
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

        var units = await _client.PostAsJsonAsync("/api/v1/units", new { name = "Sack", abbreviation = "sk" });
        Assert.Equal(HttpStatusCode.OK, units.StatusCode);
        var unitId = GetProperty(Body(await units.Content.ReadAsStringAsync()), "id");

        var sku = "MC-" + Guid.NewGuid().ToString("N");
        var product = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Mchele wa Tanga",
            sku,
            unitOfMeasureId = unitId,
            productType = 0,
            status = 1,
        });
        Assert.Equal(HttpStatusCode.OK, product.StatusCode);

        foreach (var term in new[] { "mchele", "MCHELE WA", "tanga" })
        {
            var list = Body(await (await _client
                    .GetAsync($"/api/v1/products?page=1&pageSize=10&search={Uri.EscapeDataString(term)}"))
                .Content.ReadAsStringAsync());
            Assert.Equal(1, list.GetProperty("total").GetInt32());
            Assert.Equal("Mchele wa Tanga", GetProperty(list.GetProperty("items")[0], "name"));
        }
    }
}

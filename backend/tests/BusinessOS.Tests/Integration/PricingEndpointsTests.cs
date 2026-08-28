using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class PricingEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public PricingEndpointsTests(BusinessOsApiFactory factory)
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
        var user = User.Create(Guid.NewGuid(), tenantId, email, hash, "Pricing Viewer", phone: null);
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

    private async Task<string> CreatePriceListAsync(string token, string name, bool isDefault = true)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name,
            currency = "TZS",
            isDefault,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    [Fact]
    public async Task PriceListCrud_AndDuplicateDefaultConflict()
    {
        var (token, _) = await RegisterAsync("pricingcrud");
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = " Default ",
            currency = "tzs",
            isDefault = true,
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Default", GetProperty(createdDoc, "name"));
        Assert.Equal("TZS", GetProperty(createdDoc, "currency"));
        Assert.Equal("True", GetProperty(createdDoc, "isDefault"));
        var priceListId = GetProperty(createdDoc, "id");

        var fetched = await _client.GetAsync($"/api/v1/price-lists/{priceListId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal(priceListId, GetProperty(Body(await fetched.Content.ReadAsStringAsync()), "id"));

        var listed = await _client.GetAsync("/api/v1/price-lists");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        Assert.Equal(1, Body(await listed.Content.ReadAsStringAsync()).GetArrayLength());

        var duplicateName = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Default",
            currency = "TZS",
            isDefault = false,
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicateName.StatusCode);

        var duplicateDefault = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Seasonal",
            currency = "TZS",
            isDefault = true,
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicateDefault.StatusCode);

        var updated = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}", new
        {
            name = "Default 2026",
            currency = "TZS",
            isDefault = true,
            isActive = false,
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal("Default 2026", GetProperty(Body(await updated.Content.ReadAsStringAsync()), "name"));
        Assert.Equal("False", GetProperty(Body(await updated.Content.ReadAsStringAsync()), "isActive"));

        var badCurrency = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Bad",
            currency = "TZ",
            isDefault = false,
        });
        Assert.Equal(HttpStatusCode.BadRequest, badCurrency.StatusCode);
    }

    [Fact]
    public async Task SetProductPrices_BulkUpsertRoundTrip_AndValidation()
    {
        var (token, _) = await RegisterAsync("pricingprices");
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Price Product", unitId);
        var priceListId = await CreatePriceListAsync(token, "Default");

        Authorize(token);
        var set = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[]
            {
                new { productId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m },
                new { productId, priceType = 1, price = 80m, currency = "TZS", minQuantity = 5m },
            },
        });
        Assert.Equal(HttpStatusCode.OK, set.StatusCode);
        Assert.Equal(2, Body(await set.Content.ReadAsStringAsync()).GetArrayLength());

        var fetched = await _client.GetAsync($"/api/v1/price-lists/{priceListId}/prices?productId={productId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        var prices = Body(await fetched.Content.ReadAsStringAsync());
        Assert.Equal(2, prices.GetArrayLength());
        Assert.Equal("100", prices[0].GetProperty("price").ToString());

        var updated = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[]
            {
                new { productId, priceType = 0, price = 110m, currency = "TZS", minQuantity = 1m },
                new { productId, priceType = 1, price = 85m, currency = "TZS", minQuantity = 5m },
            },
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        var updatedPrices = Body(await updated.Content.ReadAsStringAsync());
        Assert.Equal(2, updatedPrices.GetArrayLength());
        Assert.Equal("110", updatedPrices[0].GetProperty("price").ToString());

        var duplicateKey = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[]
            {
                new { productId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m },
                new { productId, priceType = 0, price = 90m, currency = "TZS", minQuantity = 1m },
            },
        });
        Assert.Equal(HttpStatusCode.BadRequest, duplicateKey.StatusCode);

        var missingProduct = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[]
            {
                new { productId = Guid.NewGuid(), priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m },
            },
        });
        Assert.Equal(HttpStatusCode.BadRequest, missingProduct.StatusCode);

        var negativePrice = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[]
            {
                new { productId, priceType = 0, price = -5m, currency = "TZS", minQuantity = 1m },
            },
        });
        Assert.Equal(HttpStatusCode.BadRequest, negativePrice.StatusCode);

        var missingPriceList = await _client.PutAsJsonAsync($"/api/v1/price-lists/{Guid.NewGuid()}/prices", new
        {
            prices = new[] { new { productId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m } },
        });
        Assert.Equal(HttpStatusCode.NotFound, missingPriceList.StatusCode);
    }

    [Fact]
    public async Task ResolvePrice_BranchOverride_PriceType_MinQuantity_AndNoPrice()
    {
        var (token, tenantId) = await RegisterAsync("pricingresolve");
        var branchId = await GetDefaultBranchIdAsync(Guid.Parse(tenantId));
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Resolved Product", unitId);
        var otherProductId = await CreateProductAsync(token, "Unpriced Product", unitId);
        var priceListId = await CreatePriceListAsync(token, "Default");

        Authorize(token);
        await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new object[]
            {
                new { productId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m },
                new { productId, priceType = 0, price = 90m, currency = "TZS", minQuantity = 1m, branchId },
                new { productId, priceType = 1, price = 80m, currency = "TZS", minQuantity = 5m },
            },
        });

        Authorize(token);
        var baseRetail = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={productId}&priceType=0&quantity=1");
        Assert.Equal(HttpStatusCode.OK, baseRetail.StatusCode);
        Assert.Equal("100", GetProperty(Body(await baseRetail.Content.ReadAsStringAsync()), "price"));

        var branchRetail = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={productId}&branchId={branchId}&priceType=0&quantity=1");
        Assert.Equal(HttpStatusCode.OK, branchRetail.StatusCode);
        Assert.Equal("90", GetProperty(Body(await branchRetail.Content.ReadAsStringAsync()), "price"));
        Assert.Equal("1", GetProperty(Body(await branchRetail.Content.ReadAsStringAsync()), "minQuantity"));

        var wholesale = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={productId}&priceType=1&quantity=10");
        Assert.Equal(HttpStatusCode.OK, wholesale.StatusCode);
        Assert.Equal("80", GetProperty(Body(await wholesale.Content.ReadAsStringAsync()), "price"));

        var quantityTwo = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={productId}&priceType=1&quantity=2");
        Assert.Equal(HttpStatusCode.NotFound, quantityTwo.StatusCode);

        var noPrice = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={otherProductId}&priceType=0&quantity=1");
        Assert.Equal(HttpStatusCode.NotFound, noPrice.StatusCode);
    }

    [Fact]
    public async Task ResolvePrice_VariantConsistencyValidation()
    {
        var (token, tenantId) = await RegisterAsync("pricingvariant");
        var unitId = await CreateUnitAsync(token, "Bottles");
        var priceListId = await CreatePriceListAsync(token, "Default");
        Authorize(token);

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

        var missingVariant = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={variantProductId}&priceType=0&quantity=1");
        Assert.Equal(HttpStatusCode.BadRequest, missingVariant.StatusCode);

        var wrongVariant = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={variantProductId}&variantId={Guid.NewGuid()}&priceType=0&quantity=1");
        Assert.Equal(HttpStatusCode.BadRequest, wrongVariant.StatusCode);

        var simpleProductId = await CreateProductAsync(token, "Simple Product", unitId);
        var simpleWithVariant = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={simpleProductId}&variantId={variantId}&priceType=0&quantity=1");
        Assert.Equal(HttpStatusCode.BadRequest, simpleWithVariant.StatusCode);
    }

    [Fact]
    public async Task LimitedViewer_CanReadButCannotManagePricing()
    {
        var (_, tenantId) = await RegisterAsync("pricingviewer");
        var viewerToken = await RegisterLimitedViewerAsync(
            $"prv-{Guid.NewGuid():N}@test.local",
            Guid.Parse(tenantId),
            new[] { PermissionNames.PricingView });

        Authorize(viewerToken);
        var read = await _client.GetAsync("/api/v1/price-lists");
        Assert.Equal(HttpStatusCode.OK, read.StatusCode);

        var create = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Blocked",
            currency = "TZS",
            isDefault = false,
        });
        Assert.Equal(HttpStatusCode.Forbidden, create.StatusCode);

        var setPrices = await _client.PutAsJsonAsync($"/api/v1/price-lists/{Guid.NewGuid()}/prices", new
        {
            prices = new object[0],
        });
        Assert.Equal(HttpStatusCode.Forbidden, setPrices.StatusCode);
    }

    [Fact]
    public async Task TenantIsolation_OtherTenantCannotReadOrResolvePricing()
    {
        var (tokenA, _) = await RegisterAsync("tenantA-pricing");
        var unitId = await CreateUnitAsync(tokenA, "Bottles");
        var productId = await CreateProductAsync(tokenA, "Secret Price", unitId);
        var priceListId = await CreatePriceListAsync(tokenA, "Default");
        Authorize(tokenA);
        await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[] { new { productId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m } },
        });

        var (tokenB, _) = await RegisterAsync("tenantB-pricing");
        Authorize(tokenB);

        var read = await _client.GetAsync($"/api/v1/price-lists/{priceListId}");
        Assert.Equal(HttpStatusCode.NotFound, read.StatusCode);

        var update = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}", new
        {
            name = "Hijacked",
            currency = "TZS",
            isDefault = true,
            isActive = true,
        });
        Assert.Equal(HttpStatusCode.NotFound, update.StatusCode);

        var resolve = await _client.GetAsync(
            $"/api/v1/pricing/resolve?productId={productId}&priceType=0&quantity=1");
        Assert.Equal(HttpStatusCode.NotFound, resolve.StatusCode);
    }

    [Fact]
    public async Task PricingMutations_WriteAuditRows()
    {
        var (token, _) = await RegisterAsync("pricingaudit");
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Audited Price", unitId);
        var priceListId = await CreatePriceListAsync(token, "Default");
        Authorize(token);
        await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[] { new { productId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m } },
        });

        using var db = CreateDbContext();
        foreach (var action in new[] { "CreatePriceListCommand", "SetProductPricesCommand" })
        {
            Assert.NotNull(await db.AuditLogs.FirstOrDefaultAsync(l => l.Action == action));
        }
    }

    [Fact]
    public async Task Pricing_PersistsAndDispatchesOutboxEvents()
    {
        var (token, _) = await RegisterAsync("pricingoutbox");
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Outbox Price", unitId);
        var priceListId = await CreatePriceListAsync(token, "Default");
        Authorize(token);
        await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[] { new { productId, priceType = 0, price = 100m, currency = "TZS", minQuantity = 1m } },
        });

        using var db = CreateDbContext();
        foreach (var type in new[]
                 {
                     "BusinessOS.Domain.Events.PriceListCreatedEvent",
                     "BusinessOS.Domain.Events.ProductPricesChangedEvent",
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

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// Shared harness for the sales endpoint integration tests: registers isolated tenants and
/// builds the product/price/stock fixtures a sale needs. Each test owns its tenant, so the
/// shared test database never leaks state across tests.
/// </summary>
public abstract class SalesTestBase : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    protected readonly BusinessOsApiFactory _factory;
    protected readonly HttpClient _client;

    protected SalesTestBase(BusinessOsApiFactory factory)
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

    protected static JsonElement Body(string json) => JsonSerializer.Deserialize<JsonElement>(json);

    protected static string GetProperty(JsonElement doc, params string[] path)
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

    protected Task<(string AccessToken, string TenantId)> RegisterVerifiedAsync(string label)
        => Support.TestRegistration.RegisterVerifiedAsync(_client, label);

    protected Task<HttpResponseMessage> RegisterUnverifiedAsync(string label, string? email = null)
        => Support.TestRegistration.RegisterUnverifiedAsync(_client, label, email);

    protected Task<string> GetLatestVerificationCodeAsync(string email)
        => Support.TestRegistration.GetLatestVerificationCodeAsync(email);

    protected async Task<string> RegisterViewerAsync(string email, Guid tenantId)
    {
        using var db = CreateDbContext();
        var viewPermission = await db.Permissions.FirstAsync(p => p.Name == PermissionNames.SalesView);
        var role = Role.Create(tenantId, $"Viewer-{Guid.NewGuid():N}");
        role.Grant([viewPermission]);
        await db.Roles.AddAsync(role);

        var hash = await db.Users
            .Where(u => u.TenantId == tenantId)
            .Select(u => u.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, email, hash, "Sales Viewer", phone: null);
        user.AssignRole(role);
        user.MarkEmailVerified();
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "accessToken");
    }

    protected void Authorize(string token)
        => _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    protected async Task<Guid> GetDefaultBranchIdAsync(Guid tenantId)
    {
        using var db = CreateDbContext();
        return await db.Branches
            .Where(b => b.TenantId == tenantId)
            .Select(b => b.Id)
            .FirstAsync();
    }

    protected async Task<Guid?> GetTaxCategoryIdAsync(string code)
    {
        using var db = CreateDbContext();
        return await db.TaxCategories
            .Where(c => c.Code == code)
            .Select(c => (Guid?)c.Id)
            .FirstOrDefaultAsync();
    }

    protected async Task<string> CreateUnitAsync(string token, string name)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/units", new { name, abbreviation = name[..3] });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    protected async Task<string> CreateProductAsync(
        string token, string name, string unitId, Guid? taxCategoryId = null, int productType = 0)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name,
            sku = $"SKU-{Guid.NewGuid():N}",
            unitOfMeasureId = unitId,
            productType,
            status = 1,
            taxCategoryId,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    protected async Task<string> CreatePriceListAsync(string token, string name, bool isDefault = true)
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

    protected async Task SetPriceAsync(string token, string priceListId, string productId, decimal price)
    {
        Authorize(token);
        var response = await _client.PutAsJsonAsync($"/api/v1/price-lists/{priceListId}/prices", new
        {
            prices = new[]
            {
                new { productId, priceType = 0, price, currency = "TZS", minQuantity = 1m },
            },
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    protected async Task<string> CreateWarehouseAsync(string token, Guid tenantId, string code)
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

    protected async Task RecordOpeningAsync(
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

    protected async Task<HttpResponseMessage> PostSaleAsync(
        string token, object body, string? idempotencyKey = null)
    {
        Authorize(token);
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/sales")
        {
            Content = JsonContent.Create(body),
        };
        if (idempotencyKey is not null)
        {
            request.Headers.TryAddWithoutValidation("Idempotency-Key", idempotencyKey);
        }

        return await _client.SendAsync(request);
    }

    protected static object SaleBody(
        Guid branchId,
        Guid clientSaleId,
        string productId,
        decimal price,
        decimal quantity = 1m,
        int paymentMethod = 0,
        decimal? amountPaid = null,
        int source = 0,
        bool isElectronicPayment = false,
        bool? isVatRegistered = null,
        string? tin = null,
        string? warehouseId = null,
        string? priceListId = null,
        decimal? discount = null)
        => new
        {
            branchId,
            warehouseId,
            priceListId,
            clientSaleId,
            source,
            effectiveAt = "2026-08-15T12:00:00Z",
            isElectronicPayment,
            isVatRegistered,
            customer = new CustomerBody("Walk-in", "0712345678", tin),
            lines = new[] { new { productId, quantity, discountAmount = discount ?? 0m } },
            payments = new[]
            {
                new { method = paymentMethod, amount = amountPaid ?? price, provider = (string?)null, phoneNumber = (string?)null, reference = (string?)null },
            },
        };

    protected static object SaleBody(
        Guid branchId,
        Guid clientSaleId,
        IReadOnlyList<object> lines,
        IReadOnlyList<object> payments,
        int source = 0,
        bool isElectronicPayment = false,
        bool? isVatRegistered = null,
        string? tin = null,
        string? warehouseId = null,
        string? priceListId = null)
        => new
        {
            branchId,
            warehouseId,
            priceListId,
            clientSaleId,
            source,
            effectiveAt = "2026-08-15T12:00:00Z",
            isElectronicPayment,
            isVatRegistered,
            customer = new CustomerBody("Walk-in", "0712345678", tin),
            lines,
            payments,
        };

    protected BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    protected sealed record CustomerBody(string? Name, string? Phone, string? Tin);
}

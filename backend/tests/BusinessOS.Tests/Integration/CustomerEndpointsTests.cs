using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class CustomerEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public CustomerEndpointsTests(BusinessOsApiFactory factory)
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

    private void Authorize(string token) =>
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    private async Task<string> RegisterLimitedUserAsync(
        string label, Guid tenantId, params string[] permissions)
    {
        using var db = CreateDbContext();
        var perms = await db.Permissions.Where(p => permissions.Contains(p.Name)).ToListAsync();
        var role = Role.Create(tenantId, $"{label} Role");
        role.Grant(perms);
        await db.Roles.AddAsync(role);

        var hash = await db.Users
            .Where(u => u.TenantId == tenantId)
            .Select(u => u.PasswordHash)
            .FirstAsync();
        var user = User.Create(
            Guid.NewGuid(), tenantId, $"{label}-{Guid.NewGuid():N}@test.local",
            hash, label, phone: null);
        user.AssignRole(role);
        user.MarkEmailVerified();
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login",
            new { identifier = user.Email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "tokens", "accessToken");
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    [Fact]
    public async Task Endpoints_RequireAuthentication()
    {
        foreach (var path in new[] { "/api/v1/customers" })
        {
            var response = await _client.GetAsync(path);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }

        var post = await _client.PostAsJsonAsync("/api/v1/customers", new { });
        Assert.Equal(HttpStatusCode.Unauthorized, post.StatusCode);
    }

    [Fact]
    public async Task Customer_FullLifecycle_CreateListGetUpdate()
    {
        var (token, _) = await RegisterAsync("custlifecycle");
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/customers", new
        {
            name = "Acme Corp",
            contactName = "John Doe",
            email = "john@acme.com",
            phone = TestPhones.Next(),
            address = "123 Main St",
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Acme Corp", GetProperty(createdDoc, "name"));
        Assert.Equal("John Doe", GetProperty(createdDoc, "contactName"));
        var customerId = GetProperty(createdDoc, "id");

        var listed = await _client.GetAsync("/api/v1/customers?page=1&pageSize=50");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listDoc = Body(await listed.Content.ReadAsStringAsync());
        Assert.True(listDoc.GetProperty("total").GetInt32() >= 1);

        var fetched = await _client.GetAsync($"/api/v1/customers/{customerId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal("Acme Corp", GetProperty(Body(await fetched.Content.ReadAsStringAsync()), "name"));

        var updated = await _client.PutAsJsonAsync($"/api/v1/customers/{customerId}", new
        {
            name = "Acme Industries",
            email = "info@acme.com",
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        var updatedDoc = Body(await updated.Content.ReadAsStringAsync());
        Assert.Equal("Acme Industries", GetProperty(updatedDoc, "name"));
        Assert.Equal("info@acme.com", GetProperty(updatedDoc, "email"));
    }

    [Fact]
    public async Task CustomersViewOnly_CanReadButCannotMutate()
    {
        var (ownerToken, tenantId) = await RegisterAsync("custviewonly");
        Authorize(ownerToken);

        var created = await _client.PostAsJsonAsync("/api/v1/customers", new
        {
            name = "View Target",
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var customerId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var viewerToken = await RegisterLimitedUserAsync(
            "custviewer", Guid.Parse(tenantId), PermissionNames.CustomersView);
        Authorize(viewerToken);

        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/customers?page=1&pageSize=10")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync($"/api/v1/customers/{customerId}")).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden,
            (await _client.PostAsJsonAsync("/api/v1/customers", new { name = "Blocked" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await _client.PutAsJsonAsync($"/api/v1/customers/{customerId}", new { name = "Hijacked" })).StatusCode);
    }

    [Fact]
    public async Task Customer_ValidationErrors_ReturnBadRequest()
    {
        var (token, _) = await RegisterAsync("custvalid");
        Authorize(token);

        var bad = await _client.PostAsJsonAsync("/api/v1/customers", new { name = "" });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);

        var notFound = await _client.GetAsync($"/api/v1/customers/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, notFound.StatusCode);
    }

    [Fact]
    public async Task Customer_TenantIsolation_ReturnsNotFound()
    {
        var (tokenA, _) = await RegisterAsync("custiso-a");
        Authorize(tokenA);

        var created = await _client.PostAsJsonAsync("/api/v1/customers", new
        {
            name = "Tenant A Customer",
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var customerId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var (tokenB, _) = await RegisterAsync("custiso-b");
        Authorize(tokenB);

        Assert.Equal(HttpStatusCode.NotFound,
            (await _client.GetAsync($"/api/v1/customers/{customerId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await _client.PutAsJsonAsync($"/api/v1/customers/{customerId}", new { name = "Hijacked" })).StatusCode);
    }

    [Fact]
    public async Task Customer_SearchFiltersResults()
    {
        var (token, _) = await RegisterAsync("custsearch");
        Authorize(token);

        await _client.PostAsJsonAsync("/api/v1/customers", new { name = "UniqueAlpha Corp" });
        await _client.PostAsJsonAsync("/api/v1/customers", new { name = "UniqueBeta Ltd" });

        var search = await _client.GetAsync("/api/v1/customers?page=1&pageSize=50&search=UniqueAlpha");
        Assert.Equal(HttpStatusCode.OK, search.StatusCode);
        var doc = Body(await search.Content.ReadAsStringAsync());
        Assert.Equal("1", GetProperty(doc, "total"));
    }
}

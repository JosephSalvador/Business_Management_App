using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class ExpenseEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public ExpenseEndpointsTests(BusinessOsApiFactory factory)
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
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "accessToken");
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
        var response = await _client.GetAsync("/api/v1/expenses");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);

        var post = await _client.PostAsJsonAsync("/api/v1/expenses", new { });
        Assert.Equal(HttpStatusCode.Unauthorized, post.StatusCode);
    }

    [Fact]
    public async Task Expense_FullLifecycle_CreateListGetUpdate()
    {
        var (token, _) = await RegisterAsync("explifecycle");
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Office supplies",
            amount = 150.50m,
            expenseDate = "2026-08-15T10:00:00Z",
            paymentMethod = "Cash",
            reference = "INV-001",
            notes = "Monthly supplies",
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Office supplies", GetProperty(createdDoc, "description"));
        var expenseId = GetProperty(createdDoc, "id");

        var listed = await _client.GetAsync("/api/v1/expenses?page=1&pageSize=50");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listDoc = Body(await listed.Content.ReadAsStringAsync());
        Assert.True(listDoc.GetProperty("total").GetInt32() >= 1);

        var fetched = await _client.GetAsync($"/api/v1/expenses/{expenseId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal("Office supplies", GetProperty(Body(await fetched.Content.ReadAsStringAsync()), "description"));

        var updated = await _client.PutAsJsonAsync($"/api/v1/expenses/{expenseId}", new
        {
            description = "Office supplies - Updated",
            amount = 200m,
            expenseDate = "2026-08-16T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        var updatedDoc = Body(await updated.Content.ReadAsStringAsync());
        Assert.Equal("Office supplies - Updated", GetProperty(updatedDoc, "description"));
        Assert.Equal("200", updatedDoc.GetProperty("amount").ToString());
    }

    [Fact]
    public async Task ExpensesViewOnly_CanReadButCannotMutate()
    {
        var (ownerToken, tenantId) = await RegisterAsync("expviewonly");
        Authorize(ownerToken);

        var created = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "View Target Expense",
            amount = 50m,
            expenseDate = "2026-08-15T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var expenseId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var viewerToken = await RegisterLimitedUserAsync(
            "expviewer", Guid.Parse(tenantId), PermissionNames.ExpensesView);
        Authorize(viewerToken);

        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/expenses?page=1&pageSize=10")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync($"/api/v1/expenses/{expenseId}")).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden,
            (await _client.PostAsJsonAsync("/api/v1/expenses", new
            {
                description = "Blocked",
                amount = 10m,
                expenseDate = "2026-08-15T10:00:00Z",
            })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await _client.PutAsJsonAsync($"/api/v1/expenses/{expenseId}", new
            {
                description = "Hijacked",
                amount = 10m,
                expenseDate = "2026-08-15T10:00:00Z",
            })).StatusCode);
    }

    [Fact]
    public async Task Expense_ValidationErrors_ReturnBadRequest()
    {
        var (token, _) = await RegisterAsync("expvalid");
        Authorize(token);

        var emptyDesc = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "",
            amount = 10m,
            expenseDate = "2026-08-15T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.BadRequest, emptyDesc.StatusCode);

        var zeroAmount = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Zero amount",
            amount = 0m,
            expenseDate = "2026-08-15T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.BadRequest, zeroAmount.StatusCode);

        var notFound = await _client.GetAsync($"/api/v1/expenses/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, notFound.StatusCode);
    }

    [Fact]
    public async Task Expense_Delete_ActuallyRemoves()
    {
        var (token, _) = await RegisterAsync("expdelete");
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "To be deleted",
            amount = 75m,
            expenseDate = "2026-08-15T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var expenseId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var deleted = await _client.DeleteAsync($"/api/v1/expenses/{expenseId}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var fetched = await _client.GetAsync($"/api/v1/expenses/{expenseId}");
        Assert.Equal(HttpStatusCode.NotFound, fetched.StatusCode);

        var list = Body(await (await _client.GetAsync("/api/v1/expenses?page=1&pageSize=50"))
            .Content.ReadAsStringAsync());
        var ids = list.GetProperty("items").EnumerateArray()
            .Select(e => e.GetProperty("id").GetString());
        Assert.DoesNotContain(expenseId, ids);
    }

    [Fact]
    public async Task ExpenseCategory_CreateList_AndIdempotentCreate()
    {
        var (token, _) = await RegisterAsync("expcat");
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/expenses/categories",
            new { name = "Advertising" });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var doc = Body(await created.Content.ReadAsStringAsync());
        var categoryId = GetProperty(doc, "id");
        Assert.Equal("Advertising", GetProperty(doc, "name"));

        var again = await _client.PostAsJsonAsync("/api/v1/expenses/categories",
            new { name = "  Advertising  " });
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Equal(categoryId, GetProperty(Body(await again.Content.ReadAsStringAsync()), "id"));

        var list = Body(await (await _client.GetAsync("/api/v1/expenses/categories"))
            .Content.ReadAsStringAsync());
        Assert.Equal(categoryId, GetProperty(list.EnumerateArray().Single(c => c.GetProperty("name").GetString() == "Advertising"), "id"));

        var empty = await _client.PostAsJsonAsync("/api/v1/expenses/categories", new { name = "" });
        Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
    }

    [Fact]
    public async Task Expense_CreateWithUnknownCategory_ReturnsBadRequest()
    {
        var (token, _) = await RegisterAsync("expbadcat");
        Authorize(token);

        var response = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Bad category",
            amount = 10m,
            expenseDate = "2026-08-15T10:00:00Z",
            categoryId = Guid.NewGuid(),
        });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ExpenseSummary_ReturnsTotalAndByCategory_ForDateRange()
    {
        var (token, _) = await RegisterAsync("expsummary");
        Authorize(token);

        var category = await _client.PostAsJsonAsync("/api/v1/expenses/categories",
            new { name = "Fuel" });
        var categoryId = GetProperty(Body(await category.Content.ReadAsStringAsync()), "id");

        var inCat = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Fuel Aug 10",
            amount = 200m,
            expenseDate = "2026-08-10T10:00:00Z",
            categoryId = Guid.Parse(categoryId),
        });
        Assert.Equal(HttpStatusCode.OK, inCat.StatusCode);
        Assert.Equal("Fuel", GetProperty(Body(await inCat.Content.ReadAsStringAsync()), "categoryName"));

        await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Fuel Aug 20",
            amount = 100m,
            expenseDate = "2026-08-20T10:00:00Z",
            categoryId = Guid.Parse(categoryId),
        });
        await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Cash out",
            amount = 50m,
            expenseDate = "2026-08-11T10:00:00Z",
        });
        await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Out of range",
            amount = 999m,
            expenseDate = "2026-09-01T10:00:00Z",
        });

        var summary = await _client.GetAsync(
            "/api/v1/expenses/summary?fromDate=2026-08-01T00%3A00%3A00Z&toDate=2026-08-31T23%3A59%3A59Z");
        Assert.Equal(HttpStatusCode.OK, summary.StatusCode);
        var doc = Body(await summary.Content.ReadAsStringAsync());
        Assert.Equal("350.00", doc.GetProperty("total").ToString());

        var byCategory = doc.GetProperty("byCategory").EnumerateArray().ToList();
        var fuelLine = byCategory.Single(c => c.GetProperty("categoryId").GetString() == categoryId);
        Assert.Equal("Fuel", GetProperty(fuelLine, "categoryName"));
        Assert.Equal("300.00", fuelLine.GetProperty("total").ToString());
        Assert.Contains(byCategory, c => c.GetProperty("categoryId").ValueKind == System.Text.Json.JsonValueKind.Null);

        var badRange = await _client.GetAsync(
            "/api/v1/expenses/summary?fromDate=2026-09-01T00%3A00%3A00Z&toDate=2026-08-01T00%3A00%3A00Z");
        Assert.Equal(HttpStatusCode.BadRequest, badRange.StatusCode);
    }
}

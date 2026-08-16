using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class OrganizationBranchTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public OrganizationBranchTests(BusinessOsApiFactory factory)
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

    private static bool GetBool(JsonElement doc, params string[] path)
    {
        JsonElement current = doc;
        foreach (var part in path)
        {
            current = current.GetProperty(part);
        }
        return current.GetBoolean();
    }

    private async Task<(string AccessToken, string TenantId)> RegisterAsync(string label)
    {
        var email = $"{label}-{Guid.NewGuid():N}@test.local";
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = $"{label} Owner",
            organizationName = $"{label} Org {Guid.NewGuid():N}",
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());
        return (GetProperty(doc, "accessToken"), GetProperty(doc, "user", "tenantId"));
    }

    private async Task<string> RegisterLimitedViewerAsync(string email, Guid tenantId)
    {
        using var db = CreateDbContext();
        var viewPermission = await db.Permissions.SingleAsync(p => p.Name == PermissionNames.BranchesView);
        var role = Role.Create(tenantId, "Branch Viewer");
        role.Grant(new[] { viewPermission });
        await db.Roles.AddAsync(role);

        var hash = await db.Users
            .Where(u => u.TenantId == tenantId)
            .Select(u => u.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, email, hash, "Branch Viewer", phone: null);
        user.AssignRole(role);
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "accessToken");
    }

    private void Authorize(string token) => _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    [Fact]
    public async Task Register_AutoCreatesDefaultHeadOfficeBranch()
    {
        var (token, _) = await RegisterAsync("defbranch");

        Authorize(token);
        var response = await _client.GetAsync("/api/v1/branches?page=1&pageSize=50");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var doc = Body(await response.Content.ReadAsStringAsync());
        var items = doc.GetProperty("items").EnumerateArray().ToList();
        var hq = items.Single(i => GetProperty(i, "code") == "HQ");
        Assert.Equal("Head Office", GetProperty(hq, "name"));
        Assert.True(GetBool(hq, "isActive"));
    }

    [Fact]
    public async Task BranchCrud_AndStatusFlow_ReturnCorrectCodesAndShapes()
    {
        var (token, _) = await RegisterAsync("crud");

        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/branches", new
        {
            name = "Dar es Salaam",
            code = "DSM",
            currency = "TZS",
            address = "Plot 1, Kariakoo",
            phone = "255700000001",
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("DSM", GetProperty(createdDoc, "code"));
        var branchId = GetProperty(createdDoc, "id");

        var duplicate = await _client.PostAsJsonAsync("/api/v1/branches", new
        {
            name = "Other",
            code = "dsm",
            currency = "TZS",
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);

        var fetched = await _client.GetAsync($"/api/v1/branches/{branchId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);

        var updated = await _client.PutAsJsonAsync($"/api/v1/branches/{branchId}", new
        {
            name = "Dar es Salaam Main",
            address = "Plot 2, Kisutu",
            phone = "255700000002",
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        var updatedDoc = Body(await updated.Content.ReadAsStringAsync());
        Assert.Equal("Dar es Salaam Main", GetProperty(updatedDoc, "name"));
        Assert.Equal("Plot 2, Kisutu", GetProperty(updatedDoc, "address"));

        var deactivated = await _client.PatchAsJsonAsync($"/api/v1/branches/{branchId}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.OK, deactivated.StatusCode);
        Assert.False(GetBool(Body(await deactivated.Content.ReadAsStringAsync()), "isActive"));

        var reactivated = await _client.PatchAsJsonAsync($"/api/v1/branches/{branchId}/status", new { isActive = true });
        Assert.Equal(HttpStatusCode.OK, reactivated.StatusCode);
        Assert.True(GetBool(Body(await reactivated.Content.ReadAsStringAsync()), "isActive"));

        var listed = await _client.GetAsync("/api/v1/branches?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listDoc = Body(await listed.Content.ReadAsStringAsync());
        Assert.Equal("1", GetProperty(listDoc, "page"));
        Assert.Equal("10", GetProperty(listDoc, "pageSize"));
        Assert.True(listDoc.GetProperty("total").GetInt32() >= 2);
    }

    [Fact]
    public async Task LimitedViewer_CanReadButCannotCreateBranches()
    {
        var (_, tenantId) = await RegisterAsync("viewer");
        var viewerToken = await RegisterLimitedViewerAsync($"viewer-{Guid.NewGuid():N}@test.local", Guid.Parse(tenantId));

        Authorize(viewerToken);
        var read = await _client.GetAsync("/api/v1/branches?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, read.StatusCode);

        var create = await _client.PostAsJsonAsync("/api/v1/branches", new
        {
            name = "Blocked",
            code = "BLK",
            currency = "TZS",
        });
        Assert.Equal(HttpStatusCode.Forbidden, create.StatusCode);
    }

    [Fact]
    public async Task TenantIsolation_OtherTenantCannotReadOrUpdateBranch()
    {
        var (tokenA, _) = await RegisterAsync("tenantA");
        Authorize(tokenA);
        var created = await _client.PostAsJsonAsync("/api/v1/branches", new
        {
            name = "Secret Branch",
            code = "SECRET",
            currency = "TZS",
        });
        var branchId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var (tokenB, _) = await RegisterAsync("tenantB");
        Authorize(tokenB);
        var read = await _client.GetAsync($"/api/v1/branches/{branchId}");
        Assert.Equal(HttpStatusCode.NotFound, read.StatusCode);

        var update = await _client.PutAsJsonAsync($"/api/v1/branches/{branchId}", new
        {
            name = "Hijacked",
        });
        Assert.Equal(HttpStatusCode.NotFound, update.StatusCode);

        var status = await _client.PatchAsJsonAsync($"/api/v1/branches/{branchId}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.NotFound, status.StatusCode);
    }

    [Fact]
    public async Task OrganizationEndpoints_ReturnOwnTenantProfile()
    {
        var (token, _) = await RegisterAsync("orgprofile");
        Authorize(token);

        var fetched = await _client.GetAsync("/api/v1/organization");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        var fetchedDoc = Body(await fetched.Content.ReadAsStringAsync());
        Assert.False(string.IsNullOrWhiteSpace(GetProperty(fetchedDoc, "name")));
        Assert.Equal("TZS", GetProperty(fetchedDoc, "currency"));
        Assert.Equal("TZ", GetProperty(fetchedDoc, "countryCode"));

        var newName = $"Acme Renamed {Guid.NewGuid():N}";
        var updated = await _client.PutAsJsonAsync("/api/v1/organization", new
        {
            name = newName,
            contactEmail = "info@acme.local",
            contactPhone = "255700000000",
            countryCode = "KE",
            taxId = "TIN-42",
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        var updatedDoc = Body(await updated.Content.ReadAsStringAsync());
        Assert.Equal(newName, GetProperty(updatedDoc, "name"));
        Assert.Equal("KE", GetProperty(updatedDoc, "countryCode"));
        Assert.Equal("TIN-42", GetProperty(updatedDoc, "taxId"));

        var again = await _client.GetAsync("/api/v1/organization");
        Assert.Equal(newName, GetProperty(Body(await again.Content.ReadAsStringAsync()), "name"));
        Assert.Equal("KE", GetProperty(Body(await again.Content.ReadAsStringAsync()), "countryCode"));

        var missingCode = await _client.PutAsJsonAsync("/api/v1/organization", new
        {
            name = "No Code",
            taxId = "TIN-43",
        });
        Assert.Equal(HttpStatusCode.BadRequest, missingCode.StatusCode);

        var invalidCode = await _client.PutAsJsonAsync("/api/v1/organization", new
        {
            name = "Bad Code",
            countryCode = "tz",
            taxId = "TIN-44",
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalidCode.StatusCode);
    }

    [Fact]
    public async Task Mutations_WriteAuditRows()
    {
        var (token, _) = await RegisterAsync("audit");
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/branches", new
        {
            name = "Audited Branch",
            code = "AUD",
            currency = "TZS",
        });
        var branchId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");
        await _client.PutAsJsonAsync($"/api/v1/branches/{branchId}", new { name = "Audited Branch 2" });
        await _client.PatchAsJsonAsync($"/api/v1/branches/{branchId}/status", new { isActive = false });

        using var db = CreateDbContext();
        foreach (var action in new[] { "CreateBranchCommand", "UpdateBranchCommand", "SetBranchStatusCommand" })
        {
            Assert.NotNull(await db.AuditLogs.FirstOrDefaultAsync(l => l.Action == action));
        }
    }

    [Fact]
    public async Task BranchCreation_PersistsOutboxEventAndDispatchesIt()
    {
        var (token, _) = await RegisterAsync("outbox");
        Authorize(token);

        await _client.PostAsJsonAsync("/api/v1/branches", new
        {
            name = "Outbox Branch",
            code = "OUTBOX",
            currency = "TZS",
        });

        using var db = CreateDbContext();
        var outbox = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Domain.Events.BranchCreatedEvent")
            .OrderByDescending(o => o.OccurredAt)
            .FirstOrDefaultAsync();
        Assert.NotNull(outbox);
        Assert.NotNull(outbox.ProcessedAt);
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}

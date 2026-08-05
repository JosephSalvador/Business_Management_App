using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Tests.Integration;

public sealed class AuthFlowTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public AuthFlowTests(BusinessOsApiFactory factory)
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
            current = current.GetProperty(part);
        }
        return current.ToString();
    }

    [Fact]
    public async Task Register_CreatesTenantAdminWritesAuditAndRaisesEvent()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Test Owner",
            phone = "255700000000",
            organizationName = $"Test Org {Guid.NewGuid():N}",
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());

        var accessToken = GetProperty(doc, "accessToken");
        var refreshToken = GetProperty(doc, "refreshToken");
        var userId = GetProperty(doc, "user", "id");
        var tenantId = GetProperty(doc, "user", "tenantId");
        var permissions = doc.GetProperty("user").GetProperty("permissions").GetArrayLength();

        Assert.False(string.IsNullOrWhiteSpace(accessToken));
        Assert.False(string.IsNullOrWhiteSpace(refreshToken));
        Assert.Equal(email, GetProperty(doc, "user", "email"));
        Assert.True(permissions >= 14, $"expected >=14 permissions, got {permissions}");

        using var db = CreateDbContext();
        Assert.NotNull(await db.AuditLogs.FirstOrDefaultAsync(a => a.Action == "Auth.Register"));
        var outbox = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Domain.Events.UserRegisteredEvent")
            .OrderByDescending(o => o.OccurredAt)
            .FirstOrDefaultAsync();
        Assert.NotNull(outbox);
        Assert.NotNull(outbox.ProcessedAt);

        _client.DefaultRequestHeaders.Authorization = new("Bearer", accessToken);
        var me = await _client.GetAsync("/api/v1/users/me");
        Assert.Equal(HttpStatusCode.OK, me.StatusCode);
        var meDoc = Body(await me.Content.ReadAsStringAsync());
        Assert.Equal(email, GetProperty(meDoc, "email"));
        Assert.Equal(userId, GetProperty(meDoc, "id"));
        Assert.Equal(tenantId, GetProperty(meDoc, "tenantId"));
    }

    [Fact]
    public async Task Login_RejectsWrongPassword()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Login Tester",
            organizationName = $"Test Org {Guid.NewGuid():N}",
        });

        var bad = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email,
            password = "Wrong-Pass",
        });
        Assert.Equal(HttpStatusCode.Unauthorized, bad.StatusCode);

        var good = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email,
            password = "Passw0rd!",
        });
        Assert.Equal(HttpStatusCode.OK, good.StatusCode);
        var doc = Body(await good.Content.ReadAsStringAsync());
        Assert.False(string.IsNullOrWhiteSpace(GetProperty(doc, "accessToken")));
    }

    [Fact]
    public async Task Refresh_RotatesTokenAndRejectsReplay()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        var register = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Refresh Tester",
            organizationName = $"Test Org {Guid.NewGuid():N}",
        });
        var registerDoc = Body(await register.Content.ReadAsStringAsync());
        var originalRefresh = GetProperty(registerDoc, "refreshToken");

        var first = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = originalRefresh });
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var firstDoc = Body(await first.Content.ReadAsStringAsync());
        var secondRefresh = GetProperty(firstDoc, "refreshToken");
        Assert.NotEqual(originalRefresh, secondRefresh);

        var replay = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = originalRefresh });
        Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
    }

    [Fact]
    public async Task UnauthenticatedRequestsAreRejected()
    {
        var response = await _client.GetAsync("/api/v1/users/me");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}

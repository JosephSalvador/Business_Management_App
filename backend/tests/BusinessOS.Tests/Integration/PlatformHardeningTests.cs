using System.Net;
using System.Net.Http.Json;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Tests.Integration;

public sealed class PlatformHardeningTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public PlatformHardeningTests(BusinessOsApiFactory factory)
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

    private async Task<string> RegisterAsync()
    {
        var email = $"harden-{Guid.NewGuid():N}@test.local";
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Hardening Tester",
            organizationName = $"Hardening Org {Guid.NewGuid():N}",
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return email;
    }

    [Fact]
    public async Task VersionedRoutes_AreExposed()
    {
        var unauthorized = await _client.GetAsync("/api/v1/users/me");
        Assert.Equal(HttpStatusCode.Unauthorized, unauthorized.StatusCode);

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email = "admin@acme.local",
            password = "Admin@12345",
        });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var versionHeaders = login.Headers.Contains("api-supported-versions")
            ? string.Join(",", login.Headers.GetValues("api-supported-versions"))
            : string.Empty;
        Assert.Contains("1.0", versionHeaders);
    }

    [Fact]
    public async Task CorrelationId_IsAssignedAndEchoed()
    {
        var response = await _client.GetAsync("/api/v1/users/me");
        Assert.True(response.Headers.Contains("X-Correlation-ID"));
        Assert.False(string.IsNullOrWhiteSpace(response.Headers.GetValues("X-Correlation-ID").First()));
    }

    [Fact]
    public async Task SecurityHeaders_ArePresent()
    {
        var response = await _client.GetAsync("/api/v1/users/me");
        Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").First());
        Assert.Equal("DENY", response.Headers.GetValues("X-Frame-Options").First());
        Assert.Equal("no-referrer", response.Headers.GetValues("Referrer-Policy").First());
    }

    [Fact]
    public async Task Validation_ReturnsStructuredErrors()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = "not-an-email",
            password = "weak",
            fullName = "",
            organizationName = "",
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.Contains("Email", content);
        Assert.Contains("Password", content);
        Assert.Contains("FullName", content);
        Assert.Contains("OrganizationName", content);
    }

    [Fact]
    public async Task AccountLockout_AfterRepeatedFailures()
    {
        var email = await RegisterAsync();

        for (var i = 0; i < 5; i++)
        {
            var response = await _client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = "Wrong-Pass" });
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }

        var locked = await _client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.Unauthorized, locked.StatusCode);
        var body = await locked.Content.ReadAsStringAsync();
        Assert.Contains("locked", body);

        using var db = CreateDbContext();
        var user = await db.Users.FirstAsync(u => u.Email == email);
        Assert.True(user.IsLockedOut);
    }

    [Fact]
    public async Task Revoke_InvalidatesRefreshToken()
    {
        var email = $"revoke-{Guid.NewGuid():N}@test.local";
        var register = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Revoke Tester",
            organizationName = $"Revoke Org {Guid.NewGuid():N}",
        });
        var registerDoc = System.Text.Json.JsonDocument.Parse(await register.Content.ReadAsStringAsync());
        var refreshToken = registerDoc.RootElement.GetProperty("refreshToken").GetString()!;

        var revoke = await _client.PostAsJsonAsync("/api/v1/auth/revoke", new { refreshToken });
        Assert.Equal(HttpStatusCode.NoContent, revoke.StatusCode);

        var refresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
    }

    [Fact]
    public async Task Audit_RecordsLoginFailures()
    {
        var email = await RegisterAsync();
        await _client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = "Wrong-Pass" });

        using var db = CreateDbContext();
        Assert.NotNull(await db.AuditLogs.FirstOrDefaultAsync(a => a.Action == "Auth.LoginFailed"));
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// M5.11 — a suspended tenant can never use the API, so offline terminals
/// replaying queued sales are rejected server-side no matter what the client
/// believes about its local state.
/// </summary>
public sealed class TenantSuspensionTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public TenantSuspensionTests(BusinessOsApiFactory factory)
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

    private async Task<(string AccessToken, Guid TenantId)> RegisterAsync(string label)
    {
        var (token, tenantId) = await TestRegistration.RegisterVerifiedAsync(_client, label);
        return (token, Guid.Parse(tenantId));
    }

    private void SetTenantActive(Guid tenantId, bool active)
    {
        using var db = CreateDbContext();
        var tenant = db.Tenants.Single(t => t.Id == tenantId);
        if (active)
        {
            tenant.Activate();
        }
        else
        {
            tenant.Deactivate();
        }
        db.SaveChanges();
        ResetCache(tenantId);
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    private void ResetCache(Guid tenantId) =>
        _factory.Services.GetRequiredService<IMemoryCache>()
            .Remove($"tenant-active:{tenantId}");

    [Fact]
    public async Task Suspended_tenant_is_rejected_on_authenticated_requests()
    {
        var (token, tenantId) = await RegisterAsync("suspension-reject");
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

        // Sanity: active tenant works.
        var before = await _client.GetAsync("/api/v1/workspaces/mine");
        Assert.Equal(HttpStatusCode.OK, before.StatusCode);

        SetTenantActive(tenantId, active: false);

        var response = await _client.GetAsync("/api/v1/workspaces/mine");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        var payload = Body(await response.Content.ReadAsStringAsync());
        Assert.Equal("Tenant Suspended", payload.GetProperty("title").GetString());
    }

    [Fact]
    public async Task Reactivated_tenant_is_served_again()
    {
        var (token, tenantId) = await RegisterAsync("suspension-reactivate");
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

        SetTenantActive(tenantId, active: false);
        var suspended = await _client.GetAsync("/api/v1/workspaces/mine");
        Assert.Equal(HttpStatusCode.Forbidden, suspended.StatusCode);

        SetTenantActive(tenantId, active: true);

        var restored = await _client.GetAsync("/api/v1/workspaces/mine");
        Assert.Equal(HttpStatusCode.OK, restored.StatusCode);
    }

    [Fact]
    public async Task Anonymous_endpoints_are_not_blocked_by_tenant_status()
    {
        var (_, tenantId) = await RegisterAsync("suspension-anonymous");

        SetTenantActive(tenantId, active: false);

        // Health endpoints carry no tenant claim and must stay reachable.
        var live = await _client.GetAsync("/health/live");
        Assert.NotEqual(HttpStatusCode.Forbidden, live.StatusCode);
    }
}

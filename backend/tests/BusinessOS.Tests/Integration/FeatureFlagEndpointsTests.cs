using System.Linq;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class FeatureFlagEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public FeatureFlagEndpointsTests(BusinessOsApiFactory factory)
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

    private static bool GetBool(JsonElement doc, params string[] path)
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
        return current.GetBoolean();
    }

    // Config is stored as a JSON string; compare normalized so whitespace AND key order are ignored.
    private static string CanonicalJson(string json) => CanonicalNode(JsonNode.Parse(json)!)!.ToJsonString();

    private static JsonNode? CanonicalNode(JsonNode? node) =>
        node switch
        {
            JsonObject obj => new JsonObject(obj.OrderBy(kv => kv.Key)
                .ToDictionary(kv => kv.Key, kv => CanonicalNode(kv.Value), StringComparer.Ordinal)),
            JsonArray arr => new JsonArray(arr.Select(CanonicalNode).ToArray()),
            _ => node?.DeepClone(),
        };

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
        var response = await _client.GetAsync("/api/v1/features");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task FeatureFlag_SetGetList_ToggleEnabled()
    {
        var (token, _) = await RegisterAsync("flagtoggle");
        Authorize(token);

        var setEnabled = await _client.PutAsJsonAsync("/api/v1/features/test.flag", new
        {
            isEnabled = true,
            config = "{\"mode\":\"dark\"}",
        });
        Assert.Equal(HttpStatusCode.OK, setEnabled.StatusCode);
        var enabledDoc = Body(await setEnabled.Content.ReadAsStringAsync());
        Assert.True(GetBool(enabledDoc, "isEnabled"));
        Assert.Equal("test.flag", GetProperty(enabledDoc, "key"));

        var getFlag = await _client.GetAsync("/api/v1/features/test.flag");
        Assert.Equal(HttpStatusCode.OK, getFlag.StatusCode);
        var flagDoc = Body(await getFlag.Content.ReadAsStringAsync());
        Assert.True(GetBool(flagDoc, "isEnabled"));
        Assert.Equal(CanonicalJson("{\"mode\":\"dark\"}"), CanonicalJson(GetProperty(flagDoc, "config")));

        var listed = await _client.GetAsync("/api/v1/features");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listDoc = Body(await listed.Content.ReadAsStringAsync());
        Assert.True(listDoc.GetArrayLength() >= 1);

        var setDisabled = await _client.PutAsJsonAsync("/api/v1/features/test.flag", new
        {
            isEnabled = false,
        });
        Assert.Equal(HttpStatusCode.OK, setDisabled.StatusCode);
        Assert.False(GetBool(Body(await setDisabled.Content.ReadAsStringAsync()), "isEnabled"));

        var confirmDisabled = await _client.GetAsync("/api/v1/features/test.flag");
        Assert.Equal(HttpStatusCode.OK, confirmDisabled.StatusCode);
        Assert.False(GetBool(Body(await confirmDisabled.Content.ReadAsStringAsync()), "isEnabled"));
    }

    [Fact]
    public async Task OrganizationsViewOnly_CanReadButCannotManage()
    {
        var (ownerToken, tenantId) = await RegisterAsync("flagviewonly");
        Authorize(ownerToken);

        await _client.PutAsJsonAsync("/api/v1/features/perm.test", new
        {
            isEnabled = true,
        });

        var viewerToken = await RegisterLimitedUserAsync(
            "flagviewer", Guid.Parse(tenantId), PermissionNames.OrganizationsView);
        Authorize(viewerToken);

        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/features")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/features/perm.test")).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden,
            (await _client.PutAsJsonAsync("/api/v1/features/perm.test", new
            {
                isEnabled = false,
            })).StatusCode);
    }

    [Fact]
    public async Task FeatureFlag_TenantIsolation_FlagsAreScoped()
    {
        var (tokenA, _) = await RegisterAsync("flagiso-a");
        Authorize(tokenA);

        await _client.PutAsJsonAsync("/api/v1/features/tenant.a.flag", new
        {
            isEnabled = true,
        });

        var (tokenB, _) = await RegisterAsync("flagiso-b");
        Authorize(tokenB);

        // Cross-tenant read → 404 (tenant-scoped not-found; no data leaked).
        var getAFlag = await _client.GetAsync("/api/v1/features/tenant.a.flag");
        Assert.Equal(HttpStatusCode.NotFound, getAFlag.StatusCode);

        await _client.PutAsJsonAsync("/api/v1/features/tenant.b.flag", new
        {
            isEnabled = true,
        });

        Authorize(tokenA);
        var listA = Body(await (await _client.GetAsync("/api/v1/features")).Content.ReadAsStringAsync());
        foreach (var flag in listA.EnumerateArray())
        {
            Assert.NotEqual("tenant.b.flag", GetProperty(flag, "key"));
        }
    }

    [Fact]
    public async Task FeatureFlag_WithConfig_PersistsConfig()
    {
        var (token, _) = await RegisterAsync("flagconfig");
        Authorize(token);

        var set = await _client.PutAsJsonAsync("/api/v1/features/configured.flag", new
        {
            isEnabled = true,
            config = "{\"threshold\":42,\"mode\":\"strict\"}",
        });
        Assert.Equal(HttpStatusCode.OK, set.StatusCode);
        var doc = Body(await set.Content.ReadAsStringAsync());
        Assert.Equal(CanonicalJson("{\"threshold\":42,\"mode\":\"strict\"}"), CanonicalJson(GetProperty(doc, "config")));

        var get = await _client.GetAsync("/api/v1/features/configured.flag");
        Assert.Equal(HttpStatusCode.OK, get.StatusCode);
        Assert.Equal(CanonicalJson("{\"threshold\":42,\"mode\":\"strict\"}"),
            CanonicalJson(GetProperty(Body(await get.Content.ReadAsStringAsync()), "config")));
    }
}

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// End-to-end coverage for the M2 authenticated journey: register → verify email →
/// login → workspaces → complete onboarding. Each test owns its tenant; the shared
/// test database never leaks state across tests.
/// </summary>
public sealed class EmailVerificationFlowTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public EmailVerificationFlowTests(BusinessOsApiFactory factory)
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
    public async Task Login_BeforeVerification_Returns403AccountNotVerified()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "Unverified", email);

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.Forbidden, login.StatusCode);

        var problem = Body(await login.Content.ReadAsStringAsync());
        Assert.Equal("AccountNotVerified", GetProperty(problem, "code"));
    }

    [Fact]
    public async Task VerifyEmail_WithCorrectCode_AllowsLoginAndFlagsVerified()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "Verify", email);
        var code = await TestRegistration.GetLatestVerificationCodeAsync(email);

        var verifyResponse = await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code });
        Assert.Equal(HttpStatusCode.NoContent, verifyResponse.StatusCode);

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var doc = Body(await login.Content.ReadAsStringAsync());
        Assert.True(bool.Parse(GetProperty(doc, "user", "emailVerified")));

        // The code is single-use.
        var replay = await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code });
        Assert.Equal(HttpStatusCode.Conflict, replay.StatusCode);
    }

    [Fact]
    public async Task VerifyEmail_WithWrongCode_IncrementsAttemptsAndLocksAfterMax()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "Attempts", email);
        var code = await TestRegistration.GetLatestVerificationCodeAsync(email);

        string? lastMessage = null;
        for (var attempt = 1; attempt <= 5; attempt++)
        {
            var wrongCode = attempt == 5 ? "000000" : "99999" + attempt;
            var wrong = await _client.PostAsJsonAsync(
                "/api/v1/auth/verify-email", new { email, code = wrongCode });
            Assert.False(wrong.IsSuccessStatusCode, $"attempt {attempt} should fail");
            lastMessage = GetProperty(Body(await wrong.Content.ReadAsStringAsync()), "detail");
        }

        Assert.Contains("Too many wrong attempts", lastMessage);

        using var db = TestRegistration.CreateDbContext();
        var userId = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync();
        var consumed = await db.EmailVerificationCodes
            .OrderByDescending(c => c.CreatedAt)
            .FirstAsync(c => c.UserId == userId);
        Assert.NotNull(consumed.ConsumedAt);
        Assert.Equal(5, consumed.AttemptCount);

        // Even the correct code no longer works once the code is locked.
        var correctAfterLock = await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code });
        Assert.False(correctAfterLock.IsSuccessStatusCode);
    }

    [Fact]
    public async Task VerifyEmail_WithExpiredCode_IsRejected()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "Expired", email);
        var code = await TestRegistration.GetLatestVerificationCodeAsync(email);

        using (var db = TestRegistration.CreateDbContext())
        {
            var userId = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync();
            var row = await db.EmailVerificationCodes
                .OrderByDescending(c => c.CreatedAt)
                .FirstAsync(c => c.UserId == userId);
            typeof(EmailVerificationCode)
                .GetProperty(nameof(EmailVerificationCode.ExpiresAt))!
                .SetValue(row, DateTime.UtcNow.AddMinutes(-1));
            await db.SaveChangesAsync();
        }

        var verify = await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code });
        Assert.Equal(HttpStatusCode.BadRequest, verify.StatusCode);
        Assert.Contains("expired", GetProperty(Body(await verify.Content.ReadAsStringAsync()), "detail"));
    }

    [Fact]
    public async Task VerifyEmail_WithUnknownUser_FailsWithoutLeakingExistence()
    {
        var ghost = await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new
        {
            email = $"ghost-{Guid.NewGuid():N}@test.local",
            code = "123456",
        });
        Assert.Equal(HttpStatusCode.BadRequest, ghost.StatusCode);
        Assert.Contains("invalid or has expired",
            GetProperty(Body(await ghost.Content.ReadAsStringAsync()), "detail"));
    }

    [Fact]
    public async Task ResendVerification_RateLimitsAndStaysUniformForUnknownAccounts()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "Resend", email);
        var originalCode = await TestRegistration.GetLatestVerificationCodeAsync(email);

        // Registration just issued a code, so an immediate resend hits the cooldown.
        var throttled = await _client.PostAsJsonAsync("/api/v1/auth/resend-verification", new { email });
        Assert.Equal(HttpStatusCode.TooManyRequests, throttled.StatusCode);

        // Unknown accounts answer with uniform success —
        // the endpoint cannot be used to enumerate registered accounts.
        var ghost = await _client.PostAsJsonAsync("/api/v1/auth/resend-verification", new
        {
            email = $"ghost-{Guid.NewGuid():N}@test.local",
        });
        Assert.Equal(HttpStatusCode.NoContent, ghost.StatusCode);

        // Once the cooldown window has passed the resend succeeds and invalidates
        // the previous code: only the newest one works.
        using (var db = TestRegistration.CreateDbContext())
        {
            var userId = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync();
            var row = await db.EmailVerificationCodes
                .OrderByDescending(c => c.CreatedAt)
                .FirstAsync(c => c.UserId == userId);
            row.GetType().GetProperty(nameof(row.CreatedAt))!
                .SetValue(row, DateTime.UtcNow.AddMinutes(-5));
            await db.SaveChangesAsync();
        }

        var ok = await _client.PostAsJsonAsync("/api/v1/auth/resend-verification", new { email });
        Assert.Equal(HttpStatusCode.NoContent, ok.StatusCode);

        var staleVerify = await _client.PostAsJsonAsync(
            "/api/v1/auth/verify-email", new { email, code = originalCode });
        Assert.Equal(HttpStatusCode.BadRequest, staleVerify.StatusCode);

        var latestCode = await TestRegistration.GetLatestVerificationCodeAsync(email);
        var verify = await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code = latestCode });
        Assert.Equal(HttpStatusCode.NoContent, verify.StatusCode);
    }

    [Fact]
    public async Task WorkspaceJourney_ZeroOnboardingToComplete_MineReflectsBackendState()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "Workspace", email);
        var code = await TestRegistration.GetLatestVerificationCodeAsync(email);
        await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code });

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        var (token, tenantId) = TestRegistration.ParseAuthResponse(await login.Content.ReadAsStringAsync());
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

        // One workspace, onboarding not yet completed.
        var mine = await _client.GetAsync("/api/v1/workspaces/mine");
        Assert.Equal(HttpStatusCode.OK, mine.StatusCode);
        var list = Body(await mine.Content.ReadAsStringAsync());
        Assert.Equal(1, list.GetArrayLength());
        Assert.Equal(tenantId, GetProperty(list[0], "id"));
        Assert.False(bool.Parse(GetProperty(list[0], "onboardingComplete")));
        Assert.Contains("Administrator", list[0].GetProperty("roles").GetRawText());

        // Complete onboarding — creator and tenant derive from the JWT claims.
        // Tenant names are globally unique, so make the display name unique per run.
        var shopName = $"Duka la Mama {Guid.NewGuid():N}";
        var complete = await _client.PostAsJsonAsync("/api/v1/organization/onboarding", new
        {
            name = shopName,
            businessType = "retail",
            countryCode = "TZ",
            currency = "tzs",
            contactPhone = "0712345678",
            taxId = (string?)null,
        });
        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);
        Assert.True(bool.Parse(GetProperty(Body(await complete.Content.ReadAsStringAsync()), "onboardingComplete")));

        var mineAfter = await _client.GetAsync("/api/v1/workspaces/mine");
        var after = Body(await mineAfter.Content.ReadAsStringAsync());
        Assert.True(bool.Parse(GetProperty(after[0], "onboardingComplete")));
        Assert.Equal(shopName, GetProperty(after[0], "name"));
        Assert.Equal("TZS", GetProperty(after[0], "currency"));

        // Audit trail exists for the onboarding mutation.
        using var db = TestRegistration.CreateDbContext();
        Assert.NotNull(await db.AuditLogs
            .Where(a => a.Action == "CompleteOnboardingCommand" && a.TenantId.ToString() == tenantId)
            .FirstOrDefaultAsync());
    }

    [Fact]
    public async Task CompleteOnboarding_RequiresOrganizationsManagePermission()
    {
        var (adminToken, adminTenantId) = await TestRegistration.RegisterVerifiedAsync(_client, "PermAdmin");

        // A viewer inside the same tenant has no Organizations.Manage permission.
        var viewerToken = await RegisterViewerAsync($"viewer-{Guid.NewGuid():N}@test.local", Guid.Parse(adminTenantId));
        _client.DefaultRequestHeaders.Authorization = new("Bearer", viewerToken);
        var forbidden = await _client.PostAsJsonAsync("/api/v1/organization/onboarding", new
        {
            name = "Nope",
            businessType = (string?)null,
            countryCode = "TZ",
            currency = "TZS",
            contactPhone = (string?)null,
            taxId = (string?)null,
        });
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);

        // Tenant isolation: the admin only ever sees their own workspace.
        _client.DefaultRequestHeaders.Authorization = new("Bearer", adminToken);
        var mine = Body(await (await _client.GetAsync("/api/v1/workspaces/mine")).Content.ReadAsStringAsync());
        Assert.Equal(adminTenantId, GetProperty(mine[0], "id"));

        // Anonymous requests are rejected outright.
        _client.DefaultRequestHeaders.Authorization = null;
        var anon = await _client.GetAsync("/api/v1/workspaces/mine");
        Assert.Equal(HttpStatusCode.Unauthorized, anon.StatusCode);
    }

    private async Task<string> RegisterViewerAsync(string email, Guid tenantId)
    {
        using var db = TestRegistration.CreateDbContext();
        var manageViewPermission = await db.Permissions.FirstAsync(p => p.Name == PermissionNames.OrganizationsView);
        var role = Role.Create(tenantId, $"WsViewer-{Guid.NewGuid():N}");
        role.Grant([manageViewPermission]);
        await db.Roles.AddAsync(role);

        var hash = await db.Users
            .Where(u => u.TenantId == tenantId)
            .Select(u => u.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, email, hash, "WS Viewer", phone: null);
        user.AssignRole(role);
        user.MarkEmailVerified();
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "accessToken");
    }
}

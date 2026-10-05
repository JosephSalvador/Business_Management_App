using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Application.Features.Auth.Services;
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

    [Fact]
    public async Task Register_CreatesUnverifiedTenantAdminWritesAuditAndQueuesVerificationEmail()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Test Owner",
            phone = TestPhones.Next(),
            organizationName = $"Test Org {Guid.NewGuid():N}",
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());

        // No session may be issued before the email is verified.
        Assert.False(doc.TryGetProperty("accessToken", out _));
        Assert.Equal(email, GetProperty(doc, "email"));
        Assert.False(bool.Parse(GetProperty(doc, "emailVerified")));
        Assert.True(doc.GetProperty("permissions").GetArrayLength() >= 14);
        var tenantId = GetProperty(doc, "tenantId");

        using var db = CreateDbContext();
        Assert.NotNull(await db.AuditLogs.FirstOrDefaultAsync(a => a.Action == "Auth.Register"));
        var registered = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Domain.Events.UserRegisteredEvent")
            .OrderByDescending(o => o.OccurredAt)
            .FirstOrDefaultAsync();
        Assert.NotNull(registered);
        Assert.NotNull(registered.ProcessedAt);

        // The welcome/verification email job must be queued for the new tenant.
        var emailJob = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Application.Jobs.SendEmailJob" && o.TenantId.ToString() == tenantId)
            .OrderByDescending(o => o.OccurredAt)
            .FirstOrDefaultAsync();
        Assert.NotNull(emailJob);
        Assert.DoesNotContain("Passw0rd", emailJob.Payload);

        // Only a hashed code may exist in the database.
        var userId = await db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync();
        var codeRow = await db.EmailVerificationCodes
            .OrderByDescending(c => c.CreatedAt)
            .FirstAsync(c => c.UserId == userId);
        Assert.DoesNotContain(codeRow.CodeHash, emailJob.Payload);
        Assert.Null(codeRow.ConsumedAt);
    }

    [Fact]
    public async Task Login_RejectsWrongPasswordBeforeAnythingElse()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "LoginTester", email);

        var bad = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            identifier = email,
            password = "Wrong-Pass",
        });
        Assert.Equal(HttpStatusCode.Unauthorized, bad.StatusCode);
        var problem = Body(await bad.Content.ReadAsStringAsync());
        Assert.Equal("Unauthorized", GetProperty(problem, "code"));
    }

    [Fact]
    public async Task Refresh_RotatesTokenAndRejectsReplay()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "RefreshTester", email);
        var code = await TestRegistration.GetLatestVerificationCodeAsync(email);
        Assert.Equal(HttpStatusCode.NoContent,
            (await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code })).StatusCode);

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var doc = Body(await login.Content.ReadAsStringAsync());
        var originalRefresh = GetProperty(doc, "tokens", "refreshToken");

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

    [Fact]
    public async Task DuplicateEmail_IsRejectedWithConflict()
    {
        var email = $"owner-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "DupTester", email);

        var second = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Second Owner",
            phone = TestPhones.Next(),
            organizationName = $"Other Org {Guid.NewGuid():N}",
        });
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Register_WithoutOrganizationName_CreatesPlaceholderTenant()
    {
        var email = $"noname-{Guid.NewGuid():N}@test.local";
        var phone = TestPhones.Next();
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Amina Mwinyi",
            phone,
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var tenantId = GetProperty(Body(await response.Content.ReadAsStringAsync()), "tenantId");

        using var db = CreateDbContext();
        var tenant = await db.Tenants.SingleAsync(t => t.Id.ToString() == tenantId);
        Assert.StartsWith("Biashara ya Amina #", tenant.Name);
    }

    [Fact]
    public async Task Register_DuplicatePhone_ReturnsConflict()
    {
        var phone = TestPhones.Next();
        await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = $"first-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "First Owner",
            phone,
            organizationName = $"Phone Org {Guid.NewGuid():N}",
        });

        var second = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = $"second-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Second Owner",
            phone,
            organizationName = $"Other Org {Guid.NewGuid():N}",
        });
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
        Assert.Contains("Phone", await second.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Login_ByLocalPhoneNumber_SucceedsAfterVerification()
    {
        var email = $"phonelogin-{Guid.NewGuid():N}@test.local";
        // Local Tanzanian form; the backend must normalize it to +255….
        var localPhone = "0" + TestPhones.Next()[3..];
        await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Simu Owner",
            phone = localPhone,
            organizationName = $"Simu Org {Guid.NewGuid():N}",
        });

        var code = await GetLatestCodeFromOutboxAsync(email);
        Assert.Equal(HttpStatusCode.NoContent,
            (await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code })).StatusCode);

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            identifier = localPhone,
            password = "Passw0rd!",
        });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    [Fact]
    public async Task ForgotPassword_UnknownEmail_StillReturnsNoContent()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/auth/forgot-password", new
        {
            email = $"ghost-{Guid.NewGuid():N}@test.local",
        });
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task ResetPassword_FullFlow_SetsNewPasswordAndVerifiesEmail()
    {
        var email = $"reset-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "Resetter", email);

        Assert.Equal(HttpStatusCode.NoContent,
            (await _client.PostAsJsonAsync("/api/v1/auth/forgot-password", new { email })).StatusCode);

        var resetCode = await GetLatestResetCodeFromOutboxAsync(email);
        Assert.Equal(HttpStatusCode.NoContent, (await _client.PostAsJsonAsync("/api/v1/auth/reset-password", new
        {
            email,
            code = resetCode,
            newPassword = "NewPassw0rd!",
        })).StatusCode);

        var oldLogin = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.Unauthorized, oldLogin.StatusCode);

        var newLogin = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "NewPassw0rd!" });
        Assert.Equal(HttpStatusCode.OK, newLogin.StatusCode);
    }

    [Fact]
    public async Task ResetPassword_WrongCode_ReturnsValidationError()
    {
        var email = $"resetbad-{Guid.NewGuid():N}@test.local";
        await TestRegistration.RegisterUnverifiedAsync(_client, "BadResetter", email);

        Assert.Equal(HttpStatusCode.NoContent,
            (await _client.PostAsJsonAsync("/api/v1/auth/forgot-password", new { email })).StatusCode);

        var response = await _client.PostAsJsonAsync("/api/v1/auth/reset-password", new
        {
            email,
            code = "000000",
            newPassword = "NewPassw0rd!",
        });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    /// <summary>Reads the 6-digit code from the newest reset email for the address.</summary>
    private static async Task<string> GetLatestResetCodeFromOutboxAsync(string email)
    {
        var normalized = email.Trim().ToLowerInvariant();
        using var db = TestRegistration.CreateDbContext();
        var payloads = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Application.Jobs.SendEmailJob")
            .OrderByDescending(o => o.OccurredAt)
            .Take(50)
            .Select(o => o.Payload)
            .ToListAsync();
        var payload = payloads.First(p =>
            p.Contains(PasswordResetService.EmailSubject) && p.Contains(normalized));
        return System.Text.RegularExpressions.Regex.Match(payload, @"\b\d{6}\b").Value;
    }

    /// <summary>Reads the 6-digit verification code from the newest welcome email.</summary>
    private static async Task<string> GetLatestCodeFromOutboxAsync(string email)
    {
        var normalized = email.Trim().ToLowerInvariant();
        using var db = TestRegistration.CreateDbContext();
        var userId = await db.Users.Where(u => u.Email == normalized)
            .Select(u => u.TenantId)
            .SingleAsync();
        var payloads = await db.OutboxMessages
            .Where(o => o.TenantId == userId && o.Type == "BusinessOS.Application.Jobs.SendEmailJob")
            .OrderByDescending(o => o.OccurredAt)
            .Take(10)
            .Select(o => o.Payload)
            .ToListAsync();
        var payload = payloads.First(p => p.Contains(normalized));
        return System.Text.RegularExpressions.Regex.Match(payload, @"\b\d{6}\b").Value;
    }
}

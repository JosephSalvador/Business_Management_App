using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Support;

/// <summary>
/// Shared registration flow for integration tests. Registration no longer issues a
/// session: tests verify the email by reading the code from the queued SendEmailJob
/// outbox row (the same place a real mailbox would receive it) and then log in.
/// </summary>
public static class TestRegistration
{
    public static async Task<(string AccessToken, string TenantId)> RegisterVerifiedAsync(
        HttpClient client, string label)
    {
        var (accessToken, tenantId, _) = await RegisterVerifiedWithUserAsync(client, label);
        return (accessToken, tenantId);
    }

    public static async Task<(string AccessToken, string TenantId, string UserId)>
        RegisterVerifiedWithUserAsync(HttpClient client, string label)
    {
        var email = $"{label}-{Guid.NewGuid():N}@test.local";
        await RegisterUnverifiedAsync(client, label, email);

        var code = await GetLatestVerificationCodeAsync(email);
        var verify = await client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code });
        Assert.Equal(HttpStatusCode.NoContent, verify.StatusCode);

        var login = await client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);

        var doc = JsonDocument.Parse(await login.Content.ReadAsStringAsync()).RootElement;
        // Login returns the LoginResponse envelope: tokens live under "tokens".
        var tokens = doc.GetProperty("tokens");
        return (
            tokens.GetProperty("accessToken").ToString(),
            tokens.GetProperty("user").GetProperty("tenantId").ToString(),
            tokens.GetProperty("user").GetProperty("id").ToString());
    }

    public static async Task<HttpResponseMessage> RegisterUnverifiedAsync(
        HttpClient client, string label, string? email = null)
    {
        var response = await client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = email ?? $"{label}-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = $"{label} Owner",
            phone = TestPhones.Next(),
            organizationName = $"{label} Org {Guid.NewGuid():N}",
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return response;
    }

    public static async Task<string> GetLatestVerificationCodeAsync(string email)
    {
        var normalized = email.Trim().ToLowerInvariant();
        using var db = CreateDbContext();
        var userId = await db.Users.Where(u => u.Email == normalized)
            .Select(u => new { u.Id, u.TenantId })
            .SingleAsync();

        // Prefer the tenant-scoped lookup (exact, race-free); fall back to a recent
        // window scan for rows written before TenantId stamping existed.
        var scoped = await db.OutboxMessages
            .Where(o => o.TenantId == userId.TenantId && o.Type == "BusinessOS.Application.Jobs.SendEmailJob")
            .OrderByDescending(o => o.OccurredAt)
            .Select(o => o.Payload)
            .ToListAsync();
        var payload = scoped.FirstOrDefault(p => p.Contains(normalized));

        if (payload is null)
        {
            var recent = await db.OutboxMessages
                .Where(o => o.Type == "BusinessOS.Application.Jobs.SendEmailJob")
                .OrderByDescending(o => o.OccurredAt)
                .Take(2000)
                .Select(o => o.Payload)
                .ToListAsync();
            payload = recent.FirstOrDefault(p => p.Contains(normalized));
        }

        Assert.NotNull(payload);

        var match = Regex.Match(payload, @"\b\d{6}\b");
        Assert.True(match.Success, $"no 6-digit code in outbox payload for {normalized}");
        return match.Value;
    }

    public static (string AccessToken, string TenantId) ParseAuthResponse(string json)
    {
        var doc = JsonSerializer.Deserialize<JsonElement>(json);
        // Login returns the LoginResponse envelope: tokens live under "tokens".
        var tokens = doc.GetProperty("tokens");
        return (
            tokens.GetProperty("accessToken").ToString(),
            tokens.GetProperty("user").GetProperty("tenantId").ToString());
    }

    public static BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}

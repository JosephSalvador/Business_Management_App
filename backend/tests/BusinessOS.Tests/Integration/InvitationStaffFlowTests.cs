using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// Staff join-by-invitation flow: the owner issues a code, a staff member redeems
/// it at registration and is attached to the owner's tenant with the Staff role.
/// The owner flow (creating a business) is untouched — see AuthFlowTests.
/// </summary>
public sealed class InvitationStaffFlowTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public InvitationStaffFlowTests(BusinessOsApiFactory factory)
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

    private void Authorize(string token) =>
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    /// <summary>Registers + verifies an owner, completes onboarding, and returns (token, tenantId).</summary>
    private async Task<(string Token, string TenantId)> RegisterOwnerAsync(string label)
    {
        var (token, tenantId) = await TestRegistration.RegisterVerifiedAsync(_client, label);
        Authorize(token);

        // Inviting staff is gated on a fully onboarded tenant (warehouse, price
        // list, expense categories — see CompleteOnboardingCommand).
        var complete = await _client.PostAsJsonAsync("/api/v1/organization/onboarding", new
        {
            name = $"Duka la {label} {Guid.NewGuid():N}",
            businessType = "retail",
            countryCode = "TZ",
            currency = "TZS",
            contactPhone = (string?)null,
            taxId = (string?)null,
        });
        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);
        return (token, tenantId);
    }

    private async Task<string> IssueInvitationAsync()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/users/invitations", new { });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());
        return GetProperty(doc, "code");
    }

    [Fact]
    public async Task IssueInvitation_RequiresAuthorization()
    {
        _client.DefaultRequestHeaders.Authorization = new("Bearer", "not-a-token");
        var response = await _client.PostAsJsonAsync("/api/v1/users/invitations", new { });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task StaffRegister_WithValidCode_JoinsOwnerTenant_AsActiveStaff()
    {
        var (_, ownerTenantId) = await RegisterOwnerAsync("InvOwnerA");
        var code = await IssueInvitationAsync();
        Assert.Equal(8, code.Length);

        var email = $"staff-{Guid.NewGuid():N}@test.local";
        var staffPhone = TestPhones.Next();
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register-staff", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Staff Member",
            phone = staffPhone,
            invitationCode = code,
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());

        // No session until verified, attached to the OWNER's tenant, active.
        Assert.False(doc.TryGetProperty("accessToken", out _));
        Assert.Equal(email, GetProperty(doc, "email"));
        Assert.Equal(ownerTenantId, GetProperty(doc, "tenantId"));
        Assert.True(bool.Parse(GetProperty(doc, "isActive")));
        Assert.False(bool.Parse(GetProperty(doc, "emailVerified")));

        // Staff permission set is limited (POS + view), not administrator.
        var permissions = doc.GetProperty("permissions").EnumerateArray()
            .Select(p => p.ToString()).ToArray();
        Assert.Contains("Sales.Create", permissions);
        Assert.DoesNotContain("Users.Manage", permissions);
        Assert.DoesNotContain("Organizations.Manage", permissions);

        // No NEW tenant may be created for staff.
        using var db = CreateDbContext();
        Assert.Equal(1, await db.Tenants.CountAsync(t => t.Id.ToString() == ownerTenantId));
        var staffUser = await db.Users.SingleAsync(u => u.Email == email);
        Assert.True(staffUser.IsActive);
        Assert.False(staffUser.EmailVerified);

        // The invitation code is consumed (single-use).
        var codeRow = await db.InvitationCodes.SingleAsync(c => c.TenantId.ToString() == ownerTenantId);
        Assert.NotNull(codeRow.ConsumedAt);
    }

    [Fact]
    public async Task StaffRegister_SameCodeTwice_SecondIsRejected()
    {
        var (_, ownerTenantId) = await RegisterOwnerAsync("InvOwnerB");
        var code = await IssueInvitationAsync();

        var first = await _client.PostAsJsonAsync("/api/v1/auth/register-staff", new
        {
            email = $"staff1-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Staff One",
            phone = TestPhones.Next(),
            invitationCode = code,
        });
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);

        var second = await _client.PostAsJsonAsync("/api/v1/auth/register-staff", new
        {
            email = $"staff2-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Staff Two",
            phone = TestPhones.Next(),
            invitationCode = code,
        });
        Assert.Equal(HttpStatusCode.BadRequest, second.StatusCode);
        using var db = CreateDbContext();
        Assert.Equal(1, await db.Users.CountAsync(u => u.TenantId.ToString() == ownerTenantId
            && u.Email.StartsWith("staff")));
    }

    [Fact]
    public async Task StaffRegister_InvalidCode_ReturnsValidationError()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register-staff", new
        {
            email = $"noghost-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "No Code",
            phone = TestPhones.Next(),
            invitationCode = "ZZZZZZZZ",
        });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Contains("invitation code is not valid", doc.ToString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task StaffRegister_DuplicatePhone_ReturnsConflict()
    {
        var (_, _) = await RegisterOwnerAsync("InvOwnerC");
        var code = await IssueInvitationAsync();
        var phone = TestPhones.Next();

        await _client.PostAsJsonAsync("/api/v1/auth/register-staff", new
        {
            email = $"dupphone1-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Dup One",
            phone,
            invitationCode = code,
        });

        var second = await _client.PostAsJsonAsync("/api/v1/auth/register-staff", new
        {
            email = $"dupphone2-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Dup Two",
            phone,
            invitationCode = code,
        });
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Staff_FullJourney_VerifiesEmail_LogsIn_AndSeesNoAdminPermissions()
    {
        var (_, ownerTenantId) = await RegisterOwnerAsync("InvOwnerD");
        var code = await IssueInvitationAsync();

        var email = $"staffjourney-{Guid.NewGuid():N}@test.local";
        await _client.PostAsJsonAsync("/api/v1/auth/register-staff", new
        {
            email,
            password = "Passw0rd!",
            fullName = "Staff Journey",
            phone = TestPhones.Next(),
            invitationCode = code,
        });

        var verifyCode = await TestRegistration.GetLatestVerificationCodeAsync(email);
        Assert.Equal(HttpStatusCode.NoContent,
            (await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code = verifyCode })).StatusCode);

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var loginDoc = Body(await login.Content.ReadAsStringAsync());
        Assert.Equal(ownerTenantId, GetProperty(loginDoc, "tokens", "user", "tenantId"));

        var permissions = loginDoc.GetProperty("user").GetProperty("permissions")
            .EnumerateArray().Select(p => p.ToString()).ToArray();
        Assert.DoesNotContain("Users.Manage", permissions);
        Assert.DoesNotContain("Organizations.Manage", permissions);
        Assert.DoesNotContain("Roles.Manage", permissions);
    }

    private static BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}

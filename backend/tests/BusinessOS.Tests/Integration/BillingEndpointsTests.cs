using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class BillingEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public BillingEndpointsTests(BusinessOsApiFactory factory)
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

    private static JsonElement Get(JsonElement doc, params string[] path)
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

        return current;
    }

    private static string Text(JsonElement doc, params string[] path) => Get(doc, path).ToString();

    private static bool Flag(JsonElement doc, params string[] path) => Get(doc, path).GetBoolean();

    private Task<(string AccessToken, string TenantId)> RegisterAsync(string label)
        => global::BusinessOS.Tests.Support.TestRegistration.RegisterVerifiedAsync(_client, label);

    private async Task<string> RegisterUserWithoutBillingPermissionsAsync(string email, Guid tenantId)
    {
        using var db = CreateDbContext();
        var role = Role.Create(tenantId, $"Unprivileged-{Guid.NewGuid():N}");
        var passwordHash = await db.Users
            .Where(user => user.TenantId == tenantId)
            .Select(user => user.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, email, passwordHash, "Unprivileged User", phone: null);
        user.AssignRole(role);
        user.MarkEmailVerified();
        await db.Roles.AddAsync(role);
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync(
            "/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return Body(await login.Content.ReadAsStringAsync()).GetProperty("accessToken").GetString()!;
    }

    private void Authorize(string token) =>
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    /// <summary>Forces the tenant's trial end into the past so the next evaluation lapses.</summary>
    private async Task LapseTrialAsync(Guid tenantId)
    {
        using var db = CreateDbContext();
        var subscription = await db.Subscriptions.SingleAsync(s => s.TenantId == tenantId);
        db.Entry(subscription).Property(s => s.TrialEndedAtUtc).CurrentValue =
            DateTime.UtcNow.AddDays(-1);
        await db.SaveChangesAsync();
    }

    private async Task SetPaidUntilAsync(Guid tenantId, DateTime paidUntilUtc)
    {
        using var db = CreateDbContext();
        var subscription = await db.Subscriptions.SingleAsync(s => s.TenantId == tenantId);
        db.Entry(subscription).Property(s => s.PaidUntilUtc).CurrentValue = paidUntilUtc;
        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task BillingEndpoints_RequireAuthentication()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/billing/subscription")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/billing/plans")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/billing/invoices")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/admin/billing/debts")).StatusCode);
    }

    [Fact]
    public async Task Subscription_IsReadableWithoutBillingPermission()
    {
        var (_, tenantId) = await RegisterAsync("billingunprivileged");
        var token = await RegisterUserWithoutBillingPermissionsAsync(
            $"unprivileged-{Guid.NewGuid():N}@test.local", Guid.Parse(tenantId));
        Authorize(token);

        var subscription = await _client.GetAsync("/api/v1/billing/subscription");
        Assert.Equal(HttpStatusCode.OK, subscription.StatusCode);

        var plans = await _client.GetAsync("/api/v1/billing/plans");
        Assert.Equal(HttpStatusCode.Forbidden, plans.StatusCode);
    }

    [Fact]
    public async Task Register_StartsWithProTrial_FullAccess()
    {
        var (token, _) = await RegisterAsync("billingtrial");
        Authorize(token);

        var response = await _client.GetAsync("/api/v1/billing/subscription");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());

        Assert.Equal("Pro", Text(doc, "planCode"));
        Assert.Equal("0", Text(doc, "status"));          // SubscriptionStatus.Trial
        Assert.Equal("0", Text(doc, "accessLevel"));     // AccessLevel.Full
        Assert.False(Flag(doc, "hasOpenInvoice"));
        Assert.Contains("pos.enabled", doc.GetProperty("effectiveFeatureKeys").EnumerateArray().Select(e => e.ToString()));
    }

    [Fact]
    public async Task Plans_ListedGloballyFreeAndPro()
    {
        var (token, _) = await RegisterAsync("billingplans");
        Authorize(token);

        var response = await _client.GetAsync("/api/v1/billing/plans");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());
        var codes = doc.EnumerateArray().Select(p => Text(p, "code")).ToArray();
        Assert.Contains("Free", codes);
        Assert.Contains("Pro", codes);

        var pro = doc.EnumerateArray().Single(p => Text(p, "code") == "Pro");
        Assert.True(decimal.Parse(Text(pro, "monthlyPrice")) >= 0);
        Assert.NotEmpty(Text(pro, "featureKeys"));
    }

    [Fact]
    public async Task Evaluate_WhenTrialLapses_TransitionsToDebtAndIssuesInvoice()
    {
        var (token, tenantId) = await RegisterAsync("billingdebt");
        await LapseTrialAsync(Guid.Parse(tenantId));
        Authorize(token);

        var response = await _client.PostAsync("/api/v1/billing/subscription/evaluate", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());

        Assert.Equal("2", Text(doc, "status"));          // SubscriptionStatus.Debt
        Assert.Equal("1", Text(doc, "accessLevel"));     // AccessLevel.PosAndInventory
        Assert.True(Flag(doc, "hasOpenInvoice"));

        // Backstop features only while in debt.
        var keys = doc.GetProperty("effectiveFeatureKeys").EnumerateArray().Select(e => e.ToString()).ToArray();
        Assert.Contains("pos.enabled", keys);
        Assert.DoesNotContain("accounting.enabled", keys);

        // Evaluate is idempotent: calling again does not double-issue an invoice.
        var again = Body(await (await _client.PostAsync("/api/v1/billing/subscription/evaluate", null)).Content.ReadAsStringAsync());
        Assert.Equal("2", Text(again, "status"));

        var invoices = Body(await (await _client.GetAsync("/api/v1/billing/invoices")).Content.ReadAsStringAsync());
        var open = invoices.EnumerateArray()
            .Where(i => Text(i, "status") == "0")        // InvoiceStatus.Open
            .ToArray();
        Assert.Single(open);
        Assert.StartsWith("INV-", Text(open[0], "number"));
    }

    [Fact]
    public async Task Evaluate_InvalidatesCachedEntitlement_EvenWithoutStatusMutation()
    {
        var (token, tenantId) = await RegisterAsync("billingevaluatecache");
        var tenantGuid = Guid.Parse(tenantId);
        await LapseTrialAsync(tenantGuid);
        Authorize(token);

        var blocked = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Cached debt",
            appliesFrom = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.PaymentRequired, blocked.StatusCode);

        await SetPaidUntilAsync(tenantGuid, DateTime.UtcNow.AddDays(30));
        var evaluate = await _client.PostAsync("/api/v1/billing/subscription/evaluate", null);
        Assert.Equal(HttpStatusCode.OK, evaluate.StatusCode);
        Assert.Equal("1", Text(Body(await evaluate.Content.ReadAsStringAsync()), "status"));

        var allowed = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Fresh access",
            appliesFrom = DateTime.UtcNow,
        });
        Assert.NotEqual(HttpStatusCode.PaymentRequired, allowed.StatusCode);
    }

    [Fact]
    public async Task Middleware_BlocksPremiumWritesWhileInDebt_AllowsReads()
    {
        var (token, tenantId) = await RegisterAsync("billinggate");
        await LapseTrialAsync(Guid.Parse(tenantId));
        Authorize(token);

        await _client.PostAsync("/api/v1/billing/subscription/evaluate", null);

        // Reads stay allowed so the client can render and sync.
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/billing/subscription")).StatusCode);

        // Premium mutation (pricing) rejected with 402 while in debt.
        var blocked = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "In debt",
            appliesFrom = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.PaymentRequired, blocked.StatusCode);

        // Backstop mutation (inventory warehouse) is NOT blocked by the subscription.
        var backstop = await _client.PostAsJsonAsync("/api/v1/warehouses", new
        {
            name = "Main Store",
            code = "MAIN",
        });
        Assert.NotEqual(HttpStatusCode.PaymentRequired, backstop.StatusCode);
    }

    [Fact]
    public async Task Redeem_Voucher_ExtendsAccessAndSettlesOpenInvoice()
    {
        var (token, tenantId) = await RegisterAsync("billingredeem");
        await LapseTrialAsync(Guid.Parse(tenantId));
        Authorize(token);

        var evaluate = Body(await (await _client.PostAsync("/api/v1/billing/subscription/evaluate", null)).Content.ReadAsStringAsync());
        Assert.Equal("2", Text(evaluate, "status"));     // SubscriptionStatus.Debt
        Assert.True(Flag(evaluate, "hasOpenInvoice"));

        var blocked = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Before voucher",
            appliesFrom = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.PaymentRequired, blocked.StatusCode);

        // Owner issues a 30-day prepaid code (Billing.Manage).
        var issued = await _client.PostAsJsonAsync("/api/v1/admin/billing/vouchers/issue", new
        {
            count = 1,
            valueDays = 30,
        });
        Assert.Equal(HttpStatusCode.OK, issued.StatusCode);
        var codes = Body(await issued.Content.ReadAsStringAsync())
            .EnumerateArray().Select(c => c.ToString()).ToArray();
        Assert.Single(codes);
        Assert.Matches(@"^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$", codes[0]);

        var redeem = await _client.PostAsJsonAsync("/api/v1/billing/vouchers/redeem", new { code = codes[0] });
        Assert.Equal(HttpStatusCode.OK, redeem.StatusCode);
        var entitlement = Body(await redeem.Content.ReadAsStringAsync());
        Assert.Equal("1", Text(entitlement, "status"));  // SubscriptionStatus.Active
        Assert.Equal("0", Text(entitlement, "accessLevel")); // AccessLevel.Full
        Assert.False(Flag(entitlement, "hasOpenInvoice"));

        // The open invoice is now settled with the voucher as the payment reference.
        var invoices = Body(await (await _client.GetAsync("/api/v1/billing/invoices")).Content.ReadAsStringAsync());
        var settled = invoices.EnumerateArray().Single(i => Text(i, "status") == "1"); // InvoiceStatus.Paid
        Assert.Equal(codes[0], Text(settled, "reference"));

        var allowed = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "After voucher",
            appliesFrom = DateTime.UtcNow,
        });
        Assert.NotEqual(HttpStatusCode.PaymentRequired, allowed.StatusCode);

        // Redeeming the same code again conflicts.
        var again = await _client.PostAsJsonAsync("/api/v1/billing/vouchers/redeem", new { code = codes[0] });
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
    }

    [Fact]
    public async Task MarkInvoicePaid_InvalidatesCachedEntitlement()
    {
        var (token, tenantId) = await RegisterAsync("billingmarkpaidcache");
        await LapseTrialAsync(Guid.Parse(tenantId));
        Authorize(token);

        var evaluate = await _client.PostAsync("/api/v1/billing/subscription/evaluate", null);
        Assert.Equal(HttpStatusCode.OK, evaluate.StatusCode);

        var invoices = Body(await (await _client.GetAsync("/api/v1/billing/invoices")).Content.ReadAsStringAsync());
        var open = invoices.EnumerateArray().Single(invoice => Text(invoice, "status") == "0");
        var invoiceId = Text(open, "id");

        var blocked = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "Before payment",
            appliesFrom = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.PaymentRequired, blocked.StatusCode);

        var paid = await _client.PostAsJsonAsync(
            $"/api/v1/admin/billing/invoices/{invoiceId}/mark-paid",
            new { reference = "MPESA-TEST-001" });
        Assert.Equal(HttpStatusCode.OK, paid.StatusCode);

        var allowed = await _client.PostAsJsonAsync("/api/v1/price-lists", new
        {
            name = "After payment",
            appliesFrom = DateTime.UtcNow,
        });
        Assert.NotEqual(HttpStatusCode.PaymentRequired, allowed.StatusCode);
    }

    [Fact]
    public async Task Redeem_UnknownOrInvalidVoucher_IsRejected()
    {
        var (token, _) = await RegisterAsync("billingbadcode");
        Authorize(token);

        var unknown = await _client.PostAsJsonAsync("/api/v1/billing/vouchers/redeem", new { code = "ZZZZ-ZZZZ-ZZZZ" });
        Assert.Equal(HttpStatusCode.NotFound, unknown.StatusCode);

        var invalid = await _client.PostAsJsonAsync("/api/v1/billing/vouchers/redeem", new { code = "  " });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
    }

    [Fact]
    public async Task Evaluate_WhenSubscriptionMissing_CreatesTrialAndReturnsItImmediately()
    {
        var (token, tenantId) = await RegisterAsync("billingselfheal");
        var tenantGuid = Guid.Parse(tenantId);
        using (var db = CreateDbContext())
        {
            var subscription = await db.Subscriptions.SingleAsync(s => s.TenantId == tenantGuid);
            db.Subscriptions.Remove(subscription);
            await db.SaveChangesAsync();
        }

        Authorize(token);

        var response = await _client.PostAsync("/api/v1/billing/subscription/evaluate", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());

        Assert.Equal("Pro", Text(doc, "planCode"));
        Assert.Equal("0", Text(doc, "status"));          // SubscriptionStatus.Trial
        Assert.Equal("0", Text(doc, "accessLevel"));     // AccessLevel.Full
        Assert.False(Flag(doc, "hasOpenInvoice"));

        // The response must match the persisted state (not a stale missing-row read).
        var persisted = Body(await (await _client.GetAsync("/api/v1/billing/subscription")).Content.ReadAsStringAsync());
        Assert.Equal("Pro", Text(persisted, "planCode"));
        Assert.Equal("0", Text(persisted, "status"));
    }

    [Fact]
    public async Task Redeem_WhenSubscriptionMissing_CreatesPaidSubscriptionInOneRoundTrip()
    {
        var (token, tenantId) = await RegisterAsync("billingredeemmissing");
        var tenantGuid = Guid.Parse(tenantId);
        using (var db = CreateDbContext())
        {
            var subscription = await db.Subscriptions.SingleAsync(s => s.TenantId == tenantGuid);
            db.Subscriptions.Remove(subscription);
            await db.SaveChangesAsync();
        }

        Authorize(token);

        var issued = await _client.PostAsJsonAsync(
            "/api/v1/admin/billing/vouchers/issue", new { count = 1, valueDays = 30 });
        Assert.Equal(HttpStatusCode.OK, issued.StatusCode);
        var code = Body(await issued.Content.ReadAsStringAsync())
            .EnumerateArray().Single().ToString();

        var redeem = await _client.PostAsJsonAsync(
            "/api/v1/billing/vouchers/redeem", new { code });
        Assert.Equal(HttpStatusCode.OK, redeem.StatusCode);
        var doc = Body(await redeem.Content.ReadAsStringAsync());

        Assert.Equal("Pro", Text(doc, "planCode"));
        Assert.Equal("1", Text(doc, "status"));          // SubscriptionStatus.Active
        Assert.Equal("0", Text(doc, "accessLevel"));     // AccessLevel.Full
        Assert.False(Flag(doc, "hasOpenInvoice"));
    }

    [Fact]
    public async Task FinanceWrites_GateOnFinanceKey_AndFlagToggleInvalidatesCache()
    {
        var (token, _) = await RegisterAsync("billingfinanceflag");
        Authorize(token);

        var disable = await _client.PutAsJsonAsync(
            "/api/v1/features/finance.enabled", new { isEnabled = false });
        Assert.Equal(HttpStatusCode.OK, disable.StatusCode);

        // Middleware must block on finance.enabled (not accounting.enabled) with 403.
        var blocked = await _client.PostAsJsonAsync(
            "/api/v1/money-accounts", new { name = "Cash" });
        Assert.Equal(HttpStatusCode.Forbidden, blocked.StatusCode);
        var doc = Body(await blocked.Content.ReadAsStringAsync());
        Assert.Equal("ModuleDisabled", Text(doc, "code"));
        Assert.Equal("finance.enabled", Text(doc, "featureKey"));

        // Toggling the flag must invalidate the cached entitlement immediately.
        var enable = await _client.PutAsJsonAsync(
            "/api/v1/features/finance.enabled", new { isEnabled = true });
        Assert.Equal(HttpStatusCode.OK, enable.StatusCode);

        var allowed = await _client.PostAsJsonAsync(
            "/api/v1/money-accounts", new { name = "Cash 2" });
        Assert.NotEqual(HttpStatusCode.Forbidden, allowed.StatusCode);
    }
}
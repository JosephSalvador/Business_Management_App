using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class ModulePackagesTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly HttpClient _client;

    public ModulePackagesTests(BusinessOsApiFactory factory)
    {
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

    private static string[] Strings(JsonElement doc, string name)
        => doc.GetProperty(name).EnumerateArray().Select(value => value.ToString()).ToArray();

    private Task<(string AccessToken, string TenantId)> RegisterAsync(string label)
        => global::BusinessOS.Tests.Support.TestRegistration.RegisterVerifiedAsync(_client, label);

    private void Authorize(string token)
        => _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    private async Task LapseTrialAsync(Guid tenantId)
    {
        using var db = CreateDbContext();
        var subscription = await db.Subscriptions.SingleAsync(s => s.TenantId == tenantId);
        db.Entry(subscription).Property(s => s.TrialEndedAtUtc).CurrentValue =
            DateTime.UtcNow.AddDays(-1);
        await db.SaveChangesAsync();
    }

    private async Task<JsonElement> CapabilitiesAsync()
        => Body(await (await _client.GetAsync("/api/v1/capabilities")).Content.ReadAsStringAsync());

    private async Task<string> CreateCustomerAsync(string name)
    {
        var response = await _client.PostAsJsonAsync(
            "/api/v1/customers", new { name, phone = TestPhones.Next() });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return Text(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private async Task ActivateInvoiceManagerAsync()
    {
        var response = await _client.PostAsync("/api/v1/billing/packages/invoice-manager", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private static object NewInvoice(
        string description = "Fitting",
        decimal quantity = 2m,
        decimal unitPrice = 50_000m,
        decimal taxRatePercent = 0m)
        => new
        {
            currency = "TZS",
            issueDate = DateTime.UtcNow,
            lines = new[]
            {
                new
                {
                    description,
                    quantity,
                    unitPrice,
                    taxRatePercent,
                },
            },
        };

    [Fact]
    public async Task Capabilities_RequireAuthentication()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/capabilities")).StatusCode);
    }

    [Fact]
    public async Task InvoiceEndpoints_RequireAuthentication()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/invoices")).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/api/v1/invoices", NewInvoice())).StatusCode);
    }

    [Fact]
    public async Task Capabilities_ReportProTrialWithoutInvoicing()
    {
        var (token, _) = await RegisterAsync("capabilitiestrial");
        Authorize(token);

        var response = await _client.GetAsync("/api/v1/capabilities");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());

        Assert.Equal("Pro", Text(doc, "planCode"));
        Assert.Equal("0", Text(doc, "accessLevel"));
        Assert.Equal("0", Text(doc, "status"));
        Assert.False(Flag(doc, "hasOpenInvoice"));
        Assert.Contains("pos.enabled", Strings(doc, "featureKeys"));
        Assert.Contains("pos.enabled", Strings(doc, "planFeatureKeys"));
        Assert.DoesNotContain("invoicing.enabled", Strings(doc, "featureKeys"));
        Assert.Empty(Strings(doc, "packages"));
        Assert.True(
            DateTime.Parse(Text(doc, "validOfflineUntil")) > DateTime.UtcNow,
            "offline validity must extend past now");
    }

    [Fact]
    public async Task ActivateInvoiceManager_UnlocksInvoicingAndReportsThePackage()
    {
        var (token, _) = await RegisterAsync("packageactivate");
        Authorize(token);

        Assert.DoesNotContain("invoicing.enabled", Strings(await CapabilitiesAsync(), "featureKeys"));

        await ActivateInvoiceManagerAsync();

        var capabilities = await CapabilitiesAsync();
        Assert.Contains("invoicing.enabled", Strings(capabilities, "featureKeys"));
        Assert.Contains("invoice-manager", Strings(capabilities, "packages"));
    }

    [Fact]
    public async Task ActivatePackage_RejectsBasePlansAndUnknownCodes()
    {
        var (token, _) = await RegisterAsync("packagevalidate");
        Authorize(token);

        var basePlan = await _client.PostAsync("/api/v1/billing/packages/Pro", null);
        Assert.Equal(HttpStatusCode.BadRequest, basePlan.StatusCode);
        Assert.Equal("Validation", Text(Body(await basePlan.Content.ReadAsStringAsync()), "code"));

        var unknown = await _client.PostAsync("/api/v1/billing/packages/not-a-plan", null);
        Assert.Equal(HttpStatusCode.NotFound, unknown.StatusCode);
    }

    [Fact]
    public async Task RemovePackage_LocksInvoicingAgain()
    {
        var (token, _) = await RegisterAsync("packageremove");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var removed = await _client.DeleteAsync("/api/v1/billing/packages/invoice-manager");
        Assert.Equal(HttpStatusCode.OK, removed.StatusCode);

        var capabilities = await CapabilitiesAsync();
        Assert.DoesNotContain("invoicing.enabled", Strings(capabilities, "featureKeys"));
        Assert.Empty(Strings(capabilities, "packages"));

        var again = await _client.DeleteAsync("/api/v1/billing/packages/invoice-manager");
        Assert.Equal(HttpStatusCode.NotFound, again.StatusCode);
    }

    [Fact]
    public async Task InvoiceWrites_BlockedWith403_WhenPackageNotActivated_ReadsStillAllowed()
    {
        var (token, _) = await RegisterAsync("invoicemoduleoff");
        Authorize(token);

        var blocked = await _client.PostAsJsonAsync("/api/v1/invoices", NewInvoice());
        Assert.Equal(HttpStatusCode.Forbidden, blocked.StatusCode);
        var doc = Body(await blocked.Content.ReadAsStringAsync());
        Assert.Equal("ModuleDisabled", Text(doc, "code"));
        Assert.Equal("invoicing", Text(doc, "module"));
        Assert.Equal("invoicing.enabled", Text(doc, "featureKey"));

        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/invoices")).StatusCode);
    }

    [Fact]
    public async Task InvoiceWrites_BlockedWith402_WhileInDebt_AndReadsStillAllowed()
    {
        var (token, tenantId) = await RegisterAsync("invoicedebt");
        await LapseTrialAsync(Guid.Parse(tenantId));
        Authorize(token);

        var evaluate = await _client.PostAsync("/api/v1/billing/subscription/evaluate", null);
        Assert.Equal(HttpStatusCode.OK, evaluate.StatusCode);

        var blocked = await _client.PostAsJsonAsync("/api/v1/invoices", NewInvoice());
        Assert.Equal(HttpStatusCode.PaymentRequired, blocked.StatusCode);
        Assert.Equal("BillingRequired", Text(Body(await blocked.Content.ReadAsStringAsync()), "code"));

        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/invoices")).StatusCode);

        // The debt backstop still lets POS work.
        var backstop = await _client.PostAsJsonAsync(
            "/api/v1/warehouses", new { name = "Debt Store", code = "DEBT" });
        Assert.NotEqual(HttpStatusCode.PaymentRequired, backstop.StatusCode);
    }

    [Fact]
    public async Task InvoiceWrites_BlockedWith403_WhenFeatureFlagDisabled()
    {
        var (token, _) = await RegisterAsync("invoiceflag");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var disable = await _client.PutAsJsonAsync(
            "/api/v1/features/invoicing.enabled", new { isEnabled = false });
        Assert.Equal(HttpStatusCode.OK, disable.StatusCode);

        var blocked = await _client.PostAsJsonAsync("/api/v1/invoices", NewInvoice());
        Assert.Equal(HttpStatusCode.Forbidden, blocked.StatusCode);
        Assert.Equal("invoicing.enabled", Text(Body(await blocked.Content.ReadAsStringAsync()), "featureKey"));

        var enable = await _client.PutAsJsonAsync(
            "/api/v1/features/invoicing.enabled", new { isEnabled = true });
        Assert.Equal(HttpStatusCode.OK, enable.StatusCode);

        var allowed = await _client.PostAsJsonAsync("/api/v1/invoices", NewInvoice());
        Assert.Equal(HttpStatusCode.OK, allowed.StatusCode);
    }

    [Fact]
    public async Task InvoiceLifecycle_CreateListPaySettleAndRejectVoidWhenPaid()
    {
        var (token, _) = await RegisterAsync("invoicelifecycle");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var created = await _client.PostAsJsonAsync("/api/v1/invoices", NewInvoice());
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var invoice = Body(await created.Content.ReadAsStringAsync());
        var invoiceId = Text(invoice, "id");

        Assert.StartsWith("CI-", Text(invoice, "number"));
        Assert.Equal("0", Text(invoice, "status"));
        Assert.Equal("100000", Text(invoice, "subtotal"));
        Assert.Equal("100000", Text(invoice, "totalAmount"));
        Assert.Equal("100000", Text(invoice, "balanceDue"));
        var line = Assert.Single(invoice.GetProperty("lines").EnumerateArray().ToArray());
        Assert.Equal("Fitting", line.GetProperty("description").ToString());
        Assert.Equal("100000", line.GetProperty("lineTotal").ToString());

        var listed = Body(await (await _client.GetAsync("/api/v1/invoices")).Content.ReadAsStringAsync());
        Assert.Equal(1, Get(listed, "total").GetInt32());
        Assert.Equal(invoiceId, Text(Get(listed, "items")[0], "id"));

        var detail = Body(await (await _client.GetAsync($"/api/v1/invoices/{invoiceId}")).Content.ReadAsStringAsync());
        Assert.Equal(invoiceId, Text(detail, "id"));

        var partial = await _client.PostAsJsonAsync(
            $"/api/v1/invoices/{invoiceId}/payments", new { amount = 40_000m, method = "M-PESA" });
        Assert.Equal(HttpStatusCode.OK, partial.StatusCode);
        var partiallyPaid = Body(await partial.Content.ReadAsStringAsync());
        Assert.Equal("1", Text(partiallyPaid, "status"));
        Assert.Equal("40000", Text(partiallyPaid, "amountPaid"));
        Assert.Equal("60000", Text(partiallyPaid, "balanceDue"));

        var settled = await _client.PostAsJsonAsync(
            $"/api/v1/invoices/{invoiceId}/payments", new { amount = 60_000m, method = "Cash" });
        Assert.Equal(HttpStatusCode.OK, settled.StatusCode);
        var paid = Body(await settled.Content.ReadAsStringAsync());
        Assert.Equal("2", Text(paid, "status"));
        Assert.Equal("0", Text(paid, "balanceDue"));

        var voidPaid = await _client.PostAsync($"/api/v1/invoices/{invoiceId}/void", null);
        Assert.Equal(HttpStatusCode.Conflict, voidPaid.StatusCode);

        var overpay = await _client.PostAsJsonAsync(
            $"/api/v1/invoices/{invoiceId}/payments", new { amount = 1m });
        Assert.Equal(HttpStatusCode.Conflict, overpay.StatusCode);
    }

    [Fact]
    public async Task InvoiceVoid_MarksInvoiceVoidAndRejectsPayment()
    {
        var (token, _) = await RegisterAsync("invoicevoid");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var created = await _client.PostAsJsonAsync(
            "/api/v1/invoices", NewInvoice("Deposit", 1m, 250_000m));
        var invoiceId = Text(Body(await created.Content.ReadAsStringAsync()), "id");

        var voided = await _client.PostAsync($"/api/v1/invoices/{invoiceId}/void", null);
        Assert.Equal(HttpStatusCode.OK, voided.StatusCode);
        var doc = Body(await voided.Content.ReadAsStringAsync());
        Assert.Equal("3", Text(doc, "status"));
        Assert.False(string.IsNullOrEmpty(Text(doc, "voidedAtUtc")));

        var payment = await _client.PostAsJsonAsync(
            $"/api/v1/invoices/{invoiceId}/payments", new { amount = 1_000m });
        Assert.Equal(HttpStatusCode.Conflict, payment.StatusCode);

        var again = await _client.PostAsync($"/api/v1/invoices/{invoiceId}/void", null);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
    }

    [Fact]
    public async Task InvoiceCreate_RejectsEmptyLinesAndUnknownCustomer()
    {
        var (token, _) = await RegisterAsync("invoicevalidation");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var empty = await _client.PostAsJsonAsync(
            "/api/v1/invoices", new { currency = "TZS", lines = Array.Empty<object>() });
        Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
        Assert.Equal("Validation", Text(Body(await empty.Content.ReadAsStringAsync()), "code"));

        var unknownCustomer = await _client.PostAsJsonAsync(
            "/api/v1/invoices",
            new
            {
                customerId = Guid.NewGuid(),
                currency = "TZS",
                lines = new[] { new { description = "Fitting", quantity = 1m, unitPrice = 1_000m } },
            });
        Assert.Equal(HttpStatusCode.NotFound, unknownCustomer.StatusCode);
    }

    [Fact]
    public async Task InvoiceList_FiltersByStatusAndSearch()
    {
        var (token, _) = await RegisterAsync("invoicefilters");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var consultationCustomer = await CreateCustomerAsync("Consultant Baker");
        var repairCustomer = await CreateCustomerAsync("Repair Garage");

        var first = await _client.PostAsJsonAsync(
            "/api/v1/invoices",
            new
            {
                customerId = consultationCustomer,
                currency = "TZS",
                lines = new[] { new { description = "Consultation", quantity = 1m, unitPrice = 120_000m } },
            });
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var firstId = Text(Body(await first.Content.ReadAsStringAsync()), "id");

        var second = await _client.PostAsJsonAsync(
            "/api/v1/invoices",
            new
            {
                customerId = repairCustomer,
                currency = "TZS",
                lines = new[] { new { description = "Repair", quantity = 1m, unitPrice = 80_000m } },
            });
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);

        var voided = await _client.PostAsync($"/api/v1/invoices/{firstId}/void", null);
        Assert.Equal(HttpStatusCode.OK, voided.StatusCode);

        var all = Body(await (await _client.GetAsync("/api/v1/invoices")).Content.ReadAsStringAsync());
        Assert.Equal(2, Get(all, "total").GetInt32());

        var voids = Body(await (await _client.GetAsync("/api/v1/invoices?status=3")).Content.ReadAsStringAsync());
        Assert.Equal(1, Get(voids, "total").GetInt32());
        Assert.Equal("Consultation", Text(Get(voids, "items")[0], "customerName"));

        var unpaid = Body(await (await _client.GetAsync("/api/v1/invoices?status=0")).Content.ReadAsStringAsync());
        Assert.Equal(1, Get(unpaid, "total").GetInt32());
        Assert.Equal("Repair Garage", Text(Get(unpaid, "items")[0], "customerName"));

        var search = Body(await (await _client.GetAsync("/api/v1/invoices?search=garage")).Content.ReadAsStringAsync());
        Assert.Equal(1, Get(search, "total").GetInt32());
        Assert.Equal("Repair Garage", Text(Get(search, "items")[0], "customerName"));

        var byCustomer = Body(await (
            await _client.GetAsync($"/api/v1/invoices?customerId={consultationCustomer}")).Content.ReadAsStringAsync());
        Assert.Equal(1, Get(byCustomer, "total").GetInt32());
        Assert.Equal("3", Text(Get(byCustomer, "items")[0], "status"));
    }

    [Fact]
    public async Task InvoiceCreate_LinksCustomerNameFromTheCustomerRecord()
    {
        var (token, _) = await RegisterAsync("invoicecustomer");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var customerId = await CreateCustomerAsync("Fatuma Bakery");

        var created = await _client.PostAsJsonAsync(
            "/api/v1/invoices",
            new
            {
                customerId = Guid.Parse(customerId),
                currency = "TZS",
                dueDate = DateTime.UtcNow.AddDays(14),
                notes = "Net 14",
                lines = new[] { new { description = "Signage", quantity = 1m, unitPrice = 350_000m, taxRatePercent = 18m } },
            });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var doc = Body(await created.Content.ReadAsStringAsync());

        Assert.Equal("Fatuma Bakery", Text(doc, "customerName"));
        Assert.Equal(customerId, Text(doc, "customerId"));
        Assert.Equal("Net 14", Text(doc, "notes"));
        Assert.Equal("350000", Text(doc, "subtotal"));
        Assert.Equal("63000", Text(doc, "taxAmount"));
        Assert.Equal("413000", Text(doc, "totalAmount"));
    }

    [Fact]
    public async Task InvoiceAccess_RequiresPermission_AndIsTenantScoped()
    {
        var (token, tenantId) = await RegisterAsync("invoicepermission");
        Authorize(token);
        await ActivateInvoiceManagerAsync();

        var created = await _client.PostAsJsonAsync("/api/v1/invoices", NewInvoice());
        var invoiceId = Text(Body(await created.Content.ReadAsStringAsync()), "id");

        var unprivileged = await RegisterUserWithoutInvoicingPermissionsAsync(
            $"no-invoices-{Guid.NewGuid():N}@test.local", Guid.Parse(tenantId));
        _client.DefaultRequestHeaders.Authorization = new("Bearer", unprivileged);

        var list = await _client.GetAsync("/api/v1/invoices");
        Assert.Equal(HttpStatusCode.Forbidden, list.StatusCode);

        Authorize(token);

        _client.DefaultRequestHeaders.Authorization = null;
        var (otherToken, _) = await RegisterAsync("invoiceothertenant");
        Authorize(otherToken);

        var foreign = await _client.GetAsync($"/api/v1/invoices/{invoiceId}");
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
    }

    private async Task<string> RegisterUserWithoutInvoicingPermissionsAsync(string email, Guid tenantId)
    {
        using var db = CreateDbContext();
        var role = Role.Create(tenantId, $"NoInvoicing-{Guid.NewGuid():N}");
        var passwordHash = await db.Users
            .Where(user => user.TenantId == tenantId)
            .Select(user => user.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, email, passwordHash, "No Invoicing", phone: null);
        user.AssignRole(role);
        user.MarkEmailVerified();
        await db.Roles.AddAsync(role);
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync(
            "/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return Body(await login.Content.ReadAsStringAsync())
            .GetProperty("tokens").GetProperty("accessToken").GetString()!;
    }
}

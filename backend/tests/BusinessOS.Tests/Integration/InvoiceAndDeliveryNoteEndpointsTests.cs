using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class InvoiceAndDeliveryNoteEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public InvoiceAndDeliveryNoteEndpointsTests(BusinessOsApiFactory factory)
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

    private static BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    private Task<(string AccessToken, string TenantId)> RegisterAsync(string label)
        => TestRegistration.RegisterVerifiedAsync(_client, label);

    private void Authorize(string token) =>
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    [Fact]
    public async Task CreateInvoice_GeneratesSequenceNumberAndOutboxEvent()
    {
        var (token, tenantIdStr) = await RegisterAsync("invseq");
        Authorize(token);
        var tenantId = Guid.Parse(tenantIdStr);

        var request = new
        {
            lines = new[]
            {
                new { description = "Web Design", quantity = 1, unitPrice = 500000m, taxRatePercent = 0m, unitOfMeasure = "Job" },
                new { description = "Hosting", quantity = 12, unitPrice = 20000m, taxRatePercent = 0m, unitOfMeasure = "Month" },
            },
            customerName = "Global Enterprises Ltd",
            customerPhone = "+255711223344",
            currency = "TZS",
            notes = "Payment due within 30 days."
        };

        var response = await _client.PostAsJsonAsync("/api/v1/invoices", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var root = doc.RootElement;
        var invoiceId = Guid.Parse(root.GetProperty("id").GetString()!);
        var number = root.GetProperty("number").GetString()!;
        var totalAmount = root.GetProperty("totalAmount").GetDecimal();

        Assert.StartsWith("INV", number);
        Assert.Equal(740000m, totalAmount);
        Assert.Equal("Unpaid", root.GetProperty("status").GetString());

        // Verify outbox integration: domain event saved inside OutboxMessages in same transaction
        using var db = CreateDbContext();
        var outboxMessages = await db.OutboxMessages
            .Where(m => m.TenantId == tenantId && m.Payload.Contains(invoiceId.ToString()))
            .ToListAsync();

        Assert.NotEmpty(outboxMessages);
        Assert.Contains(outboxMessages, m => m.Type.Contains("InvoiceCreatedIntegrationEvent") || m.Type.Contains("CustomerInvoiceIssuedEvent"));
    }

    [Fact]
    public async Task TenantIsolation_BlocksCrossTenantAccess_ForInvoicesAndDeliveryNotes()
    {
        // Setup Tenant A
        var (tokenA, _) = await RegisterAsync("isolan");
        Authorize(tokenA);

        var invResponse = await _client.PostAsJsonAsync("/api/v1/invoices", new
        {
            lines = new[] { new { description = "Exclusive Tenant A Consultation", quantity = 1, unitPrice = 100000m } },
            customerName = "Tenant A VIP Customer"
        });
        Assert.Equal(HttpStatusCode.OK, invResponse.StatusCode);
        using var invDoc = JsonDocument.Parse(await invResponse.Content.ReadAsStringAsync());
        var invoiceId = Guid.Parse(invDoc.RootElement.GetProperty("id").GetString()!);

        var dnResponse = await _client.PostAsJsonAsync("/api/v1/delivery-notes", new
        {
            invoiceId = invoiceId,
            driverName = "Tenant A Driver",
            vehicleNumber = "T 999 AAA"
        });
        Assert.Equal(HttpStatusCode.OK, dnResponse.StatusCode);
        using var dnDoc = JsonDocument.Parse(await dnResponse.Content.ReadAsStringAsync());
        var deliveryNoteId = Guid.Parse(dnDoc.RootElement.GetProperty("id").GetString()!);

        // Setup Tenant B
        var (tokenB, _) = await RegisterAsync("isolbn");
        Authorize(tokenB);

        // Tenant B trying to get Tenant A's invoice
        var getInvB = await _client.GetAsync($"/api/v1/invoices/{invoiceId}");
        Assert.Equal(HttpStatusCode.NotFound, getInvB.StatusCode);

        // Tenant B listing invoices should not see Tenant A's invoice
        var listInvB = await _client.GetFromJsonAsync<JsonElement>("/api/v1/invoices");
        var invoices = listInvB.GetProperty("items").EnumerateArray().ToList();
        Assert.DoesNotContain(invoices, i => i.GetProperty("id").GetString() == invoiceId.ToString());

        // Tenant B trying to get Tenant A's delivery note
        var getDnB = await _client.GetAsync($"/api/v1/delivery-notes/{deliveryNoteId}");
        Assert.Equal(HttpStatusCode.NotFound, getDnB.StatusCode);

        // Tenant B listing delivery notes should not see Tenant A's delivery note
        var listDnB = await _client.GetFromJsonAsync<JsonElement>("/api/v1/delivery-notes");
        var notes = listDnB.GetProperty("items").EnumerateArray().ToList();
        Assert.DoesNotContain(notes, n => n.GetProperty("id").GetString() == deliveryNoteId.ToString());
    }

    [Fact]
    public async Task DeliveryNote_FullLifecycle_FromInvoiceToDelivered()
    {
        var (token, _) = await RegisterAsync("dncycle");
        Authorize(token);

        // 1. Create Invoice
        var invResponse = await _client.PostAsJsonAsync("/api/v1/invoices", new
        {
            lines = new[]
            {
                new { description = "Steel Bars 12mm", quantity = 100, unitPrice = 25000m, unitOfMeasure = "Pcs" },
                new { description = "Binding Wire", quantity = 10, unitPrice = 15000m, unitOfMeasure = "Rolls" }
            },
            customerName = "Kilimanjaro Contractors",
            customerPhone = "+255755123456",
            customerAddress = "Moshi Industrial Area"
        });
        Assert.Equal(HttpStatusCode.OK, invResponse.StatusCode);
        using var invDoc = JsonDocument.Parse(await invResponse.Content.ReadAsStringAsync());
        var invoiceId = Guid.Parse(invDoc.RootElement.GetProperty("id").GetString()!);
        var invoiceNumber = invDoc.RootElement.GetProperty("number").GetString()!;

        // 2. Create Delivery Note from Invoice
        var createDnResponse = await _client.PostAsJsonAsync("/api/v1/delivery-notes", new
        {
            invoiceId = invoiceId,
            vehicleNumber = "T 345 BCD",
            driverName = "Rashid Said",
            driverPhone = "+255767112233"
        });
        Assert.Equal(HttpStatusCode.OK, createDnResponse.StatusCode);
        using var dnDoc = JsonDocument.Parse(await createDnResponse.Content.ReadAsStringAsync());
        var note = dnDoc.RootElement;
        var deliveryNoteId = Guid.Parse(note.GetProperty("id").GetString()!);

        Assert.Equal("Draft", note.GetProperty("status").GetString());
        Assert.Equal(invoiceNumber, note.GetProperty("invoiceNumber").GetString());
        Assert.Equal("Kilimanjaro Contractors", note.GetProperty("customerName").GetString());
        Assert.Equal("Moshi Industrial Area", note.GetProperty("deliveryAddress").GetString());
        Assert.Equal(2, note.GetProperty("items").GetArrayLength());

        // 3. Mark Dispatched
        var dispatchResponse = await _client.PostAsJsonAsync(
            $"/api/v1/delivery-notes/{deliveryNoteId}/dispatch",
            new { vehicleNumber = "T 345 BCD", driverName = "Rashid Said" });
        Assert.Equal(HttpStatusCode.OK, dispatchResponse.StatusCode);
        using var dispDoc = JsonDocument.Parse(await dispatchResponse.Content.ReadAsStringAsync());
        Assert.Equal("Dispatched", dispDoc.RootElement.GetProperty("status").GetString());

        // 4. Mark Delivered
        var deliverResponse = await _client.PostAsJsonAsync(
            $"/api/v1/delivery-notes/{deliveryNoteId}/deliver",
            new { receivedByName = "Site Engineer Bakari" });
        Assert.Equal(HttpStatusCode.OK, deliverResponse.StatusCode);
        using var delDoc = JsonDocument.Parse(await deliverResponse.Content.ReadAsStringAsync());
        Assert.Equal("Delivered", delDoc.RootElement.GetProperty("status").GetString());
        Assert.Equal("Site Engineer Bakari", delDoc.RootElement.GetProperty("receivedByName").GetString());
    }
}

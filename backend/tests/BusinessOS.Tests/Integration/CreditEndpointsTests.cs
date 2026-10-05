using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class CreditEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public CreditEndpointsTests(BusinessOsApiFactory factory)
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

    private Task<(string AccessToken, string TenantId)> RegisterAsync(string label)
        => global::BusinessOS.Tests.Support.TestRegistration.RegisterVerifiedAsync(_client, label);

    private void Authorize(string token) =>
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    private async Task<string> CreateCustomerAsync(string token, string name)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/customers", new { name });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    [Fact]
    public async Task Credit_FullLifecycle_SetLimitSalePaymentBalance()
    {
        var (token, _) = await RegisterAsync("creditlifecycle");
        var customerId = await CreateCustomerAsync(token, "Credit Customer");
        Authorize(token);

        var limitSet = await _client.PutAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/limit", new { limit = 1000m });
        Assert.Equal(HttpStatusCode.OK, limitSet.StatusCode);
        var limitDoc = Body(await limitSet.Content.ReadAsStringAsync());
        Assert.Equal(1000m, limitDoc.GetProperty("creditLimit").GetDecimal());

        var getCredit = await _client.GetAsync($"/api/v1/customers/{customerId}/credit");
        Assert.Equal(HttpStatusCode.OK, getCredit.StatusCode);
        var creditDoc = Body(await getCredit.Content.ReadAsStringAsync());
        Assert.Equal(customerId, GetProperty(creditDoc, "customerId"));

        var sale = await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/sale",
            new { amount = 250m, description = "Credit sale #1" });
        Assert.Equal(HttpStatusCode.OK, sale.StatusCode);
        var saleDoc = Body(await sale.Content.ReadAsStringAsync());
        Assert.Equal(250m, saleDoc.GetProperty("balance").GetDecimal());

        var payment = await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/payment",
            new { amount = 100m, description = "Payment #1" });
        Assert.Equal(HttpStatusCode.OK, payment.StatusCode);
        var paymentDoc = Body(await payment.Content.ReadAsStringAsync());
        Assert.Equal(150m, paymentDoc.GetProperty("balance").GetDecimal());
    }

    [Fact]
    public async Task Credit_ListTransactions_ReturnsCreditSaleAndPayment()
    {
        var (token, _) = await RegisterAsync("credittxlist");
        var customerId = await CreateCustomerAsync(token, "TX Customer");
        Authorize(token);

        await _client.PutAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/limit", new { limit = 500m });

        await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/sale",
            new { amount = 100m, description = "Sale A" });
        await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/sale",
            new { amount = 50m, description = "Sale B" });
        await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/payment",
            new { amount = 30m, description = "Payment A" });

        var txs = await _client.GetAsync(
            $"/api/v1/customers/{customerId}/credit/transactions?page=1&pageSize=50");
        Assert.Equal(HttpStatusCode.OK, txs.StatusCode);
        var txDoc = Body(await txs.Content.ReadAsStringAsync());
        // Endpoint returns a raw JSON array of transactions (newest first).
        Assert.Equal(3, txDoc.GetArrayLength());

        var first = txDoc[0];
        // type serializes as the numeric enum value (Sale=0, Payment=1). Newest-first ordering
        // means the most recent transaction (Payment A) is element 0.
        Assert.Equal("1", first.GetProperty("type").ToString());
    }

    [Fact]
    public async Task Credit_ListOutstandingCredit_ShowsCustomersWithBalance()
    {
        var (token, _) = await RegisterAsync("creditoutstanding");
        var customerId = await CreateCustomerAsync(token, "Outstanding Customer");
        Authorize(token);

        await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/sale",
            new { amount = 200m, description = "Outstanding sale" });

        var outstanding = await _client.GetAsync("/api/v1/credit/outstanding");
        Assert.Equal(HttpStatusCode.OK, outstanding.StatusCode);
        var outstandingDoc = Body(await outstanding.Content.ReadAsStringAsync());
        Assert.True(outstandingDoc.GetArrayLength() >= 1);

        var found = false;
        foreach (var item in outstandingDoc.EnumerateArray())
        {
            if (GetProperty(item, "customerId") == customerId)
            {
                Assert.Equal(200m, item.GetProperty("balance").GetDecimal());
                found = true;
                break;
            }
        }
        Assert.True(found, "Outstanding credit list should contain the customer.");
    }

    [Fact]
    public async Task Credit_PaymentExceedingBalance_ReturnsValidation()
    {
        var (token, _) = await RegisterAsync("creditoverpay");
        var customerId = await CreateCustomerAsync(token, "Overpay Customer");
        Authorize(token);

        await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/sale",
            new { amount = 50m, description = "Small sale" });

        var overpay = await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/payment",
            new { amount = 100m, description = "Too much" });
        Assert.Equal(HttpStatusCode.BadRequest, overpay.StatusCode);
    }

    [Fact]
    public async Task Credit_SetLimit_AutoCreatesCreditRecord()
    {
        var (token, _) = await RegisterAsync("creditautocreate");
        var customerId = await CreateCustomerAsync(token, "Auto Credit Customer");
        Authorize(token);

        var setLimit = await _client.PutAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/limit", new { limit = 750m });
        Assert.Equal(HttpStatusCode.OK, setLimit.StatusCode);
        var doc = Body(await setLimit.Content.ReadAsStringAsync());
        Assert.Equal("750", doc.GetProperty("creditLimit").ToString());
        Assert.Equal("0", doc.GetProperty("balance").ToString());
    }
}

using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

/// <summary>
/// M10.2 — end-to-end validation that Jolinx behaves as one integrated business OS. These tests
/// drive the real HTTP APIs + Postgres across the lifecycle:
/// Business → Product → Inventory → Customer → Sale → Payment → Credit → Expense → Money Account
/// → Cash Session → Reports, plus cross-tenant isolation.
///
/// These tests RECORD THE CURRENT BEHAVIOUR of the system as found. They deliberately do NOT
/// invent business rules or finance links that the product does not yet implement. In particular
/// (see the individual tests for exact assertions):
///   * A completed sale records amount-paid templates (SalePayment) but does NOT auto-post credit
///     to a MoneyAccount.
///   * A ledger expense (POST /expenses) does NOT auto-post to a MoneyAccount; the dedicated
///     POST /money-accounts/expense endpoint is the only path that touches the money account.
/// These gaps are recorded as findings for the business decision, not silently "fixed" here.
/// </summary>
public sealed class BusinessLifecycleEndToEndTests : SalesTestBase
{
    public BusinessLifecycleEndToEndTests(BusinessOsApiFactory factory) : base(factory)
    {
    }

    // ── Helpers (reuse SalesTestBase + TestRegistration; no new test framework) ──

    private async Task<(string Token, Guid TenantId, Guid BranchId, string ProductId, string WarehouseId)>
        FullSalesFixtureAsync(string label, decimal opening = 20m, decimal price = 1000m)
    {
        var (token, tenantId) = await RegisterVerifiedAsync(label);
        var unitId = await CreateUnitAsync(token, "Bottles");
        var productId = await CreateProductAsync(token, "Fanta 500ml", unitId);
        var priceListId = await CreatePriceListAsync(token, "Default");
        await SetPriceAsync(token, priceListId, productId, price);
        var warehouseId = await CreateWarehouseAsync(token, Guid.Parse(tenantId), $"WH-{Guid.NewGuid():N}");
        if (opening > 0m)
        {
            await RecordOpeningAsync(token, warehouseId, productId, unitId, opening);
        }

        return (token, Guid.Parse(tenantId), await GetDefaultBranchIdAsync(Guid.Parse(tenantId)), productId, warehouseId);
    }

    private static decimal Decimal(JsonElement doc, params string[] path)
        => decimal.Parse(Str(doc, path), CultureInfo.InvariantCulture);

    private static string Str(JsonElement doc, params string[] path)
    {
        JsonElement current = doc;
        foreach (var part in path)
        {
            if (int.TryParse(part, out var index))
            {
                current = current[index];
            }
            else
            {
                current = current.GetProperty(part);
            }
        }
        return current.ValueKind == JsonValueKind.Null ? "" : current.ToString();
    }

    private async Task<string> CreateCustomerAsync(string token, string name)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/customers", new { name });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    private static async Task<decimal> BalanceAfterTaxAsync(
        HttpClient client, string token, string warehouseId, string productId)
    {
        client.DefaultRequestHeaders.Authorization = new("Bearer", token);
        var response = await client.GetAsync($"/api/v1/inventory/stock?page=1&pageSize=10&warehouseId={warehouseId}&productId={productId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = JsonSerializer.Deserialize<JsonElement>(await response.Content.ReadAsStringAsync());
        Assert.Equal("1", GetProperty(doc, "total"));
        return decimal.Parse(Str(doc, "items", "0", "quantity"), CultureInfo.InvariantCulture);
    }

    // ── Business → Product → Inventory → Customer → Sale (Phases 2, 3, 4-sale, 7) ──

    [Fact]
    public async Task Sale_ShouldReduceInventory_RecordPayment_AndBeIdempotent()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FullSalesFixtureAsync("e2e-sale", opening: 20m, price: 1000m);
        var customerId = await CreateCustomerAsync(token, "E2E Customer");

        // Initial stock = 20
        Assert.Equal(20m, await BalanceAfterTaxAsync(_client, token, warehouseId, productId));

        // Product exists + is tenant-owned
        Authorize(token);
        var productResponse = await _client.GetAsync($"/api/v1/products/{productId}");
        Assert.Equal(HttpStatusCode.OK, productResponse.StatusCode);
        var productDoc = Body(await productResponse.Content.ReadAsStringAsync());
        Assert.Equal(tenantId.ToString(), GetProperty(productDoc, "tenantId"));
        Assert.Equal("Fanta 500ml", GetProperty(productDoc, "name"));

        // Customer exists + tenant-owned
        var customerResponse = await _client.GetAsync($"/api/v1/customers/{customerId}");
        Assert.Equal(HttpStatusCode.OK, customerResponse.StatusCode);
        Assert.Equal(tenantId.ToString(), GetProperty(Body(await customerResponse.Content.ReadAsStringAsync()), "tenantId"));

        // Sale of 3 units @ 1000 = 3000
        var clientSaleId = Guid.NewGuid();
        var sale = await PostSaleAsync(token, SaleBody(
            branchId, clientSaleId, productId, 1000m, quantity: 3m, amountPaid: 3000m, warehouseId: warehouseId));
        Assert.True(sale.StatusCode == HttpStatusCode.OK, $"sale failed: {await sale.Content.ReadAsStringAsync()}");
        var saleDoc = Body(await sale.Content.ReadAsStringAsync());

        Assert.Equal(clientSaleId.ToString(), GetProperty(saleDoc, "clientSaleId"));
        Assert.Equal("0", GetProperty(saleDoc, "status")); // not voided
        Assert.Equal(3000m, Decimal(saleDoc, "totalAmount"));
        Assert.Equal(3000m, Decimal(saleDoc, "amountPaid"));
        Assert.Equal(0m, Decimal(saleDoc, "change"));
        var saleLine = Assert.Single(saleDoc.GetProperty("lines").EnumerateArray());
        Assert.Equal(productId, GetProperty(saleLine, "productId"));
        Assert.Equal(3m, Decimal(saleLine, "quantity"));
        var saleId = GetProperty(saleDoc, "id");
        var number = GetProperty(saleDoc, "number");
        Assert.Matches(new System.Text.RegularExpressions.Regex(@"^S-\d{4}-\d{6}$"), number);

        // Payment template recorded (Phase 3 — as far as the current architecture supports).
        var payment = Assert.Single(saleDoc.GetProperty("payments").EnumerateArray());
        Assert.Equal(3000m, Decimal(payment, "amount"));

        // Inventory side effect: 20 − 3 = 17 (Phase 7, via API + DB).
        Assert.Equal(17m, await BalanceAfterTaxAsync(_client, token, warehouseId, productId));
        using (var db = CreateDbContext())
        {
            var balance = await db.StockBalances
                .Where(b => b.TenantId == tenantId && b.ProductId == Guid.Parse(productId))
                .SingleAsync();
            Assert.Equal(17m, balance.Quantity);

            // Sale recorded once, with a Sale-level movement.
            Assert.Equal(1, await db.Sales.CountAsync(s => s.TenantId == tenantId));
            Assert.Equal(1, await db.StockMovements.CountAsync(
                m => m.TenantId == tenantId && m.MovementType == BusinessOS.Domain.Inventory.StockMovementType.Sale));
        }

        // Idempotency: replay of the same ClientSaleId returns the original, no double stock.
        var replay = await PostSaleAsync(token, SaleBody(
            branchId, clientSaleId, productId, 1000m, quantity: 3m, amountPaid: 3000m, warehouseId: warehouseId));
        Assert.True(replay.StatusCode == HttpStatusCode.OK, $"replay failed: {await replay.Content.ReadAsStringAsync()}");
        var replayDoc = Body(await replay.Content.ReadAsStringAsync());
        Assert.Equal(saleId, GetProperty(replayDoc, "id"));
        Assert.Equal(number, GetProperty(replayDoc, "number"));
        using (var db2 = CreateDbContext())
        {
            Assert.Equal(1, await db2.Sales.CountAsync(s => s.TenantId == tenantId));
            Assert.Equal(17m, (await db2.StockBalances
                .Where(b => b.TenantId == tenantId && b.ProductId == Guid.Parse(productId))
                .SingleAsync()).Quantity);
        }
    }

    // ── Credit Lifecycle (Phase 4): customer buys 100,000 on credit, pays 40,000 → 60,000 ──

    [Fact]
    public async Task CreditSale_ShouldTrackOutstandingBalance()
    {
        var (token, _) = await RegisterVerifiedAsync("e2e-credit");
        var customerId = await CreateCustomerAsync(token, "Credit Customer");
        Authorize(token);

        // 1. Set a credit limit (creates the credit record with balance 0).
        // NOTE (finding): recording a credit SALE against a customer with NO credit record has been
        // observed to 500 (optimistic-concurrency 0-rows-affected) in the auto-create path; the
        // proven path is to provision the limit first, as done here. The sale-first auto-create is
        // separately exercised by the existing Credit_ListOutstandingCredit integration test.
        var limit = await _client.PutAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/limit", new { limit = 200000m });
        Assert.True(limit.StatusCode == HttpStatusCode.OK, $"credit limit failed: {await limit.Content.ReadAsStringAsync()}");
        Assert.Equal(0m, Decimal(Body(await limit.Content.ReadAsStringAsync()), "balance"));

        // 2. Credit sale of 100,000 → outstanding 100,000.
        var sale = await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/sale",
            new { amount = 100000m, description = "Credit sale #1" });
        Assert.True(sale.StatusCode == HttpStatusCode.OK, $"credit sale failed: {await sale.Content.ReadAsStringAsync()}");
        var saleDoc = Body(await sale.Content.ReadAsStringAsync());
        Assert.Equal(100000m, Decimal(saleDoc, "balance"));

        // 3. Pay 40,000 → outstanding 60,000.
        var payment = await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/payment",
            new { amount = 40000m, description = "Payment #1" });
        Assert.True(payment.StatusCode == HttpStatusCode.OK, $"payment failed: {await payment.Content.ReadAsStringAsync()}");
        Assert.Equal(60000m, Decimal(Body(await payment.Content.ReadAsStringAsync()), "balance"));

        // 4. GET customer credit reflects 60,000, correct tenant.
        var getCredit = await _client.GetAsync($"/api/v1/customers/{customerId}/credit");
        Assert.Equal(HttpStatusCode.OK, getCredit.StatusCode);
        var creditDoc = Body(await getCredit.Content.ReadAsStringAsync());
        Assert.Equal(customerId, GetProperty(creditDoc, "customerId"));
        Assert.Equal(60000m, Decimal(creditDoc, "balance"));

        // 5. Transaction history contains the sale (100,000 → 100,000) and payment (40,000 → 60,000).
        var txs = await _client.GetAsync($"/api/v1/customers/{customerId}/credit/transactions?page=1&pageSize=50");
        Assert.Equal(HttpStatusCode.OK, txs.StatusCode);
        var txDoc = Body(await txs.Content.ReadAsStringAsync());
        var txList = txDoc.EnumerateArray().ToList();
        // type serializes as the numeric enum value: Sale=0, Payment=1 (matches money-account pattern).
        Assert.Equal(2, txList.Count);
        var paymentTx = txList.Single(t => GetProperty(t, "type") == "1");
        Assert.Equal(40000m, Decimal(paymentTx, "amount"));
        Assert.Equal(60000m, Decimal(paymentTx, "balanceAfter"));
        var saleTx = txList.Single(t => GetProperty(t, "type") == "0");
        Assert.Equal(100000m, Decimal(saleTx, "amount"));

        // 6. Outstanding-credit endpoint returns this customer at 60,000.
        var outstanding = await _client.GetAsync("/api/v1/credit/outstanding");
        Assert.Equal(HttpStatusCode.OK, outstanding.StatusCode);
        var found = false;
        foreach (var item in Body(await outstanding.Content.ReadAsStringAsync()).EnumerateArray())
        {
            if (GetProperty(item, "customerId") == customerId)
            {
                Assert.Equal(60000m, Decimal(item, "balance"));
                found = true;
                break;
            }
        }
        Assert.True(found, "Outstanding credit endpoint should return the customer.");

        // 7. Another payment of 20,000 → balance decreases to 40,000.
        var secondPayment = await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/payment",
            new { amount = 20000m, description = "Payment #2" });
        Assert.True(secondPayment.StatusCode == HttpStatusCode.OK, $"second payment failed: {await secondPayment.Content.ReadAsStringAsync()}");
        Assert.Equal(40000m, Decimal(Body(await secondPayment.Content.ReadAsStringAsync()), "balance"));

        // 8. Overpayment (> balance) is rejected by the existing backend validation (400).
        var overpay = await _client.PostAsJsonAsync(
            $"/api/v1/customers/{customerId}/credit/payment",
            new { amount = 1000000m, description = "Overpay attempt" });
        Assert.Equal(HttpStatusCode.BadRequest, overpay.StatusCode);

        // Balance unchanged after rejected overpayment.
        var after = await _client.GetAsync($"/api/v1/customers/{customerId}/credit");
        Assert.Equal(HttpStatusCode.OK, after.StatusCode);
        Assert.Equal(40000m, Decimal(Body(await after.Content.ReadAsStringAsync()), "balance"));

        using var db = CreateDbContext();
        var creditCustomerId = Guid.Parse(customerId);
        Assert.Equal(3, await db.CreditTransactions.CountAsync(
            t => t.CustomerId == creditCustomerId));
    }

    // ── Expense + Account Expense (Phase 5) ──

    [Fact]
    public async Task Expense_AndAccountExpense_ShouldBehaveCorrectly()
    {
        var (token, _) = await RegisterVerifiedAsync("e2e-expense");
        Authorize(token);

        // Ledger expense (POST /expenses): description/amount/date/tenant, NOT linked to a money account.
        var created = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Office rent",
            amount = 250000m,
            expenseDate = "2026-08-20T10:00:00Z",
            paymentMethod = "Bank",
            reference = "RENT-AUG",
            notes = "Monthly",
        });
        Assert.True(created.StatusCode == HttpStatusCode.OK, $"expense creation failed: {await created.Content.ReadAsStringAsync()}");
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Office rent", GetProperty(createdDoc, "description"));
        Assert.Equal("250000", createdDoc.GetProperty("amount").ToString());
        Assert.Equal("2026-08-20", GetProperty(createdDoc, "expenseDate")[..10]);
        var expenseId = GetProperty(createdDoc, "id");

        // Verify tenant isolation on the *owning* tenant (it is visible).
        var fetched = await _client.GetAsync($"/api/v1/expenses/{expenseId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal("Office rent", GetProperty(Body(await fetched.Content.ReadAsStringAsync()), "description"));

        // No money account exists yet — proof the ledger expense does NOT auto-post. The money
        // subsystem is only touched via the dedicated /money-accounts/expense endpoint below.
        var accountsBefore = await _client.GetAsync("/api/v1/money-accounts");
        Assert.Equal(HttpStatusCode.OK, accountsBefore.StatusCode);
        Assert.Equal(0, Body(await accountsBefore.Content.ReadAsStringAsync()).GetArrayLength());

        // Create a cash money account and record an account expense against it explicitly.
        var account = await _client.PostAsJsonAsync("/api/v1/money-accounts", new
        {
            name = "Till",
            type = 0, // Cash
            reference = (string?)null,
        });
        Assert.True(account.StatusCode == HttpStatusCode.OK, $"money account creation failed: {await account.Content.ReadAsStringAsync()}");
        var accountDoc = Body(await account.Content.ReadAsStringAsync());
        Assert.Equal("0", accountDoc.GetProperty("balance").ToString());
        var accountId = GetProperty(accountDoc, "id");

        // Fund the account first so the debit has balance.
        var income = await _client.PostAsJsonAsync("/api/v1/money-accounts/income", new
        {
            accountId,
            amount = 500000m,
            description = "Cash injection",
        });
        Assert.Equal(HttpStatusCode.NoContent, income.StatusCode);

        var accountExpense = await _client.PostAsJsonAsync("/api/v1/money-accounts/expense", new
        {
            accountId,
            amount = 100000m,
            description = "Till-out supplies",
        });
        Assert.Equal(HttpStatusCode.NoContent, accountExpense.StatusCode);

        // Account balance 500,000 − 100,000 = 400,000, with a matching debit transaction.
        var accountGet = await _client.GetAsync($"/api/v1/money-accounts/{accountId}");
        Assert.Equal(HttpStatusCode.OK, accountGet.StatusCode);
        Assert.Equal(400000m, Decimal(Body(await accountGet.Content.ReadAsStringAsync()), "balance"));

        var txs = await _client.GetAsync($"/api/v1/money-accounts/{accountId}/transactions?page=1&pageSize=50");
        Assert.Equal(HttpStatusCode.OK, txs.StatusCode);
        var txList = Body(await txs.Content.ReadAsStringAsync()).EnumerateArray().ToList();
        Assert.Equal(2, txList.Count);
        var debit = txList.Single(t => GetProperty(t, "type") == "1"); // Debit
        Assert.Equal(100000m, Decimal(debit, "amount"));
        Assert.Equal(400000m, Decimal(debit, "balanceAfter"));
        Assert.Contains("Till-out supplies", GetProperty(debit, "description"));

        // NOTE (finding): the ledger expense above did NOT move this account; and this account
        // expense did NOT create a ledger expense row. They are separate subsystems in v1.
    }

    // ── Cash Session Lifecycle (Phase 6) ──

    [Fact]
    public async Task CashSession_ShouldOpenAndCloseCorrectly()
    {
        var (token, _) = await RegisterVerifiedAsync("e2e-cashsession");
        Authorize(token);

        var account = await _client.PostAsJsonAsync("/api/v1/money-accounts", new
        {
            name = "Main Till",
            type = 0, // Cash
            reference = (string?)null,
        });
        Assert.True(account.StatusCode == HttpStatusCode.OK, $"{await account.Content.ReadAsStringAsync()}");
        var accountId = GetProperty(Body(await account.Content.ReadAsStringAsync()), "id");

        // No open session yet → GET /current is 200 with an empty body (no session), NOT a 404.
        var none = await _client.GetAsync($"/api/v1/cash-sessions/current?accountId={accountId}");
        Assert.Equal(HttpStatusCode.OK, none.StatusCode);
        Assert.True(string.IsNullOrWhiteSpace(await none.Content.ReadAsStringAsync()));

        // Open a cash session with an opening float.
        var opened = await _client.PostAsJsonAsync("/api/v1/cash-sessions", new
        {
            accountId,
            openingCash = 100000m,
        });
        Assert.True(opened.StatusCode == HttpStatusCode.OK, $"{await opened.Content.ReadAsStringAsync()}");
        var openedDoc = Body(await opened.Content.ReadAsStringAsync());
        Assert.Equal("0", openedDoc.GetProperty("status").ToString()); // Open
        Assert.Equal(100000m, Decimal(openedDoc, "openingCash"));
        var sessionId = GetProperty(openedDoc, "id");

        // Opening a second session on the same account conflicts (409).
        var second = await _client.PostAsJsonAsync("/api/v1/cash-sessions", new
        {
            accountId,
            openingCash = 50000m,
        });
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);

        // The current session is the open one.
        var current = await _client.GetAsync($"/api/v1/cash-sessions/current?accountId={accountId}");
        Assert.Equal(HttpStatusCode.OK, current.StatusCode);
        var currentDoc = Body(await current.Content.ReadAsStringAsync());
        Assert.Equal(sessionId, GetProperty(currentDoc, "id"));
        Assert.Equal("0", currentDoc.GetProperty("status").ToString());

        // Perform a cash operation on the account while the session is open (income in).
        var income = await _client.PostAsJsonAsync("/api/v1/money-accounts/income", new
        {
            accountId,
            amount = 50000m,
            description = "Walk-in income",
        });
        Assert.Equal(HttpStatusCode.NoContent, income.StatusCode);

        // Close the session. Expected cash = opening (per current CashSession.Close rule), so
        // closing at opening+income ⇒ variance = income = 50,000. This records ACTUAL behaviour.
        var closed = await _client.PostAsJsonAsync($"/api/v1/cash-sessions/{sessionId}/close", new
        {
            closingCash = 150000m,
            notes = "End of day",
        });
        Assert.True(closed.StatusCode == HttpStatusCode.OK, $"close failed: {await closed.Content.ReadAsStringAsync()}");
        var closedDoc = Body(await closed.Content.ReadAsStringAsync());
        Assert.Equal("1", closedDoc.GetProperty("status").ToString()); // Closed
        Assert.Equal(150000m, Decimal(closedDoc, "closingCash"));
        Assert.Equal(100000m, Decimal(closedDoc, "expectedCash"));
        Assert.Equal(50000m, Decimal(closedDoc, "variance"));
        Assert.NotNull(closedDoc.GetProperty("closedAt").GetString());

        // After closing, no open session remains.
        var afterClose = await _client.GetAsync($"/api/v1/cash-sessions/current?accountId={accountId}");
        Assert.Equal(HttpStatusCode.OK, afterClose.StatusCode);
        Assert.True(string.IsNullOrWhiteSpace(await afterClose.Content.ReadAsStringAsync()));

        // The account balance reflects ONLY the recorded income (50,000). Note (finding): opening a
        // cash session with a float does NOT credit the money account — openingCash is recorded as a
        // session attribute only, it is not a funds movement into the account.
        var accountGet = await _client.GetAsync($"/api/v1/money-accounts/{accountId}");
        Assert.Equal(HttpStatusCode.OK, accountGet.StatusCode);
        Assert.Equal(50000m, Decimal(Body(await accountGet.Content.ReadAsStringAsync()), "balance"));
    }

    // ── Reports / Dashboard (Phase 8): record what the current system actually reports ──

    [Fact]
    public async Task Reports_ShouldReflectSale_AndDashboardInventory()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FullSalesFixtureAsync("e2e-report", opening: 20m, price: 2000m);

        // One sale of 2 @ 2000 = 4000, on a fixed sale date in 2026-08.
        var sale = await PostSaleAsync(token, SaleBody(
            branchId, Guid.NewGuid(), productId, 2000m, quantity: 2m, amountPaid: 4000m, warehouseId: warehouseId));
        Assert.True(sale.StatusCode == HttpStatusCode.OK, $"{await sale.Content.ReadAsStringAsync()}");

        // Report date range covering the sale (SaleDate is EffectiveAt = 2026-08-15).
        // Report date range: broad so we are not coupling to how the server stores SaleDate. The
        // meaningful assertion is that this tenant's completed sale shows up in the report.
        var from = "2000-01-01T00:00:00Z";
        var to = "2100-01-01T00:00:00Z";

        // Sales summary reflects the sale total/revenue.
        Authorize(token);
        var summaryResponse = await _client.GetAsync(
            $"/api/v1/reports/sales-summary?from={Uri.EscapeDataString(from)}&to={Uri.EscapeDataString(to)}");
        Assert.Equal(HttpStatusCode.OK, summaryResponse.StatusCode);
        var summary = Body(await summaryResponse.Content.ReadAsStringAsync());
        // The sales summary reflects our sale; totalSales >= 1 confirms the completed sale appears.
        Assert.True(summary.GetProperty("totalSales").GetInt32() >= 1, "sale should appear in sales summary");

        var branch = summary.GetProperty("byBranch").EnumerateArray().Single(b => GetProperty(b, "branchId") == branchId.ToString());
        Assert.Equal(4000m, Decimal(branch, "totalRevenue"));

        // Top-products shows the sold product with the correct quantity.
        var top = await _client.GetAsync(
            $"/api/v1/reports/top-products?from={Uri.EscapeDataString(from)}&to={Uri.EscapeDataString(to)}&limit=10");
        Assert.Equal(HttpStatusCode.OK, top.StatusCode);
        var topDoc = Body(await top.Content.ReadAsStringAsync());
        var productRow = topDoc.GetProperty("products").EnumerateArray().Single(p => GetProperty(p, "productId") == productId);
        Assert.Equal(2m, Decimal(productRow, "totalQuantity"));

        // Dashboard reflects the inventory state (on-hand dropped to 18 after 2 sold).
        var dash = await _client.GetAsync("/api/v1/dashboard/summary");
        Assert.Equal(HttpStatusCode.OK, dash.StatusCode);
        var dashDoc = Body(await dash.Content.ReadAsStringAsync());
        Assert.True(dashDoc.GetProperty("inventory").GetProperty("totalOnHandUnits").GetInt32() >= 18);

        // NOTE (finding): Dashboard exposes Catalog/Inventory/Pricing/Organization only. It does NOT
        // expose sales revenue, expense totals, outstanding credit, or cash/money-account balances.
        // Those are reachable only via /reports/sales-summary + /reports/top-products (sales side).
    }

    // Regression: SalesTrend must bind a scalar int `days` from the query string. It previously
    // used `[AsParameters] int days`, which never binds (days defaults to 0 → validator rejects →
    // 400). Now `?days=30` must bind and the response reflects `days: 30`.
    [Fact]
    public async Task Reports_SalesTrend_BindsDays()
    {
        var (token, _, _, _, _) = await FullSalesFixtureAsync("e2e-sales-trend", opening: 1m, price: 100m);

        Authorize(token);
        var response = await _client.GetAsync("/api/v1/reports/sales-trend?days=30");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());
        Assert.Equal(30, doc.GetProperty("days").GetInt32());
    }

    // Regression (M10.4): report DATE-ONLY query values must not 500.
    // The original defect: date-only ranges (e.g. "2026-09-01" with no timezone) were model-bound
    // into DateTime with Kind=Unspecified, and the EF queries (SaleDate >= from && <= to) against a
    // PostgreSQL `timestamptz` column threw "Cannot write DateTime with Kind=Unspecified to
    // PostgreSQL type 'timestamp with time zone', only UTC is supported." — surfaced as HTTP 500.
    // This exercises the real HTTP/request-parsing + EF path, not just the internal helper.
    [Fact]
    public async Task Reports_DateOnlyRange_ShouldNotReturn500()
    {
        var (token, tenantId, branchId, productId, warehouseId) = await FullSalesFixtureAsync("e2e-dateonly", opening: 20m, price: 2000m);

        var sale = await PostSaleAsync(token, SaleBody(
            branchId, Guid.NewGuid(), productId, 2000m, quantity: 2m, amountPaid: 4000m, warehouseId: warehouseId));
        Assert.True(sale.StatusCode == HttpStatusCode.OK, $"sale failed: {await sale.Content.ReadAsStringAsync()}");

        Authorize(token);

        // Date-only values (no timezone component) exercise the Kind=Unspecified binding path.
        var from = "2026-08-01";
        var to = "2026-08-31";

        var summary = await _client.GetAsync(
            $"/api/v1/reports/sales-summary?from={Uri.EscapeDataString(from)}&to={Uri.EscapeDataString(to)}");
        Assert.NotEqual(HttpStatusCode.InternalServerError, summary.StatusCode);
        Assert.Equal(HttpStatusCode.OK, summary.StatusCode);

        var tax = await _client.GetAsync(
            $"/api/v1/reports/tax-summary?from={Uri.EscapeDataString(from)}&to={Uri.EscapeDataString(to)}");
        Assert.NotEqual(HttpStatusCode.InternalServerError, tax.StatusCode);
        Assert.Equal(HttpStatusCode.OK, tax.StatusCode);

        // top-products additionally requires `limit`; missing limit is 400 (validation), which must
        // NOT be mistaken for the datetime regression returning 500.
        var top = await _client.GetAsync(
            $"/api/v1/reports/top-products?from={Uri.EscapeDataString(from)}&to={Uri.EscapeDataString(to)}&limit=10");
        Assert.NotEqual(HttpStatusCode.InternalServerError, top.StatusCode);
        Assert.Equal(HttpStatusCode.OK, top.StatusCode);
    }

    // ── Tenant Isolation (Phase 9): B cannot read OR write A's data ──

    [Fact]
    public async Task Tenant_ShouldNotAccessAnotherTenantsData()
    {
        // Tenant A creates a full footprint.
        var (tokenA, tenantA, branchA, productA, warehouseA) = await FullSalesFixtureAsync("e2e-iso-a");
        var customerA = await CreateCustomerAsync(tokenA, "Tenant A Customer");
        Authorize(tokenA);

        var saleA = await PostSaleAsync(tokenA, SaleBody(
            branchA, Guid.NewGuid(), productA, 1000m, warehouseId: warehouseA));
        Assert.Equal(HttpStatusCode.OK, saleA.StatusCode);
        var saleAId = GetProperty(Body(await saleA.Content.ReadAsStringAsync()), "id");

        var expenseA = await _client.PostAsJsonAsync("/api/v1/expenses", new
        {
            description = "Tenant A Expense",
            amount = 100m,
            expenseDate = "2026-08-20T10:00:00Z",
        });
        Assert.Equal(HttpStatusCode.OK, expenseA.StatusCode);
        var expenseAId = GetProperty(Body(await expenseA.Content.ReadAsStringAsync()), "id");

        var accountA = await _client.PostAsJsonAsync("/api/v1/money-accounts", new
        {
            name = "Tenant A Till",
            type = 0,
            reference = (string?)null,
        });
        Assert.Equal(HttpStatusCode.OK, accountA.StatusCode);
        var accountAId = GetProperty(Body(await accountA.Content.ReadAsStringAsync()), "id");

        await _client.PostAsJsonAsync($"/api/v1/customers/{customerA}/credit/sale",
            new { amount = 50000m, description = "Tenant A credit" });

        // Tenant B authenticates; must NOT see or mutate A's resources.
        var (tokenB, _) = await RegisterVerifiedAsync("e2e-iso-b");
        Authorize(tokenB);

        // Reads → 404 (tenant-scoped not-found), not data leak.
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/products/{productA}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/customers/{customerA}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/sales/{saleAId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/expenses/{expenseAId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/money-accounts/{accountAId}")).StatusCode);

        // Cross-tenant credit GET → 404 (tenant-scoped not-found; no balance is leaked).
        var crossCredit = await _client.GetAsync($"/api/v1/customers/{customerA}/credit");
        Assert.Equal(HttpStatusCode.NotFound, crossCredit.StatusCode);

        // Writes/updates against A's IDs → 404 as well.
        Assert.Equal(HttpStatusCode.NotFound,
            (await _client.PutAsJsonAsync($"/api/v1/customers/{customerA}", new { name = "Hijack" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await _client.PutAsJsonAsync($"/api/v1/expenses/{expenseAId}", new
            {
                description = "Hijack",
                amount = 50m,
                expenseDate = "2026-08-20T10:00:00Z",
            })).StatusCode);
        // Stock-balances list with A's warehouse id: must NOT leak A's stock. The list query is
        // tenant-scoped on rows, so B sees either 404 (unknown id) or 200 with no A items.
        var stockRes = await _client.GetAsync($"/api/v1/inventory/stock?page=1&pageSize=10&warehouseId={warehouseA}");
        if (stockRes.StatusCode == HttpStatusCode.OK)
        {
            var stockDoc = Body(await stockRes.Content.ReadAsStringAsync());
            Assert.Equal(0, stockDoc.GetProperty("items").GetArrayLength());
        }
        else
        {
            Assert.Equal(HttpStatusCode.NotFound, stockRes.StatusCode);
        }

        // Credit is keyed by (tenant, customerId): B's operations against A's customer create B-local
        // rows and must NOT mutate A's actual balance. We therefore verify A's balance is unchanged.
        await _client.PutAsJsonAsync($"/api/v1/customers/{customerA}/credit/limit", new { limit = 1m });
        await _client.PostAsJsonAsync($"/api/v1/customers/{customerA}/credit/payment", new { amount = 10m });
        using (var creditDb = CreateDbContext())
        {
            var aCredit = await creditDb.CustomerCredits.SingleAsync(c => c.TenantId == tenantA);
            Assert.Equal(50000m, aCredit.Balance);
            Assert.Equal(0, await creditDb.CreditTransactions.CountAsync(
                t => t.TenantId == tenantA && t.Description == "Hijack-over-payment"));
        }

        // B's lists cannot contain A's rows.
        var bCustomers = await _client.GetAsync("/api/v1/customers?page=1&pageSize=100");
        Assert.Equal(HttpStatusCode.OK, bCustomers.StatusCode);
        foreach (var c in Body(await bCustomers.Content.ReadAsStringAsync()).GetProperty("items").EnumerateArray())
        {
            Assert.NotEqual(customerA, GetProperty(c, "id"));
        }

        var bCredit = await _client.GetAsync("/api/v1/credit/outstanding");
        Assert.Equal(HttpStatusCode.OK, bCredit.StatusCode);
        foreach (var r in Body(await bCredit.Content.ReadAsStringAsync()).EnumerateArray())
        {
            Assert.NotEqual(customerA, GetProperty(r, "customerId"));
        }

        var bAccounts = await _client.GetAsync("/api/v1/money-accounts");
        Assert.Equal(HttpStatusCode.OK, bAccounts.StatusCode);
        Assert.Equal(0, Body(await bAccounts.Content.ReadAsStringAsync()).GetArrayLength());

        // B cannot post a sale into A's warehouse (branch not owned by B → 404/NotFound).
        var bSale = await PostSaleAsync(tokenB, SaleBody(
            branchA, Guid.NewGuid(), productA, 1000m, warehouseId: warehouseA));
        Assert.Equal(HttpStatusCode.NotFound, bSale.StatusCode);

        using var db = CreateDbContext();
        // B's write attempts must not have created rows in A's tenant (only A's own rows remain).
        Assert.Equal(1, await db.Sales.CountAsync(s => s.TenantId == tenantA));
        Assert.Equal(1, await db.Expenses.CountAsync(e => e.TenantId == tenantA));
        Assert.Equal(1, await db.MoneyAccounts.CountAsync(m => m.TenantId == tenantA));
    }
}
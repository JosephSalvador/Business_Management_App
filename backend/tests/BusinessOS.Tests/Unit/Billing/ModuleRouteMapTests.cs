using BusinessOS.Application.Features.Billing;
using BusinessOS.Domain.Billing;

namespace BusinessOS.Tests.Unit.Billing;

public sealed class ModuleRouteMapTests
{
    [Theory]
    [InlineData("/api/v1/sales", "pos")]
    [InlineData("/api/v1/receipts/9f1c", "pos")]
    [InlineData("/api/v1/products", "inventory")]
    [InlineData("/api/v1/warehouses", "inventory")]
    [InlineData("/api/v1/inventory/adjustments", "inventory")]
    [InlineData("/api/v1/suppliers", "purchasing")]
    [InlineData("/api/v1/purchase-orders", "purchasing")]
    [InlineData("/api/v1/supplier-bills", "purchasing")]
    [InlineData("/api/v1/accounts", "accounting")]
    [InlineData("/api/v1/journal-entries", "accounting")]
    [InlineData("/api/v1/expenses", "finance")]
    [InlineData("/api/v1/money-accounts", "finance")]
    [InlineData("/api/v1/cash-sessions", "finance")]
    [InlineData("/api/v1/price-lists", "pricing")]
    [InlineData("/api/v1/pricing/resolve", "pricing")]
    [InlineData("/api/v1/customers", "crm")]
    [InlineData("/api/v1/credit/outstanding", "credit")]
    [InlineData("/api/v1/invoices", "invoicing")]
    [InlineData("/api/v1/reports/trial-balance", "reports")]
    public void Match_ResolvesOwningModule(string path, string moduleId)
    {
        var module = ModuleRouteMap.Match(path);

        Assert.NotNull(module);
        Assert.Equal(moduleId, module!.Id);
    }

    [Fact]
    public void Match_CustomerCreditSubresource_BelongsToCreditNotCrm()
    {
        var module = ModuleRouteMap.Match("/api/v1/customers/2b3c/credit/payment");

        Assert.NotNull(module);
        Assert.Equal("credit", module!.Id);
        Assert.Equal(FeatureKeys.Credit, module.FeatureKey);
    }

    [Fact]
    public void Match_CustomersRoot_BelongsToCrm()
    {
        Assert.Equal("crm", ModuleRouteMap.Match("/api/v1/customers")!.Id);
        Assert.Equal("crm", ModuleRouteMap.Match("/api/v1/customers/2b3c")!.Id);
    }

    [Theory]
    [InlineData("/api/v1/auth/login")]
    [InlineData("/api/v1/billing/subscription")]
    [InlineData("/api/v1/capabilities")]
    [InlineData("/api/v1/dashboard")]
    [InlineData("/api/v1/organization/branches")]
    [InlineData("/api/v1/features/pos.enabled")]
    [InlineData("/api/v1/admin/tenants")]
    [InlineData("/")]
    [InlineData("")]
    [InlineData(null)]
    public void Match_AlwaysAvailableRoutes_ReturnNoModule(string? path)
    {
        Assert.Null(ModuleRouteMap.Match(path));
    }

    [Fact]
    public void Match_IgnoresApiVersionSegment()
    {
        Assert.Equal("invoicing", ModuleRouteMap.Match("/api/v2/invoices")!.Id);
        Assert.Equal("pos", ModuleRouteMap.Match("/sales")!.Id);
    }

    [Fact]
    public void EveryModule_UsesTheBackstopFlagForPosAndInventory()
    {
        var backstop = ModuleRouteMap.All.Where(m => m.IsBackstop).Select(m => m.Id).ToArray();

        Assert.Equal(new[] { "inventory", "pos" }, backstop.Order().ToArray());
        Assert.False(ModuleRouteMap.ByModuleId("invoicing")!.IsBackstop);
    }

    [Fact]
    public void ByModuleId_AndByFeatureKey_ResolveTheSameModule()
    {
        foreach (var module in ModuleRouteMap.All)
        {
            Assert.Equal(module.Id, ModuleRouteMap.ByModuleId(module.Id)!.Id);
            Assert.Equal(module.Id, ModuleRouteMap.ByFeatureKey(module.FeatureKey)!.Id);
        }

        Assert.Null(ModuleRouteMap.ByModuleId("nope"));
        Assert.Null(ModuleRouteMap.ByFeatureKey("nope.enabled"));
    }
}

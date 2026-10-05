using BusinessOS.Application.Features.Billing;
using BusinessOS.Domain.Billing;

namespace BusinessOS.Tests.Unit.Billing;

public sealed class SubscriptionEntitlementGuardTests
{
    private static readonly DateTime Now = new(2026, 9, 20, 12, 0, 0, DateTimeKind.Utc);

    private static SubscriptionEntitlement Entitlement(
        AccessLevel accessLevel,
        SubscriptionStatus status,
        params string[] keys)
        => new(
            Status: status,
            AccessLevel: accessLevel,
            PlanCode: "Pro",
            EffectiveFeatureKeys: keys,
            NextDueUtc: accessLevel == AccessLevel.Full ? Now.AddDays(10) : null,
            HasOpenInvoice: false,
            MaxBranches: null,
            MaxUsers: null,
            MaxProducts: null,
            EvaluatedAtUtc: Now,
            PlanFeatureKeys: keys,
            Packages: Array.Empty<string>());

    [Fact]
    public void EnsureFeature_WhenKeyPresent_ReturnsNull()
    {
        var entitlement = Entitlement(
            AccessLevel.Full, SubscriptionStatus.Trial, FeatureKeys.Pos, FeatureKeys.Inventory);

        Assert.Null(SubscriptionEntitlementGuard.EnsureFeature(entitlement, FeatureKeys.Inventory));
    }

    [Fact]
    public void EnsureFeature_WhenKeyMissingAndFullAccess_ReturnsModuleDisabled()
    {
        var entitlement = Entitlement(AccessLevel.Full, SubscriptionStatus.Trial, FeatureKeys.Pos);

        var error = SubscriptionEntitlementGuard.EnsureFeature(entitlement, FeatureKeys.Invoicing);

        Assert.NotNull(error);
        Assert.Equal("ModuleDisabled", error!.Value.Code);
        Assert.Contains("Invoicing", error.Value.Message);
    }

    [Fact]
    public void EnsureFeature_WhenKeyMissingInDebt_ReturnsBillingRequired()
    {
        var entitlement = Entitlement(
            AccessLevel.PosAndInventory, SubscriptionStatus.Debt, FeatureKeys.Pos, FeatureKeys.Inventory);

        var error = SubscriptionEntitlementGuard.EnsureFeature(entitlement, FeatureKeys.Invoicing);

        Assert.NotNull(error);
        Assert.Equal("BillingRequired", error!.Value.Code);
    }

    [Fact]
    public void EnsureFeature_UnknownFeatureKey_FallsBackToGenericMessage()
    {
        var entitlement = Entitlement(AccessLevel.Full, SubscriptionStatus.Trial, FeatureKeys.Pos);

        var error = SubscriptionEntitlementGuard.EnsureFeature(entitlement, "mystery.enabled");

        Assert.NotNull(error);
        Assert.Equal("ModuleDisabled", error!.Value.Code);
        Assert.Equal("This feature is not enabled for this workspace.", error.Value.Message);
    }

    [Fact]
    public void EnsureWithinLimit_NullLimitNeverBlocks()
    {
        Assert.Null(SubscriptionEntitlementGuard.EnsureWithinLimit(limit: null, currentCount: 100, resource: "products"));
        Assert.Null(SubscriptionEntitlementGuard.EnsureWithinLimit(limit: null, currentCount: 9_999, resource: "things"));
    }

    [Fact]
    public void EnsureWithinLimit_AllowsCountAtOrBelowLimit()
    {
        Assert.Null(SubscriptionEntitlementGuard.EnsureWithinLimit(limit: 2, currentCount: 2, resource: "things"));
        Assert.Null(SubscriptionEntitlementGuard.EnsureWithinLimit(limit: 5, currentCount: 5, resource: "products"));
        Assert.Null(SubscriptionEntitlementGuard.EnsureWithinLimit(limit: 5, currentCount: 4, resource: "products"));
    }

    [Fact]
    public void EnsureWithinLimit_BlocksCountAboveLimit()
    {
        var error = SubscriptionEntitlementGuard.EnsureWithinLimit(
            limit: 2, currentCount: 3, resource: "products");

        Assert.NotNull(error);
        Assert.Equal("QuotaExceeded", error!.Value.Code);
        Assert.Contains("2 products", error.Value.Message);
    }
}

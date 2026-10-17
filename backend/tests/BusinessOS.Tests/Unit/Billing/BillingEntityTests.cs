using BusinessOS.Application.Features.Billing;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Events;

namespace BusinessOS.Tests.Unit.Billing;

public sealed class SubscriptionAccessEvaluatorTests
{
    private static readonly DateTime Now = new(2026, 9, 1, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Evaluate_PaidUntilInFuture_ReturnsActiveFullAccess()
    {
        var result = SubscriptionAccessEvaluator.Evaluate(
            SubscriptionStatus.Trial,
            trialEndedAtUtc: Now.AddDays(-5),
            paidUntilUtc: Now.AddDays(10),
            nowUtc: Now);

        Assert.Equal(SubscriptionStatus.Active, result.Status);
        Assert.Equal(AccessLevel.Full, result.AccessLevel);
        Assert.Equal(Now.AddDays(10), result.NextDueUtc);
    }

    [Fact]
    public void Evaluate_InsideTrial_ReturnsTrialFullAccess()
    {
        var result = SubscriptionAccessEvaluator.Evaluate(
            SubscriptionStatus.Trial,
            trialEndedAtUtc: Now.AddDays(5),
            paidUntilUtc: null,
            nowUtc: Now);

        Assert.Equal(SubscriptionStatus.Trial, result.Status);
        Assert.Equal(AccessLevel.Full, result.AccessLevel);
        Assert.Equal(Now.AddDays(5), result.NextDueUtc);
    }

    [Fact]
    public void Evaluate_AfterTrialWithoutPayment_DerivesDebtRegardlessOfStoredStatus()
    {
        // Stored status says Active (a stale report state) but the dates are decisive.
        var result = SubscriptionAccessEvaluator.Evaluate(
            SubscriptionStatus.Active,
            trialEndedAtUtc: Now.AddDays(-20),
            paidUntilUtc: Now.AddDays(-1),
            nowUtc: Now);

        Assert.Equal(SubscriptionStatus.Debt, result.Status);
        Assert.Equal(AccessLevel.PosAndInventory, result.AccessLevel);
        Assert.Null(result.NextDueUtc);
    }

    [Fact]
    public void EffectivePeriodStart_UsesPaidUntilWhenInFuture_OtherwiseNow()
    {
        var paidInFuture = SubscriptionAccessEvaluator.EffectivePeriodStart(Now.AddDays(3), Now);
        Assert.Equal(Now.AddDays(3), paidInFuture);

        var lapsed = SubscriptionAccessEvaluator.EffectivePeriodStart(Now.AddDays(-1), Now);
        Assert.Equal(Now, lapsed);

        var neverPaid = SubscriptionAccessEvaluator.EffectivePeriodStart(null, Now);
        Assert.Equal(Now, neverPaid);
    }
}

public sealed class SubscriptionTests
{
    private static readonly DateTime Now = new(2026, 9, 1, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void StartTrial_SetsProPlanTrialWindowAndRaisesEvent()
    {
        var subscription = Subscription.StartTrial(Guid.NewGuid(), nowUtc: Now);

        Assert.Equal(SubscriptionAccessEvaluator.DefaultPlanCode, subscription.PlanCode);
        Assert.Equal(SubscriptionStatus.Trial, subscription.Status);
        Assert.Equal(Now.Add(SubscriptionAccessEvaluator.DefaultTrialLength), subscription.TrialEndedAtUtc);
        Assert.Null(subscription.PaidUntilUtc);
        Assert.Single(subscription.DomainEvents.OfType<SubscriptionTrialStartedEvent>());
    }

    [Fact]
    public void StartTrial_AcceptsCustomPlanAndLength()
    {
        var subscription = Subscription.StartTrial(
            Guid.NewGuid(),
            planCode: "Free",
            trialLength: TimeSpan.FromDays(7),
            nowUtc: Now);

        Assert.Equal("Free", subscription.PlanCode);
        Assert.Equal(Now.AddDays(7), subscription.TrialEndedAtUtc);
    }

    [Fact]
    public void Paid_ExtendsPaidUntilFromEffectiveStart()
    {
        var subscription = Subscription.StartTrial(Guid.NewGuid(), nowUtc: Now);
        subscription.Paid(Now, TimeSpan.FromDays(30), nowUtc: Now);

        Assert.Equal(Now.AddDays(30), subscription.PaidUntilUtc);
    }

    [Fact]
    public void Paid_WithEarlierEffectiveStart_DoesNotShrinkWindow()
    {
        var subscription = Subscription.StartTrial(Guid.NewGuid(), nowUtc: Now);
        subscription.Paid(Now, TimeSpan.FromDays(30), nowUtc: Now);
        subscription.Paid(Now, TimeSpan.FromDays(7), nowUtc: Now);

        Assert.Equal(Now.AddDays(30), subscription.PaidUntilUtc);
    }

    [Fact]
    public void Paid_WhileInDebt_MarksActiveAndRaisesEvent()
    {
        var subscription = Subscription.StartTrial(Guid.NewGuid(), nowUtc: Now.AddDays(-20));
        subscription.MarkDebt(Now);
        Assert.Equal(SubscriptionStatus.Debt, subscription.Status);

        subscription.Paid(Now, TimeSpan.FromDays(30), nowUtc: Now);
        Assert.Equal(SubscriptionStatus.Active, subscription.Status);
        Assert.Contains(subscription.DomainEvents, e => e is SubscriptionActivatedEvent);
    }

    [Fact]
    public void MarkDebt_IsIdempotent()
    {
        var subscription = Subscription.StartTrial(Guid.NewGuid(), nowUtc: Now.AddDays(-20));
        subscription.MarkDebt(Now);
        subscription.MarkDebt(Now);

        Assert.Equal(SubscriptionStatus.Debt, subscription.Status);
        Assert.Single(subscription.DomainEvents.OfType<SubscriptionDebtTransitionEvent>());
    }
}

public sealed class VoucherTests
{
    [Fact]
    public void Create_AcceptsValidValueDaysAndNormalizesCode()
    {
        var voucher = Voucher.Create(null, null, "abcd-efgh-jkLM", 30);
        Assert.Equal("ABCD-EFGH-JKLM", voucher.Code);
        Assert.Equal(VoucherStatus.Issued, voucher.Status);
    }

    [Fact]
    public void Create_RejectsOutOfRangeValueDays()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => Voucher.Create(null, null, "TEST-TEST-TEST", 0));
        Assert.Throws<ArgumentOutOfRangeException>(() => Voucher.Create(null, null, "TEST-TEST-TEST", 366));
    }

    [Fact]
    public void Redeem_MarksRedeemedWithTenantAndRaisesEvent()
    {
        var tenantId = Guid.NewGuid();
        var voucher = Voucher.Create(null, null, "AAA1-BBB2-CCC3", 30);
        voucher.Redeem(tenantId, new DateTime(2026, 9, 1, 12, 0, 0, DateTimeKind.Utc));

        Assert.Equal(VoucherStatus.Redeemed, voucher.Status);
        Assert.Equal(tenantId, voucher.RedeemedByTenantId);
        Assert.IsType<VoucherRedeemedEvent>(voucher.DomainEvents.Single());
    }

    [Fact]
    public void Redeem_Twice_Throws()
    {
        var voucher = Voucher.Create(null, null, "AAA1-BBB2-CCC3", 30);
        voucher.Redeem(Guid.NewGuid());
        Assert.Throws<InvalidOperationException>(() => voucher.Redeem(Guid.NewGuid()));
    }

    [Fact]
    public void Redeem_Expired_Throws()
    {
        var now = new DateTime(2026, 9, 1, 12, 0, 0, DateTimeKind.Utc);
        var voucher = Voucher.Create(null, null, "AAA1-BBB2-CCC3", 30, expiresAtUtc: now.AddDays(-1));
        Assert.Throws<InvalidOperationException>(() => voucher.Redeem(Guid.NewGuid(), now));
    }

    [Fact]
    public void VoucherCodes_Generate_ProducesReadableGroups()
    {
        for (var i = 0; i < 100; i++)
        {
            var code = VoucherCodes.Generate();
            Assert.Matches(@"^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$", code);
        }
    }

    [Theory]
    [InlineData("test-test-test", "TEST-TEST-TEST")]
    [InlineData("  TEST-TEST-TEST  ", "TEST-TEST-TEST")]
    [InlineData("abc", "ABC")]
    public void VoucherCodes_Normalize_TrimsAndUpperCases(string input, string expected)
        => Assert.Equal(expected, VoucherCodes.Normalize(input));

    [Fact]
    public void VoucherCodes_Generate_IsUnambiguousForHumans()
    {
        // The alphabet excludes 0/O/1/I which are easy to misread over the phone.
        var code = VoucherCodes.Generate();
        Assert.DoesNotContain("0", code);
        Assert.DoesNotContain("O", code);
        Assert.DoesNotContain("1", code);
        Assert.DoesNotContain("I", code);
    }

    [Fact]
    public void VoucherCodes_GeneratedCodes_AlwaysPassChecksum()
    {
        for (var i = 0; i < 50; i++)
        {
            var code = VoucherCodes.Generate();
            Assert.True(VoucherCodes.IsValidChecksum(code), $"Generated code '{code}' failed its own checksum.");
        }
    }

    [Fact]
    public void VoucherCodes_TamperedCode_FailsChecksum()
    {
        var validCode = VoucherCodes.Generate();
        Assert.True(VoucherCodes.IsValidChecksum(validCode));

        // Tamper with the last character (the check-digit)
        var clean = validCode.Replace("-", string.Empty);
        var tampered = clean[..^1] + (clean[^1] == 'A' ? 'B' : 'A');
        Assert.False(VoucherCodes.IsValidChecksum(tampered));
    }

    [Fact]
    public void Voucher_TargetTenantBinding_Enforced()
    {
        var targetTenant = Guid.NewGuid();
        var wrongTenant = Guid.NewGuid();
        var code = VoucherCodes.Generate();
        var voucher = Voucher.Create(null, null, code, 30, targetTenantId: targetTenant);

        // Wrong tenant fails
        Assert.Throws<InvalidOperationException>(() => voucher.Redeem(wrongTenant));

        // Correct tenant succeeds
        voucher.Redeem(targetTenant);
        Assert.Equal(VoucherStatus.Redeemed, voucher.Status);
        Assert.Equal(targetTenant, voucher.RedeemedByTenantId);
    }

    [Fact]
    public void Plan_Update_AppliesDynamicChanges()
    {
        var plan = Plan.Create("test-pkg", "Old Name", 10000m, "TZS", new[] { "pos.enabled" }, isPackage: true);
        plan.Update(
            "New Package Name",
            25000m,
            "TZS",
            new[] { "pos.enabled", "invoicing.enabled" },
            maxBranches: 2,
            maxUsers: 5,
            maxProducts: 2000,
            isPackage: true);

        Assert.Equal("New Package Name", plan.Name);
        Assert.Equal(25000m, plan.MonthlyPrice);
        Assert.Contains("invoicing.enabled", plan.FeatureKeys);
        Assert.Equal(2, plan.MaxBranches);
    }

    [Fact]
    public void Subscription_ExtendTrial_And_ChangePlan_Succeed()
    {
        var tenantId = Guid.NewGuid();
        var sub = Subscription.StartTrial(tenantId, "Pro", TimeSpan.FromDays(14));
        var initialEnd = sub.TrialEndedAtUtc;

        sub.ExtendTrial(TimeSpan.FromDays(7));
        Assert.True(sub.TrialEndedAtUtc > initialEnd);

        sub.ChangePlan("Scale");
        Assert.Equal("Scale", sub.PlanCode);
    }
}

public sealed class InvoiceTests
{
    private static readonly DateTime Now = new(2026, 9, 1, 12, 0, 0, DateTimeKind.Utc);

    private static Plan ProPlan() => Plan.Seed(
        "Pro", "Pro", 25_000m, "TZS", FeatureKeys.All);

    [Fact]
    public void CreateRenewal_SetsFieldsRaisesIssuedEvent()
    {
        var subscriptionId = Guid.NewGuid();
        var invoice = Invoice.CreateRenewal(
            Guid.NewGuid(), "INV-2026-000001", ProPlan(), subscriptionId,
            Now, Now.AddMonths(1), Now);

        Assert.Equal(InvoiceStatus.Open, invoice.Status);
        Assert.Equal(25_000m, invoice.Amount);
        Assert.Equal("TZS", invoice.Currency);
        Assert.Contains("Pro", invoice.Description, StringComparison.Ordinal);
        Assert.IsType<InvoiceIssuedEvent>(invoice.DomainEvents.Single());
    }

    [Fact]
    public void CreateRenewal_RejectsInvertedPeriod()
    {
        Assert.Throws<ArgumentException>(() => Invoice.CreateRenewal(
            Guid.NewGuid(), "INV-1", ProPlan(), Guid.NewGuid(),
            Now.AddMonths(1), Now, Now));
    }

    [Fact]
    public void MarkPaid_SetsReferenceAndStatus()
    {
        var invoice = Invoice.CreateRenewal(
            Guid.NewGuid(), "INV-2026-000001", ProPlan(), Guid.NewGuid(),
            Now, Now.AddMonths(1), Now);
        var confirmedBy = Guid.NewGuid();

        invoice.MarkPaid("AAAA-BBBB-CCCC", confirmedBy, Now);

        Assert.Equal(InvoiceStatus.Paid, invoice.Status);
        Assert.Equal("AAAA-BBBB-CCCC", invoice.Reference);
        Assert.Equal(confirmedBy, invoice.ConfirmedByUserId);
        Assert.Equal(Now, invoice.PaidAtUtc);
        Assert.IsType<InvoicePaidEvent>(invoice.DomainEvents.Last());
    }

    [Fact]
    public void MarkPaid_OnPaidOrCancelledInvoice_Throws()
    {
        var paid = Invoice.CreateRenewal(
            Guid.NewGuid(), "INV-1", ProPlan(), Guid.NewGuid(), Now, Now.AddMonths(1), Now);
        paid.MarkPaid("ref");
        Assert.Throws<InvalidOperationException>(() => paid.MarkPaid("ref2"));

        var cancelled = Invoice.CreateRenewal(
            Guid.NewGuid(), "INV-2", ProPlan(), Guid.NewGuid(), Now, Now.AddMonths(1), Now);
        cancelled.Cancel();
        Assert.Throws<InvalidOperationException>(() => cancelled.MarkPaid("ref2"));
    }

    [Fact]
    public void MarkPaid_RequiresReference()
    {
        var invoice = Invoice.CreateRenewal(
            Guid.NewGuid(), "INV-1", ProPlan(), Guid.NewGuid(), Now, Now.AddMonths(1), Now);
        Assert.Throws<ArgumentException>(() => invoice.MarkPaid("  "));
    }

    [Fact]
    public void Cancel_OnlyAffectsOpenInvoice()
    {
        var invoice = Invoice.CreateRenewal(
            Guid.NewGuid(), "INV-1", ProPlan(), Guid.NewGuid(), Now, Now.AddMonths(1), Now);
        invoice.Cancel();
        Assert.Equal(InvoiceStatus.Cancelled, invoice.Status);
        Assert.Throws<InvalidOperationException>(() => invoice.Cancel());
    }
}
using BusinessOS.Domain.Sales;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class TaxEntitiesTests
{
    private static readonly DateTime OnDate = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void TaxCategory_NormalizesCodeAndName()
    {
        var category = TaxCategory.Create(" vat_standard ", " Standard VAT ");

        Assert.Equal("VAT_STANDARD", category.Code);
        Assert.Equal("Standard VAT", category.Name);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void TaxCategory_RejectsEmptyCode(string code)
    {
        Assert.Throws<ArgumentException>(() => TaxCategory.Create(code, "Standard"));
    }

    [Fact]
    public void TaxCategory_RejectsNullCode()
    {
        Assert.Throws<ArgumentException>(() => TaxCategory.Create(null!, "Standard"));
    }

    [Fact]
    public void TaxRegime_NormalizesFields()
    {
        var regime = TaxRegime.Create(" tz_tra ", " Tanzania TRA ", " tz ");

        Assert.Equal("TZ_TRA", regime.Code);
        Assert.Equal("Tanzania TRA", regime.Name);
        Assert.Equal("TZ", regime.CountryCode);
    }

    [Fact]
    public void TaxRule_CapturesWindowAndStrategyKey()
    {
        var regimeId = Guid.NewGuid();
        var categoryId = Guid.NewGuid();
        var rule = TaxRule.Create(
            regimeId, categoryId, "A", 0.18m, TaxCalculationStrategies.TzDualVat,
            new DateTime(2021, 7, 1, 0, 0, 0, DateTimeKind.Utc), null);

        Assert.Equal(regimeId, rule.RegimeId);
        Assert.Equal(categoryId, rule.CategoryId);
        Assert.Equal("A", rule.Code);
        Assert.Equal(0.18m, rule.Rate);
        Assert.Equal(TaxCalculationStrategies.TzDualVat, rule.CalculationStrategyKey);
        Assert.True(rule.IsEffectiveAt(OnDate));
        Assert.False(rule.IsEffectiveAt(new DateTime(2021, 6, 30, 23, 59, 59, DateTimeKind.Utc)));
    }

    [Theory]
    [InlineData(-0.01)]
    [InlineData(1.01)]
    public void TaxRule_RejectsInvalidRate(decimal rate)
    {
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            TaxRule.Create(Guid.NewGuid(), Guid.NewGuid(), "A", rate));
    }

    [Fact]
    public void TaxRule_RejectsEmptyCode()
    {
        Assert.Throws<ArgumentException>(() =>
            TaxRule.Create(Guid.NewGuid(), Guid.NewGuid(), " ", 0.18m));
    }

    [Fact]
    public void TaxExemption_AppliesByTransactionTypeCustomerAndWindow()
    {
        var tenantId = Guid.NewGuid();
        var categoryId = Guid.NewGuid();
        var customerId = Guid.NewGuid();
        var exemption = TaxExemption.Create(
            tenantId, categoryId, transactionType: "EXPORT", customerId: customerId,
            effectiveFrom: new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            effectiveTo: new DateTime(2026, 12, 31, 23, 59, 59, DateTimeKind.Utc));

        Assert.True(exemption.AppliesTo("EXPORT", customerId, OnDate));
        Assert.False(exemption.AppliesTo("RETAIL", customerId, OnDate));
        Assert.False(exemption.AppliesTo("EXPORT", Guid.NewGuid(), OnDate));
        Assert.False(exemption.AppliesTo("EXPORT", customerId, new DateTime(2025, 6, 1, 0, 0, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void TaxExemption_WithoutNarrowingAppliesToAnyCustomerAndType()
    {
        var exemption = TaxExemption.Create(Guid.NewGuid(), Guid.NewGuid());

        Assert.True(exemption.AppliesTo(null, null, OnDate));
        Assert.True(exemption.AppliesTo("RETAIL", Guid.NewGuid(), OnDate));
    }

    [Fact]
    public void TaxExemption_RejectsInvertedWindow()
    {
        Assert.Throws<ArgumentException>(() => TaxExemption.Create(
            Guid.NewGuid(), Guid.NewGuid(),
            effectiveFrom: new DateTime(2026, 12, 31, 0, 0, 0, DateTimeKind.Utc),
            effectiveTo: new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void TaxRule_SeedUsesSameInvariants()
    {
        var rule = TaxRule.Seed(Guid.NewGuid(), Guid.NewGuid(), "C", 0m);

        Assert.Equal("C", rule.Code);
        Assert.Equal(0m, rule.Rate);
        Assert.Null(rule.CalculationStrategyKey);
        Assert.True(rule.IsEffectiveAt(OnDate));
    }
}

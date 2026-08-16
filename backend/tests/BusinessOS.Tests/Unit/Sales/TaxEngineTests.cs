using BusinessOS.Application.Ports;
using BusinessOS.Application.Tax;
using BusinessOS.Application.Tax.Strategies;
using BusinessOS.Domain.Sales;
using BusinessOS.Localizations.Tanzania.Tax;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class TaxEngineTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid BranchId = new("22222222-2222-2222-2222-222222222222");
    private static readonly Guid ItemId = new("33333333-3333-3333-3333-333333333333");
    private static readonly Guid ItemIdTwo = new("44444444-4444-4444-4444-444444444444");
    private static readonly Guid CustomerId = new("55555555-5555-5555-5555-555555555555");
    private static readonly DateTime OnDate = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);
    private static readonly DateTime TraWindowStart = new(2021, 7, 1, 0, 0, 0, DateTimeKind.Utc);

    private static Guid RegimeId;
    private static Guid VatStandardCategoryId;
    private static Guid ZeroRatedCategoryId;

    [Fact]
    public async Task CashPayment_UsesRateA_AndLandsExactlyOnInclusiveShelfPrice()
    {
        var service = CreateService(withDualVatRules: true);
        var result = await service.CalculateAsync(
            Context(electronic: false, price: 100m), CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal("A", line.TaxCode);
        Assert.Equal(0.18m, line.AppliedRate);
        Assert.Equal(84.75m, line.BaseAmount);
        Assert.Equal(15.25m, line.TaxAmount);
        Assert.Equal(100.00m, line.LineTotal);
        Assert.NotNull(line.AppliedRuleId);
        Assert.Equal(84.75m, result.TotalBaseAmount);
        Assert.Equal(15.25m, result.TotalTaxAmount);
    }

    [Fact]
    public async Task ElectronicWithoutTin_UsesRateB()
    {
        var service = CreateService(withDualVatRules: true);
        var result = await service.CalculateAsync(
            Context(electronic: true, tin: null, price: 100m), CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal("B", line.TaxCode);
        Assert.Equal(0.16m, line.AppliedRate);
        Assert.Equal(84.75m, line.BaseAmount);
        Assert.Equal(13.56m, line.TaxAmount);
        Assert.Equal(98.31m, line.LineTotal);
    }

    [Fact]
    public async Task ElectronicWithTinAndVatRegistered_UsesRateA()
    {
        var service = CreateService(withDualVatRules: true);
        var result = await service.CalculateAsync(
            Context(electronic: true, tin: "123-456-789", vatRegistered: true, price: 100m), CancellationToken.None);

        Assert.Equal("A", Assert.Single(result.Lines).TaxCode);
    }

    [Fact]
    public async Task ElectronicWithTinNotVatRegistered_UsesRateB()
    {
        var service = CreateService(withDualVatRules: true);
        var result = await service.CalculateAsync(
            Context(electronic: true, tin: "123-456-789", vatRegistered: false, price: 100m), CancellationToken.None);

        Assert.Equal("B", Assert.Single(result.Lines).TaxCode);
    }

    [Fact]
    public async Task ExclusivePrice_TaxesTheGrossWithoutExtraction()
    {
        var service = CreateService(withDualVatRules: true);
        var result = await service.CalculateAsync(
            Context(electronic: false, price: 100m, inclusive: false), CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal(100.00m, line.BaseAmount);
        Assert.Equal(18.00m, line.TaxAmount);
        Assert.Equal(118.00m, line.LineTotal);
    }

    [Fact]
    public async Task MixedCart_AggregatesStandardAndZeroRatedLines()
    {
        var service = CreateService(withDualVatRules: true);
        var context = new TaxCalculationContext(
            TenantId, BranchId, OnDate, null, "TZS",
            IsElectronicPayment: false, CustomerTin: null, IsVatRegistered: null,
            Items:
            [
                new TaxCalculationLineItem(ItemId, "VAT_STANDARD", 100m, 1m, IsPriceTaxInclusive: true),
                new TaxCalculationLineItem(ItemIdTwo, "ZERO_RATED", 50m, 1m, IsPriceTaxInclusive: true),
            ]);

        var result = await service.CalculateAsync(context, CancellationToken.None);

        Assert.Equal(2, result.Lines.Count);
        Assert.Equal("A", result.Lines[0].TaxCode);
        Assert.Equal(0m, result.Lines[1].TaxAmount);
        Assert.Equal("C", result.Lines[1].TaxCode);
        Assert.Equal(134.75m, result.TotalBaseAmount);
        Assert.Equal(15.25m, result.TotalTaxAmount);
    }

    [Fact]
    public async Task MultipleQuantity_RoundsPerLineOnce()
    {
        var service = CreateService(withDualVatRules: true);
        var result = await service.CalculateAsync(
            Context(electronic: false, price: 100m, quantity: 2m), CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal(169.49m, line.BaseAmount);
        Assert.Equal(30.51m, line.TaxAmount);
        Assert.Equal(200.00m, line.LineTotal);
    }

    [Fact]
    public async Task ExpiredRule_IsIgnoredAndFallsBackToZero()
    {
        var service = CreateService(withDualVatRules: true);
        var result = await service.CalculateAsync(
            Context(electronic: false, price: 100m, onDate: new DateTime(2020, 1, 1, 0, 0, 0, DateTimeKind.Utc)),
            CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal("NONE", line.TaxCode);
        Assert.Equal(0m, line.TaxAmount);
        Assert.Equal(100.00m, line.BaseAmount);
        Assert.Equal(100.00m, line.LineTotal);
        Assert.Null(line.AppliedRuleId);
    }

    [Fact]
    public async Task NoRegimeForTenant_FallsBackToZero()
    {
        var service = CreateService(withDualVatRules: true, withRegime: false);
        var result = await service.CalculateAsync(
            Context(electronic: false, price: 100m), CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal("NONE", line.TaxCode);
        Assert.Equal(0m, line.TaxAmount);
        Assert.Null(line.AppliedRuleId);
    }

    [Fact]
    public async Task UnknownCategory_FallsBackToZero()
    {
        var service = CreateService(withDualVatRules: true);
        var context = new TaxCalculationContext(
            TenantId, BranchId, OnDate, null, "TZS",
            IsElectronicPayment: false, CustomerTin: null, IsVatRegistered: null,
            Items: [new TaxCalculationLineItem(ItemId, "UNKNOWN", 100m, 1m, IsPriceTaxInclusive: true)]);

        var result = await service.CalculateAsync(context, CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal("NONE", line.TaxCode);
        Assert.Equal(100.00m, line.LineTotal);
        Assert.Null(line.AppliedRuleId);
    }

    [Fact]
    public async Task ExemptionForCustomer_ZeroesTheLine()
    {
        var repo = CreateRepository(withDualVatRules: true);
        repo.Exemptions.Add(TaxExemption.Create(
            TenantId, VatStandardCategoryId, transactionType: null, customerId: CustomerId,
            effectiveFrom: new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            effectiveTo: new DateTime(2026, 12, 31, 23, 59, 59, DateTimeKind.Utc)));
        var service = CreateService(repo);

        var result = await service.CalculateAsync(
            Context(electronic: false, price: 100m, customerId: CustomerId), CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal("EXEMPT", line.TaxCode);
        Assert.Equal(0m, line.TaxAmount);
        Assert.Equal(100.00m, line.LineTotal);
        Assert.Null(line.AppliedRuleId);
    }

    [Fact]
    public async Task ExemptionWithSeededZeroRule_UsesTheRuleId()
    {
        var repo = CreateRepository(withDualVatRules: true);
        repo.Exemptions.Add(TaxExemption.Create(TenantId, ZeroRatedCategoryId));
        var service = CreateService(repo);
        var context = new TaxCalculationContext(
            TenantId, BranchId, OnDate, null, "TZS",
            IsElectronicPayment: false, CustomerTin: null, IsVatRegistered: null,
            Items: [new TaxCalculationLineItem(ItemId, "ZERO_RATED", 50m, 1m, IsPriceTaxInclusive: true)]);

        var result = await service.CalculateAsync(context, CancellationToken.None);

        var line = Assert.Single(result.Lines);
        Assert.Equal("C", line.TaxCode);
        Assert.Equal(0m, line.TaxAmount);
        Assert.NotNull(line.AppliedRuleId);
    }

    [Fact]
    public async Task NonExemptCustomer_IsStillTaxed()
    {
        var repo = CreateRepository(withDualVatRules: true);
        repo.Exemptions.Add(TaxExemption.Create(
            TenantId, VatStandardCategoryId, customerId: CustomerId,
            effectiveFrom: new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            effectiveTo: new DateTime(2026, 12, 31, 23, 59, 59, DateTimeKind.Utc)));
        var service = CreateService(repo);

        var result = await service.CalculateAsync(
            Context(electronic: false, price: 100m, customerId: Guid.NewGuid()), CancellationToken.None);

        Assert.Equal("A", Assert.Single(result.Lines).TaxCode);
    }

    [Fact]
    public async Task NonPositiveQuantity_IsRejected()
    {
        var service = CreateService(withDualVatRules: true);

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() =>
            service.CalculateAsync(Context(electronic: false, price: 100m, quantity: 0m), CancellationToken.None));
    }

    private static TaxCalculationContext Context(
        bool electronic,
        decimal price,
        bool inclusive = true,
        decimal quantity = 1m,
        string? tin = null,
        bool? vatRegistered = null,
        Guid? customerId = null,
        DateTime? onDate = null)
        => new(
            TenantId, BranchId, onDate ?? OnDate, customerId, "TZS",
            IsElectronicPayment: electronic, CustomerTin: tin, IsVatRegistered: vatRegistered,
            Items: [new TaxCalculationLineItem(ItemId, "VAT_STANDARD", price, quantity, inclusive)]);

    private static TaxService CreateService(bool withDualVatRules, bool withRegime = true)
        => CreateService(CreateRepository(withDualVatRules, withRegime));

    private static TaxService CreateService(FakeTaxRepository repo)
        => new(
            repo,
            new ITaxCalculationStrategy[]
            {
                new DefaultPercentageTaxStrategy(),
                new TzDualVatTaxStrategy(),
            });

    private static FakeTaxRepository CreateRepository(bool withDualVatRules, bool withRegime = true)
    {
        var repo = new FakeTaxRepository();
        if (withRegime)
        {
            repo.Regime = TaxRegime.Create("TZ_TRA", "Tanzania TRA", "TZ");
            RegimeId = repo.Regime.Id;
        }

        repo.Categories.Add(TaxCategory.Create("VAT_STANDARD", "Standard VAT"));
        repo.Categories.Add(TaxCategory.Create("ZERO_RATED", "Zero rated"));
        VatStandardCategoryId = repo.Categories[0].Id;
        ZeroRatedCategoryId = repo.Categories[1].Id;

        if (withDualVatRules)
        {
            repo.Rules.Add(TaxRule.Create(
                RegimeId, VatStandardCategoryId, "A", 0.18m, TaxCalculationStrategies.TzDualVat,
                TraWindowStart, null));
            repo.Rules.Add(TaxRule.Create(
                RegimeId, VatStandardCategoryId, "B", 0.16m, TaxCalculationStrategies.TzDualVat,
                TraWindowStart, null));
            repo.Rules.Add(TaxRule.Create(
                RegimeId, VatStandardCategoryId, "OLD", 0.10m, TaxCalculationStrategies.TzDualVat,
                new DateTime(2010, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                new DateTime(2015, 12, 31, 23, 59, 59, DateTimeKind.Utc)));
            repo.Rules.Add(TaxRule.Create(
                RegimeId, ZeroRatedCategoryId, "C", 0m, TaxCalculationStrategies.TzDualVat,
                TraWindowStart, null));
        }

        return repo;
    }

    private sealed class FakeTaxRepository : ITaxRuleRepository
    {
        public TaxRegime? Regime { get; set; }
        public List<TaxCategory> Categories { get; } = [];
        public List<TaxRule> Rules { get; } = [];
        public List<TaxExemption> Exemptions { get; } = [];

        public Task<TaxRegime?> GetRegimeForTenantAsync(
            Guid tenantId, CancellationToken cancellationToken = default)
            => Task.FromResult(Regime);

        public Task<TaxCategory?> GetCategoryByIdAsync(
            Guid id, CancellationToken cancellationToken = default)
            => Task.FromResult(Categories.FirstOrDefault(c => c.Id == id));

        public Task<IReadOnlyList<TaxCategory>> ListCategoriesByCodesAsync(
            IEnumerable<string> codes, CancellationToken cancellationToken = default)
        {
            var wanted = codes.Select(c => c.ToUpperInvariant()).ToHashSet();
            return Task.FromResult<IReadOnlyList<TaxCategory>>(
                Categories.Where(c => wanted.Contains(c.Code)).ToList());
        }

        public Task<IReadOnlyList<TaxRule>> ListEffectiveRulesAsync(
            Guid regimeId, DateTime onDate, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<TaxRule>>(
                Rules.Where(r => r.RegimeId == regimeId && r.IsEffectiveAt(onDate)).ToList());

        public Task<IReadOnlyList<TaxExemption>> ListExemptionsAsync(
            Guid tenantId, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<TaxExemption>>(Exemptions);
    }
}

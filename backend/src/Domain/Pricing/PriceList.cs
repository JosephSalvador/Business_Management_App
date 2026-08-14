using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Pricing;

public sealed class PriceList : AggregateRoot
{
    private readonly List<ProductPrice> _prices = new();

    private PriceList(
        Guid id,
        Guid tenantId,
        string name,
        string currency,
        bool isDefault,
        bool isActive,
        DateTime? effectiveFrom,
        DateTime? effectiveTo)
        : base(id)
    {
        TenantId = tenantId;
        Name = name;
        Currency = currency;
        IsDefault = isDefault;
        IsActive = isActive;
        EffectiveFrom = effectiveFrom;
        EffectiveTo = effectiveTo;
    }

    public Guid TenantId { get; private set; }
    public string Name { get; private set; }
    public string Currency { get; private set; }
    public bool IsDefault { get; private set; }
    public bool IsActive { get; private set; }
    public DateTime? EffectiveFrom { get; private set; }
    public DateTime? EffectiveTo { get; private set; }

    public IReadOnlyCollection<ProductPrice> Prices => _prices.AsReadOnly();

    public static PriceList Create(
        Guid tenantId,
        string name,
        string currency,
        bool isDefault,
        DateTime? effectiveFrom = null,
        DateTime? effectiveTo = null)
    {
        ValidateWindow(effectiveFrom, effectiveTo);

        var priceList = new PriceList(
            Guid.NewGuid(),
            tenantId,
            name.Trim(),
            ProductPrice.NormalizeCurrency(currency),
            isDefault,
            isActive: true,
            effectiveFrom,
            effectiveTo);

        priceList.AddDomainEvent(new PriceListCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, priceList.Id, tenantId, priceList.Name, priceList.Currency, isDefault));

        return priceList;
    }

    public void UpdateProfile(
        string name,
        string currency,
        bool isDefault,
        bool isActive,
        DateTime? effectiveFrom,
        DateTime? effectiveTo)
    {
        ValidateWindow(effectiveFrom, effectiveTo);

        Name = name.Trim();
        Currency = ProductPrice.NormalizeCurrency(currency);
        IsDefault = isDefault;
        IsActive = isActive;
        EffectiveFrom = effectiveFrom;
        EffectiveTo = effectiveTo;

        AddDomainEvent(new PriceListUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Name, Currency, IsDefault, IsActive));
    }

    public bool IsEffectiveAt(DateTime onDate)
        => IsActive
            && (EffectiveFrom is null || EffectiveFrom <= onDate)
            && (EffectiveTo is null || EffectiveTo >= onDate);

    public void SetPrices(IEnumerable<ProductPriceSpec> prices)
    {
        var specs = prices.ToList();
        if (HasDuplicateKeys(specs))
        {
            throw new ArgumentException("Product price keys must be unique.", nameof(prices));
        }

        if (HasSamePrices(specs))
        {
            return;
        }

        var kept = new List<ProductPrice>();
        foreach (var spec in specs)
        {
            var existing = _prices.FirstOrDefault(price =>
                (spec.Id != Guid.Empty && price.Id == spec.Id) || price.HasSameKey(spec));
            if (existing is null)
            {
                kept.Add(ProductPrice.Assign(
                    TenantId,
                    Id,
                    Guid.Empty,
                    spec.ProductId,
                    spec.VariantId,
                    spec.BranchId,
                    spec.PriceType,
                    spec.Price,
                    spec.Currency,
                    spec.MinQuantity,
                    spec.EffectiveFrom,
                    spec.EffectiveTo,
                    spec.IsActive));
                continue;
            }

            existing.Update(spec.Price, spec.Currency, spec.MinQuantity, spec.EffectiveFrom, spec.EffectiveTo, spec.IsActive);
            kept.Add(existing);
        }

        foreach (var dropped in _prices.Except(kept).ToList())
        {
            _prices.Remove(dropped);
        }

        _prices.Clear();
        _prices.AddRange(kept);

        AddDomainEvent(new ProductPricesChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, _prices.Count));
    }

    private static bool HasDuplicateKeys(IReadOnlyCollection<ProductPriceSpec> specs)
        => specs.Select(s => new PriceKey(s.ProductId, s.VariantId, s.BranchId, s.PriceType)).Distinct().Count() != specs.Count;

    private bool HasSamePrices(IReadOnlyCollection<ProductPriceSpec> specs)
    {
        if (specs.Count != _prices.Count)
        {
            return false;
        }

        foreach (var spec in specs)
        {
            var match = _prices.FirstOrDefault(price =>
                (spec.Id != Guid.Empty && price.Id == spec.Id) || price.HasSameKey(spec));
            if (match is null
                || match.Price != spec.Price
                || match.Currency != ProductPrice.NormalizeCurrency(spec.Currency)
                || match.MinQuantity != spec.MinQuantity
                || match.EffectiveFrom != spec.EffectiveFrom
                || match.EffectiveTo != spec.EffectiveTo
                || match.IsActive != spec.IsActive)
            {
                return false;
            }
        }

        return true;
    }

    private static void ValidateWindow(DateTime? effectiveFrom, DateTime? effectiveTo)
    {
        if (effectiveFrom is not null && effectiveTo is not null && effectiveFrom > effectiveTo)
        {
            throw new ArgumentException("EffectiveFrom must be before or equal to EffectiveTo.");
        }
    }

    private readonly record struct PriceKey(Guid ProductId, Guid? VariantId, Guid? BranchId, PriceType PriceType);
}

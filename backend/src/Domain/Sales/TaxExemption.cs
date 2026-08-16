using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A tenant-scoped override that exempts a tax category (optionally narrowed by customer or
/// transaction type) within a window. The engine applies overrides before snapshotting lines.
/// Customer-level exemptions become usable when the Customers module ships.
/// </summary>
public sealed class TaxExemption : Entity
{
    private TaxExemption(
        Guid id,
        Guid tenantId,
        Guid categoryId,
        string? transactionType,
        Guid? customerId,
        DateTime? effectiveFrom,
        DateTime? effectiveTo)
        : base(id)
    {
        TenantId = tenantId;
        CategoryId = categoryId;
        TransactionType = transactionType;
        CustomerId = customerId;
        EffectiveFrom = effectiveFrom;
        EffectiveTo = effectiveTo;
    }

    public Guid TenantId { get; private set; }
    public Guid CategoryId { get; private set; }
    public string? TransactionType { get; private set; }
    public Guid? CustomerId { get; private set; }
    public DateTime? EffectiveFrom { get; private set; }
    public DateTime? EffectiveTo { get; private set; }

    public static TaxExemption Create(
        Guid tenantId,
        Guid categoryId,
        string? transactionType = null,
        Guid? customerId = null,
        DateTime? effectiveFrom = null,
        DateTime? effectiveTo = null)
    {
        ValidateWindow(effectiveFrom, effectiveTo);

        return new TaxExemption(
            Guid.NewGuid(),
            tenantId,
            categoryId,
            string.IsNullOrWhiteSpace(transactionType) ? null : transactionType.Trim().ToUpperInvariant(),
            customerId,
            effectiveFrom,
            effectiveTo);
    }

    public bool AppliesTo(string? transactionType, Guid? customerId, DateTime onDate)
        => (EffectiveFrom is null || EffectiveFrom <= onDate)
            && (EffectiveTo is null || EffectiveTo >= onDate)
            && (TransactionType is null || TransactionType == transactionType)
            && (CustomerId is null || CustomerId == customerId);

    private static void ValidateWindow(DateTime? effectiveFrom, DateTime? effectiveTo)
    {
        if (effectiveFrom is not null && effectiveTo is not null && effectiveFrom > effectiveTo)
        {
            throw new ArgumentException("EffectiveFrom must be before or equal to EffectiveTo.");
        }
    }
}

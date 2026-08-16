namespace BusinessOS.Application.Tax;

/// <summary>
/// One transacted line the engine prices. <see cref="IsPriceTaxInclusive"/> tells the engine
/// whether <see cref="UnitPrice"/> already embeds the shelf-rate tax (TRA practice) or not.
/// </summary>
public sealed record TaxCalculationLineItem(
    Guid ItemId,
    string TaxCategoryCode,
    decimal UnitPrice,
    decimal Quantity,
    bool IsPriceTaxInclusive);

/// <summary>
/// Everything the tax engine needs to resolve rules and snapshot lines: what is being
/// transacted (per-line category), where (regime resolved from the tenant country), when
/// (transaction date), and the payment/taxpayer context used by regimes like TRA dual VAT.
/// </summary>
public sealed record TaxCalculationContext(
    Guid TenantId,
    Guid BranchId,
    DateTime TransactionDate,
    Guid? CustomerId,
    string Currency,
    bool IsElectronicPayment,
    string? CustomerTin,
    bool? IsVatRegistered,
    IReadOnlyList<TaxCalculationLineItem> Items);

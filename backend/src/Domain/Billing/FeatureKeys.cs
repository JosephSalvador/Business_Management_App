namespace BusinessOS.Domain.Billing;

/// <summary>
/// Feature-flag keys that a <see cref="Plan"/> unlocks. They mirror the per-tenant
/// feature flags seeded at provisioning time; the plan catalog just decides which subset
/// a tenant is entitled to at a given moment (trial/annual-activate → the subscribed plan,
/// otherwise the free backstop).
/// </summary>
public static class FeatureKeys
{
    public const string Pos = "pos.enabled";
    public const string Inventory = "inventory.enabled";
    public const string Purchasing = "purchasing.enabled";
    public const string Accounting = "accounting.enabled";
    public const string Crm = "crm.enabled";
    public const string Credit = "credit.enabled";
    public const string Reports = "reports.enabled";
    public const string MultiBranch = "multi-branch.enabled";
    public const string Pricing = "pricing.enabled";
    public const string Finance = "finance.enabled";
    public const string Invoicing = "invoicing.enabled";

    /// <summary>Unlocks everything a paid (or trial) subscription grants today.</summary>
    public static readonly string[] All =
    {
        Pos, Inventory, Purchasing, Accounting, Crm, Credit, Reports, MultiBranch,
        Pricing, Finance, Invoicing,
    };

    public static readonly string[] Pro =
    {
        Pos, Inventory, Purchasing, Accounting, Crm, Credit, Reports, MultiBranch,
        Pricing, Finance,
    };

    public static readonly string[] InvoiceManager =
    {
        Invoicing,
    };

    /// <summary>The backstop set a tenant keeps working with while in debt (POS + stock).</summary>
    public static readonly string[] Backstop =
    {
        Pos, Inventory,
    };
}
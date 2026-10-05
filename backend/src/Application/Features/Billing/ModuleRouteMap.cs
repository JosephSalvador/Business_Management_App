using BusinessOS.Domain.Billing;

namespace BusinessOS.Application.Features.Billing;

/// <summary>
/// One sellable module: the API surface it owns, the feature key that unlocks it and
/// whether it survives a subscription falling into debt.
/// </summary>
public sealed record ModuleDescriptor(
    string Id,
    string Name,
    string FeatureKey,
    bool IsBackstop);

/// <summary>
/// Maps an API route onto the module that owns it. The middleware uses it to decide
/// whether a request is allowed to run, and the Flutter client uses the same module ids
/// in its navigation so a disabled module disappears from the workspace instead of
/// failing at click time.
/// </summary>
public static class ModuleRouteMap
{
    public static readonly IReadOnlyList<ModuleDescriptor> All = new[]
    {
        new ModuleDescriptor("pos", "Point of Sale", FeatureKeys.Pos, true),
        new ModuleDescriptor("inventory", "Inventory", FeatureKeys.Inventory, true),
        new ModuleDescriptor("purchasing", "Purchasing", FeatureKeys.Purchasing, false),
        new ModuleDescriptor("accounting", "Accounting", FeatureKeys.Accounting, false),
        new ModuleDescriptor("finance", "Finance", FeatureKeys.Finance, false),
        new ModuleDescriptor("crm", "Customers", FeatureKeys.Crm, false),
        new ModuleDescriptor("credit", "Credit", FeatureKeys.Credit, false),
        new ModuleDescriptor("pricing", "Pricing", FeatureKeys.Pricing, false),
        new ModuleDescriptor("invoicing", "Invoicing", FeatureKeys.Invoicing, false),
        new ModuleDescriptor("reports", "Reports", FeatureKeys.Reports, false),
    };

    private static readonly IReadOnlyDictionary<string, string> SegmentModules =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["sales"] = "pos",
            ["receipts"] = "pos",
            ["products"] = "inventory",
            ["warehouses"] = "inventory",
            ["inventory"] = "inventory",
            ["suppliers"] = "purchasing",
            ["purchase-orders"] = "purchasing",
            ["supplier-bills"] = "purchasing",
            ["accounts"] = "accounting",
            ["journal-entries"] = "accounting",
            ["account-mappings"] = "accounting",
            ["accounting-reports"] = "accounting",
            ["expenses"] = "finance",
            ["money-accounts"] = "finance",
            ["cash-sessions"] = "finance",
            ["price-lists"] = "pricing",
            ["pricing"] = "pricing",
            ["customers"] = "crm",
            ["credit"] = "credit",
            ["invoices"] = "invoicing",
            ["reports"] = "reports",
        };

    private static readonly IReadOnlyDictionary<string, ModuleDescriptor> ById =
        All.ToDictionary(module => module.Id, StringComparer.Ordinal);

    public static ModuleDescriptor? ByModuleId(string id)
        => ById.GetValueOrDefault(id);

    public static ModuleDescriptor? ByFeatureKey(string featureKey)
        => All.FirstOrDefault(module =>
            string.Equals(module.FeatureKey, featureKey, StringComparison.Ordinal));

    /// <summary>
    /// Resolves the module owning <paramref name="path"/>, or <c>null</c> for routes that
    /// are always available (auth, identity, organisation, billing, capabilities, dashboard).
    /// </summary>
    public static ModuleDescriptor? Match(string? path)
    {
        var segments = SegmentsAfterApiVersion(path);
        if (segments.Count == 0)
        {
            return null;
        }

        // /customers/{id}/credit/* is the credit module even though it hangs off customers.
        if (segments.Count >= 3 &&
            string.Equals(segments[0], "customers", StringComparison.Ordinal) &&
            string.Equals(segments[2], "credit", StringComparison.Ordinal))
        {
            return ById["credit"];
        }

        return SegmentModules.TryGetValue(segments[0], out var moduleId)
            ? ById[moduleId]
            : null;
    }

    private static List<string> SegmentsAfterApiVersion(string? path)
    {
        var segments = new List<string>();
        if (string.IsNullOrEmpty(path))
        {
            return segments;
        }

        var value = path;
        if (value.StartsWith("/api/", StringComparison.Ordinal))
        {
            var rest = value["/api/".Length..];
            var slash = rest.IndexOf('/');
            value = slash >= 0 ? rest[slash..] : "/";
        }

        foreach (var segment in value.Split('/', StringSplitOptions.RemoveEmptyEntries))
        {
            segments.Add(segment);
        }

        return segments;
    }
}

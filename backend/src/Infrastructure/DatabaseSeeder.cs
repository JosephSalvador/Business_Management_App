using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Infrastructure;

/// <summary>
/// Idempotent seed for local development: registers all known permissions and creates a
/// demo tenant + administrator user if they do not exist.
/// Dev credentials (never for production): admin@acme.local / Admin@12345
/// </summary>
public sealed class DatabaseSeeder
{
    private readonly BusinessDbContext _db;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ILogger<DatabaseSeeder> _logger;

    public DatabaseSeeder(
        BusinessDbContext db,
        IPasswordHasher passwordHasher,
        ILogger<DatabaseSeeder> logger)
    {
        _db = db;
        _passwordHasher = passwordHasher;
        _logger = logger;
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default, bool createDemoTenant = true)
    {
        var existingNames = await _db.Permissions.Select(p => p.Name).ToListAsync(cancellationToken);
        var missing = PermissionNames.All.Where(name => !existingNames.Contains(name)).ToArray();

        foreach (var name in missing)
        {
            _db.Permissions.Add(Permission.Seed(name));
        }

        if (missing.Length > 0)
        {
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Seeded {Count} permissions.", missing.Length);
        }

        var adminRoles = await _db.Roles
            .Include(r => r.Permissions)
            .Where(r => r.IsSystem && r.Name == SystemRoles.Administrator)
            .ToListAsync(cancellationToken);

        if (adminRoles.Count > 0)
        {
            var grantPermissions = await _db.Permissions
                .Where(p => PermissionNames.All.Contains(p.Name))
                .ToListAsync(cancellationToken);

            foreach (var role in adminRoles)
            {
                role.Grant(grantPermissions);
            }

            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Re-granted permissions to {Count} system administrator roles.", adminRoles.Count);
        }

        await EnsureTaxCatalogAsync(cancellationToken);
        await EnsureBillingCatalogAsync(cancellationToken);
        await EnsureFeatureFlagBackfillAsync(cancellationToken);

        if (!createDemoTenant)
        {
            _logger.LogInformation("Demo tenant seeding disabled for this environment.");
            return;
        }

        const string demoEmail = "admin@acme.local";
        var demoUser = await _db.Users.FirstOrDefaultAsync(u => u.Email == demoEmail, cancellationToken);
        if (demoUser is not null)
        {
            var demoTenant = await _db.Tenants.FirstOrDefaultAsync(
                t => t.Id == demoUser.TenantId, cancellationToken);
            if (demoTenant is not null && string.IsNullOrWhiteSpace(demoTenant.CountryCode))
            {
                demoTenant.UpdateCountryCode(Tenant.DefaultCountryCode);
                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Set default country code for the demo tenant.");
            }

            if (!demoUser.EmailVerified)
            {
                demoUser.MarkEmailVerified();
                await _db.SaveChangesAsync(cancellationToken);
            }

            if (demoTenant is not null && demoTenant.OnboardingCompletedAt is null)
            {
                var currency = string.IsNullOrWhiteSpace(demoTenant.Currency) ? "TZS" : demoTenant.Currency;
                demoTenant.CompleteOnboarding(demoTenant.Name, businessType: null, Tenant.DefaultCountryCode, currency, contactPhone: null, taxId: null);
                await _db.SaveChangesAsync(cancellationToken);
            }

            if (!await _db.Branches.AnyAsync(b => b.TenantId == demoUser.TenantId, cancellationToken))
            {
                _db.Branches.Add(Branch.Create(
                    demoUser.TenantId,
                    Branch.DefaultName,
                    Branch.DefaultCode,
                    Tenant.DefaultCurrency));
                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Seeded default branch for the demo tenant.");
            }

            await EnsureExpenseCategoriesAsync(demoUser.TenantId, cancellationToken);

            return;
        }

        var tenant = Tenant.Create(Guid.NewGuid(), "Acme Ltd");
        await _db.Tenants.AddAsync(tenant, cancellationToken);

        var adminRole = Role.Create(tenant.Id, SystemRoles.Administrator, isSystem: true);
        var allPermissions = await _db.Permissions
            .Where(p => PermissionNames.All.Contains(p.Name))
            .ToListAsync(cancellationToken);
        adminRole.Grant(allPermissions);
        await _db.Roles.AddAsync(adminRole, cancellationToken);

        var staffRole = Role.Create(
            tenant.Id,
            SystemRoles.Staff,
            isSystem: true,
            description: "Fanyakazi — catalogue, stock na POS");
        staffRole.Grant(await ResolvePermissionsAsync(PermissionNames.Staff, cancellationToken));
        await _db.Roles.AddAsync(staffRole, cancellationToken);

        foreach (var template in RoleTemplates.Starter)
        {
            var role = Role.Create(tenant.Id, template.Name, description: template.Description);
            role.Grant(await ResolvePermissionsAsync(template.PermissionNames, cancellationToken));
            await _db.Roles.AddAsync(role, cancellationToken);
        }

        var admin = User.Create(
            Guid.NewGuid(),
            tenant.Id,
            demoEmail,
            _passwordHasher.Hash("Admin@12345"),
            "System Administrator",
            phone: null);
        admin.AssignRole(adminRole);
        admin.MarkEmailVerified();
        await _db.Users.AddAsync(admin, cancellationToken);

        // The seeded workspace is fully usable without running guided setup.
        tenant.CompleteOnboarding(tenant.Name, businessType: null, Tenant.DefaultCountryCode, tenant.Currency, contactPhone: null, taxId: null);

        await _db.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("Seeded demo tenant 'Acme Ltd' and administrator user.");

        await EnsureExpenseCategoriesAsync(tenant.Id, cancellationToken);
    }

    private async Task<IReadOnlyList<Permission>> ResolvePermissionsAsync(
        IEnumerable<string> names,
        CancellationToken cancellationToken)
    {
        var requested = names.ToHashSet(StringComparer.Ordinal);
        return await _db.Permissions
            .Where(permission => requested.Contains(permission.Name))
            .ToListAsync(cancellationToken);
    }

    /// <summary>
    /// Platform-level tax catalog, idempotently get-or-create by natural code. Categories,
    /// the TZ_TRA regime and its A/B/C rules apply to every tenant (regime is resolved from the
    /// tenant's country code at sale time); tenant-scoped exemptions are never seeded.
    /// </summary>
    private async Task EnsureTaxCatalogAsync(CancellationToken cancellationToken)
    {
        var categories = new (string Code, string Name)[]
        {
            ("VAT_STANDARD", "Standard VAT"),
            ("VAT_REDUCED", "Reduced VAT"),
            ("VAT_ZERO", "Zero rated"),
            ("EXEMPT", "Exempt"),
        };

        foreach (var (code, name) in categories)
        {
            if (!await _db.TaxCategories.AnyAsync(c => c.Code == code, cancellationToken))
            {
                _db.TaxCategories.Add(TaxCategory.Seed(code, name));
            }
        }

        var regime = await _db.TaxRegimes.FirstOrDefaultAsync(r => r.Code == "TZ_TRA", cancellationToken);
        if (regime is null)
        {
            regime = TaxRegime.Seed("TZ_TRA", "Tanzania TRA", "TZ");
            _db.TaxRegimes.Add(regime);
        }

        await _db.SaveChangesAsync(cancellationToken);

        var categoryById = await _db.TaxCategories
            .Where(c => categories.Select(c => c.Code).Contains(c.Code))
            .ToDictionaryAsync(c => c.Code, cancellationToken);

        // --- Tax rules disabled until TRA integration addon is developed ---
        // When re-enabled, uncomment below to seed TZ_TRA rules (18%/16% dual VAT).
        // var traStart = new DateTime(2021, 7, 1, 0, 0, 0, DateTimeKind.Utc);
        // var rules = new (string Category, string Code, decimal Rate, string? StrategyKey)[]
        // {
        //     ("VAT_STANDARD", "A", 0.18m, TaxCalculationStrategies.TzDualVat),
        //     ("VAT_STANDARD", "B", 0.16m, TaxCalculationStrategies.TzDualVat),
        //     ("VAT_REDUCED", "A", 0.18m, TaxCalculationStrategies.TzDualVat),
        //     ("VAT_REDUCED", "B", 0.16m, TaxCalculationStrategies.TzDualVat),
        //     ("VAT_ZERO", "C", 0m, null),
        //     ("EXEMPT", "C", 0m, null),
        // };
        //
        // foreach (var (category, code, rate, strategyKey) in rules)
        // {
        //     var categoryId = categoryById[category].Id;
        //     if (!await _db.TaxRules.AnyAsync(
        //             r => r.RegimeId == regime.Id && r.CategoryId == categoryId && r.Code == code,
        //             cancellationToken))
        //     {
        //         _db.TaxRules.Add(TaxRule.Seed(regime.Id, categoryId, code, rate, strategyKey, traStart));
        //     }
        // }

        await _db.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("Ensured TZ_TRA tax catalog (categories, regime). Tax rules pending TRA integration addon.");
    }

    /// <summary>
    /// M13 monetization catalog: the platform-level Free/Pro plan catalog, idempotently
    /// seeded by code. Tenants that pre-date M13 (or were provisioned before the registration
    /// hook) are backfilled with a fresh 14-day Pro trial so nothing is left in limbo.
    /// </summary>
    private async Task EnsureBillingCatalogAsync(CancellationToken cancellationToken)
    {
        if (!await PlanExistsAsync(Plan.FreeCode, cancellationToken))
        {
            _db.Plans.Add(Plan.Seed(
                Plan.FreeCode,
                "Free",
                0,
                Plan.DefaultCurrency,
                FeatureKeys.Backstop));
        }

        if (!await PlanExistsAsync(Plan.ProCode, cancellationToken))
        {
            _db.Plans.Add(Plan.Seed(
                Plan.ProCode,
                "Pro",
                Plan.ProMonthlyPriceDefaultTzs,
                Plan.DefaultCurrency,
                FeatureKeys.Pro,
                maxBranches: 3,
                maxUsers: 5,
                maxProducts: 3000));
        }

        if (!await PlanExistsAsync(Plan.InvoiceManagerCode, cancellationToken))
        {
            _db.Plans.Add(Plan.Seed(
                Plan.InvoiceManagerCode,
                "Invoice Manager",
                Plan.InvoiceManagerMonthlyPriceDefaultTzs,
                Plan.DefaultCurrency,
                FeatureKeys.InvoiceManager,
                isPackage: true));
        }

        await _db.SaveChangesAsync(cancellationToken);

        var orphanTenantIds = await _db.Tenants
            .Where(tenant => !_db.Subscriptions.Any(subscription => subscription.TenantId == tenant.Id))
            .Select(tenant => tenant.Id)
            .ToListAsync(cancellationToken);

        foreach (var tenantId in orphanTenantIds)
        {
            _db.Subscriptions.Add(Subscription.StartTrial(tenantId));
        }

        if (orphanTenantIds.Count > 0)
        {
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation(
                "Granted 14-day Pro trial subscriptions to {Count} legacy tenants.",
                orphanTenantIds.Count);
        }
    }

    private Task<bool> PlanExistsAsync(string code, CancellationToken cancellationToken)
    {
        var normalized = code.Trim().ToLowerInvariant();
        return _db.Plans.AnyAsync(p => p.Code.ToLower() == normalized, cancellationToken);
    }

    private async Task EnsureFeatureFlagBackfillAsync(CancellationToken cancellationToken)
    {
        var tenantIds = await _db.Tenants.Select(t => t.Id).ToListAsync(cancellationToken);
        if (tenantIds.Count == 0)
        {
            return;
        }

        var existing = await _db.FeatureFlags
            .Where(flag => tenantIds.Contains(flag.TenantId))
            .Select(flag => new { flag.TenantId, flag.Key })
            .ToListAsync(cancellationToken);

        var present = existing
            .Select(flag => (flag.TenantId, flag.Key))
            .ToHashSet();

        var added = 0;
        foreach (var tenantId in tenantIds)
        {
            foreach (var key in FeatureKeys.All)
            {
                if (present.Add((tenantId, key)))
                {
                    _db.FeatureFlags.Add(FeatureFlag.Create(tenantId, key, isEnabled: true));
                    added++;
                }
            }
        }

        if (added > 0)
        {
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation(
                "Backfilled {Count} feature flags for legacy tenants.", added);
        }
    }

    /// <summary>
    /// Seed default expense categories per tenant so new expenses always have a category.
    /// </summary>
    private async Task EnsureExpenseCategoriesAsync(Guid tenantId, CancellationToken cancellationToken)
    {
        var defaults = new[]
        {
            "Rent", "Utilities", "Transport", "Salaries", "Supplies",
            "Marketing", "Maintenance", "Insurance", "Taxes", "Other",
        };

        foreach (var name in defaults)
        {
            if (!await _db.ExpenseCategories.AnyAsync(
                    c => c.TenantId == tenantId && c.Name == name, cancellationToken))
            {
                _db.ExpenseCategories.Add(ExpenseCategory.Create(tenantId, name));
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
    }
}

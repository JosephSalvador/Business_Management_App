using BusinessOS.Application.Ports;
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

    public async Task SeedAsync(CancellationToken cancellationToken = default)
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

        var traStart = new DateTime(2021, 7, 1, 0, 0, 0, DateTimeKind.Utc);
        var rules = new (string Category, string Code, decimal Rate, string? StrategyKey)[]
        {
            ("VAT_STANDARD", "A", 0.18m, TaxCalculationStrategies.TzDualVat),
            ("VAT_STANDARD", "B", 0.16m, TaxCalculationStrategies.TzDualVat),
            ("VAT_REDUCED", "A", 0.18m, TaxCalculationStrategies.TzDualVat),
            ("VAT_REDUCED", "B", 0.16m, TaxCalculationStrategies.TzDualVat),
            ("VAT_ZERO", "C", 0m, null),
            ("EXEMPT", "C", 0m, null),
        };

        foreach (var (category, code, rate, strategyKey) in rules)
        {
            var categoryId = categoryById[category].Id;
            if (!await _db.TaxRules.AnyAsync(
                    r => r.RegimeId == regime.Id && r.CategoryId == categoryId && r.Code == code,
                    cancellationToken))
            {
                _db.TaxRules.Add(TaxRule.Seed(regime.Id, categoryId, code, rate, strategyKey, traStart));
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("Ensured TZ_TRA tax catalog (categories, regime, A/B/C rules).");
    }
}

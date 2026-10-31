using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Invoicing;
using BusinessOS.Domain.Pricing;
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

        var staffAndCashierRoles = await _db.Roles
            .Include(r => r.Permissions)
            .Where(r => r.Name == SystemRoles.Staff || r.Name == "Cashier")
            .ToListAsync(cancellationToken);

        var pricingViewPerm = await _db.Permissions
            .FirstOrDefaultAsync(p => p.Name == PermissionNames.PricingView, cancellationToken);

        if (pricingViewPerm is not null && staffAndCashierRoles.Count > 0)
        {
            var updated = 0;
            foreach (var role in staffAndCashierRoles)
            {
                if (!role.Permissions.Any(p => p.Name == PermissionNames.PricingView))
                {
                    role.Grant(new[] { pricingViewPerm });
                    updated++;
                }
            }

            if (updated > 0)
            {
                await _db.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Granted PricingView to {Count} existing Staff/Cashier roles.", updated);
            }
        }

        await EnsureTaxCatalogAsync(cancellationToken);
        await EnsureBillingCatalogAsync(cancellationToken);
        await EnsureFeatureFlagBackfillAsync(cancellationToken);

        // Auto-verify all users in staging / preproduction so users are never blocked by unconfigured SMTP
        var unverifiedUsers = await _db.Users.Where(u => !u.EmailVerified).ToListAsync(cancellationToken);
        if (unverifiedUsers.Count > 0)
        {
            foreach (var u in unverifiedUsers)
            {
                u.MarkEmailVerified();
            }
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Auto-verified {Count} existing unverified users.", unverifiedUsers.Count);
        }

        await EnsureDocumentTemplatesSeededAsync(cancellationToken);

        if (!createDemoTenant)
        {
            _logger.LogInformation("Demo tenant seeding disabled for this environment.");
            return;
        }

        const string demoEmail = "admin@acme.local";
        var demoUser = await _db.Users.FirstOrDefaultAsync(u => u.Email == demoEmail, cancellationToken);
        if (demoUser is null)
        {
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

            tenant.CompleteOnboarding(tenant.Name, businessType: null, Tenant.DefaultCountryCode, tenant.Currency, contactPhone: null, taxId: null);

            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Seeded demo tenant 'Acme Ltd' and administrator user.");
        }

        var allTenants = await _db.Tenants.ToListAsync(cancellationToken);
        foreach (var currentTenant in allTenants)
        {
            await EnsureTenantDefaultsAndSampleCatalogAsync(currentTenant, cancellationToken);
        }
    }

    private async Task EnsureTenantDefaultsAndSampleCatalogAsync(Tenant tenant, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(tenant.CountryCode))
        {
            tenant.UpdateCountryCode(Tenant.DefaultCountryCode);
        }

        if (tenant.OnboardingCompletedAt is null)
        {
            var currency = string.IsNullOrWhiteSpace(tenant.Currency) ? Tenant.DefaultCurrency : tenant.Currency;
            tenant.CompleteOnboarding(tenant.Name, businessType: null, Tenant.DefaultCountryCode, currency, contactPhone: null, taxId: null);
        }

        Branch? defaultBranch = await _db.Branches.FirstOrDefaultAsync(b => b.TenantId == tenant.Id, cancellationToken);
        if (defaultBranch is null)
        {
            defaultBranch = Branch.Create(
                tenant.Id,
                Branch.DefaultName,
                Branch.DefaultCode,
                string.IsNullOrWhiteSpace(tenant.Currency) ? Tenant.DefaultCurrency : tenant.Currency);
            _db.Branches.Add(defaultBranch);
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Seeded default branch for tenant '{TenantName}'.", tenant.Name);
        }

        await EnsureExpenseCategoriesAsync(tenant.Id, cancellationToken);

        // Ensure default Unit of Measure
        var pieceUnit = await _db.UnitsOfMeasure.FirstOrDefaultAsync(
            u => u.TenantId == tenant.Id && (u.Abbreviation == "PCS" || u.Name == "Piece"), cancellationToken);
        if (pieceUnit is null)
        {
            pieceUnit = UnitOfMeasure.Create(tenant.Id, "Piece", "PCS");
            _db.UnitsOfMeasure.Add(pieceUnit);
            await _db.SaveChangesAsync(cancellationToken);
        }

        // Ensure default Product Categories
        var categories = new Dictionary<string, ProductCategory>(StringComparer.OrdinalIgnoreCase);
        var catNames = new[] { "Vinywaji", "Chakula", "Usafi" };
        foreach (var catName in catNames)
        {
            var cat = await _db.ProductCategories.FirstOrDefaultAsync(
                c => c.TenantId == tenant.Id && c.Name == catName, cancellationToken);
            if (cat is null)
            {
                cat = ProductCategory.Create(tenant.Id, catName);
                _db.ProductCategories.Add(cat);
                await _db.SaveChangesAsync(cancellationToken);
            }
            categories[catName] = cat;
        }

        // Ensure default Warehouse & Stock Location
        var warehouse = await _db.Warehouses
            .Include(w => w.Locations)
            .FirstOrDefaultAsync(w => w.TenantId == tenant.Id, cancellationToken);
        if (warehouse is null)
        {
            warehouse = Warehouse.Create(tenant.Id, defaultBranch.Id, "Kuu", "MAIN", "Stoo Kuu ya Biashara");
            _db.Warehouses.Add(warehouse);
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Seeded default warehouse for tenant '{TenantName}'.", tenant.Name);
        }

        var stockLocation = await _db.StockLocations.FirstOrDefaultAsync(
            l => l.WarehouseId == warehouse.Id, cancellationToken);

        // Ensure default Retail Price List
        var defaultPriceList = await _db.PriceLists.FirstOrDefaultAsync(
            p => p.TenantId == tenant.Id && p.IsDefault, cancellationToken);
        if (defaultPriceList is null)
        {
            var currency = string.IsNullOrWhiteSpace(tenant.Currency) ? Tenant.DefaultCurrency : tenant.Currency;
            defaultPriceList = PriceList.Create(tenant.Id, "Bei ya Rejareja", currency, isDefault: true);
            _db.PriceLists.Add(defaultPriceList);
            await _db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Seeded default price list for tenant '{TenantName}'.", tenant.Name);
        }

        // If tenant has no products, seed realistic sample products with prices and stock balances
        var hasProducts = await _db.Products.AnyAsync(p => p.TenantId == tenant.Id, cancellationToken);
        if (!hasProducts)
        {
            var sampleProducts = new[]
            {
                new {
                    Name = "Coca-Cola 500ml",
                    Category = "Vinywaji",
                    Sku = "BEV-COKE-500",
                    Barcode = "049000000443",
                    Description = "Kinywaji baridi cha chupa 500ml",
                    CostPrice = 1200m,
                    SellingPrice = 1500m,
                    InitialStock = 50m
                },
                new {
                    Name = "Maji ya Uhai 1.5L",
                    Category = "Vinywaji",
                    Sku = "BEV-UHAI-1500",
                    Barcode = "616110000101",
                    Description = "Maji safi na salama ya kunywa 1.5L",
                    CostPrice = 800m,
                    SellingPrice = 1000m,
                    InitialStock = 80m
                },
                new {
                    Name = "Azam Ngano Bora 1kg",
                    Category = "Chakula",
                    Sku = "GROC-AZAM-1KG",
                    Barcode = "616110000202",
                    Description = "Unga safi wa ngano namba moja wa kuoka na kupika",
                    CostPrice = 2000m,
                    SellingPrice = 2500m,
                    InitialStock = 35m
                },
                new {
                    Name = "Mchele wa Kyela Super 1kg",
                    Category = "Chakula",
                    Sku = "GROC-KYELA-1KG",
                    Barcode = "616110000303",
                    Description = "Mchele safi wenye harufu nzuri toka Kyela Mbeya",
                    CostPrice = 2900m,
                    SellingPrice = 3500m,
                    InitialStock = 40m
                },
                new {
                    Name = "Sabuni ya Omo 500g",
                    Category = "Usafi",
                    Sku = "DET-OMO-500",
                    Barcode = "616110000404",
                    Description = "Sabuni ya unga ya kufulia nguo safi na harufu nzuri",
                    CostPrice = 2300m,
                    SellingPrice = 2800m,
                    InitialStock = 25m
                }
            };

            foreach (var sp in sampleProducts)
            {
                var catId = categories.TryGetValue(sp.Category, out var c) ? c.Id : (Guid?)null;
                var product = Product.Create(
                    tenant.Id,
                    sp.Name,
                    sp.Description,
                    sp.Sku,
                    sp.Barcode,
                    catId,
                    brandId: null,
                    pieceUnit.Id,
                    ProductType.Product,
                    ProductStatus.Active,
                    taxCategoryId: null,
                    costPrice: sp.CostPrice);

                _db.Products.Add(product);
                await _db.SaveChangesAsync(cancellationToken);

                var productPrice = ProductPrice.Assign(
                    tenant.Id,
                    defaultPriceList.Id,
                    Guid.NewGuid(),
                    product.Id,
                    variantId: null,
                    branchId: null,
                    PriceType.Retail,
                    sp.SellingPrice,
                    defaultPriceList.Currency,
                    minQuantity: 1m,
                    effectiveFrom: null,
                    effectiveTo: null,
                    isActive: true);
                _db.ProductPrices.Add(productPrice);

                if (stockLocation is not null)
                {
                    var balance = StockBalance.Create(
                        tenant.Id, warehouse.Id, stockLocation.Id, product.Id, variantId: null, batchId: null);
                    balance.Apply(sp.InitialStock);
                    _db.StockBalances.Add(balance);
                }

                await _db.SaveChangesAsync(cancellationToken);
            }

            _logger.LogInformation("Seeded 5 sample catalog products with prices and stock for tenant '{TenantName}'.", tenant.Name);
        }
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

    private async Task EnsureDocumentTemplatesSeededAsync(CancellationToken cancellationToken)
    {
        if (await _db.DocumentTemplates.AnyAsync(cancellationToken))
        {
            return;
        }

        var templates = new List<DocumentTemplate>
        {
            DocumentTemplate.Create(
                name: "Modern Minimalist",
                documentType: DocumentType.Invoice,
                description: "Clean, contemporary corporate layout with bold typography, accent branding, and bank summary.",
                isDefault: true,
                displayOrder: 1,
                liquidLayout: @"<!DOCTYPE html>
<html>
<head>
<meta charset=""utf-8"" />
<title>Invoice {{ invoice.number }}</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; background: #ffffff; padding: 32px; font-size: 14px; line-height: 1.5; }
.header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 3px solid {{ theme.primary_hex }}; padding-bottom: 20px; margin-bottom: 24px; }
.brand-name { font-size: 24px; font-weight: 800; color: {{ theme.primary_hex }}; letter-spacing: -0.5px; }
.doc-type { font-size: 28px; font-weight: 900; color: {{ theme.primary_hex }}; text-align: right; }
.doc-num { font-size: 16px; font-weight: 600; color: {{ theme.secondary_hex }}; text-align: right; }
.meta-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 28px; }
.meta-card { background: #f8fafc; border-radius: 8px; padding: 16px; border: 1px solid #e2e8f0; }
.meta-title { font-size: 12px; font-weight: 700; color: {{ theme.secondary_hex }}; text-transform: uppercase; margin-bottom: 6px; }
table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
th { background: {{ theme.primary_hex }}; color: #ffffff; text-align: left; padding: 10px 12px; font-size: 12px; text-transform: uppercase; font-weight: 700; }
td { padding: 12px; border-bottom: 1px solid #e2e8f0; }
tr:nth-child(even) td { background: #f8fafc; }
.text-right { text-align: right; }
.summary-container { display: flex; justify-content: flex-end; margin-bottom: 28px; }
.summary-table { width: 320px; border-collapse: collapse; }
.summary-table td { padding: 8px 12px; }
.summary-total { font-size: 18px; font-weight: 800; color: {{ theme.primary_hex }}; border-top: 2px solid {{ theme.primary_hex }}; }
.bank-box { background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 16px; margin-top: 24px; font-size: 13px; }
.bank-title { font-weight: 700; color: {{ theme.primary_hex }}; margin-bottom: 4px; }
.footer { margin-top: 40px; text-align: center; font-size: 12px; color: {{ theme.secondary_hex }}; border-top: 1px solid #e2e8f0; padding-top: 16px; }
</style>
</head>
<body>
<div class=""header"">
    <div>
        <div class=""brand-name"">{{ organization.name }}</div>
        <div>{{ organization.address }}</div>
        <div>{{ organization.phone }} | {{ organization.email }}</div>
        {% if organization.tin %}<div>TIN: {{ organization.tin }}</div>{% endif %}
    </div>
    <div>
        <div class=""doc-type"">{{ invoice.document_title }}</div>
        <div class=""doc-num""># {{ invoice.number }}</div>
        <div>Date: {{ invoice.issue_date }}</div>
        {% if invoice.due_date %}<div>Due: {{ invoice.due_date }}</div>{% endif %}
    </div>
</div>

<div class=""meta-grid"">
    <div class=""meta-card"">
        <div class=""meta-title"">Invoiced To</div>
        <div style=""font-weight: 700; font-size: 16px;"">{{ invoice.customer_name }}</div>
        {% if invoice.customer_attention %}<div>Attn: {{ invoice.customer_attention }}</div>{% endif %}
        {% if invoice.customer_phone %}<div>Phone: {{ invoice.customer_phone }}</div>{% endif %}
        {% if invoice.customer_address %}<div>{{ invoice.customer_address }}</div>{% endif %}
        {% if invoice.customer_tin %}<div>TIN: {{ invoice.customer_tin }}</div>{% endif %}
    </div>
    {% if invoice.reference_number or invoice.payment_terms %}
    <div class=""meta-card"">
        <div class=""meta-title"">Reference Details</div>
        {% if invoice.reference_number %}<div>Ref / LPO: <strong>{{ invoice.reference_number }}</strong></div>{% endif %}
        {% if invoice.payment_terms %}<div>Terms: <strong>{{ invoice.payment_terms }}</strong></div>{% endif %}
    </div>
    {% endif %}
</div>

<table>
<thead>
    <tr>
        <th>#</th>
        <th>Description</th>
        <th class=""text-right"">Qty</th>
        <th class=""text-right"">Unit Price</th>
        <th class=""text-right"">Total</th>
    </tr>
</thead>
<tbody>
{% for line in invoice.lines %}
    <tr>
        <td>{{ forloop.index }}</td>
        <td>{{ line.description }}</td>
        <td class=""text-right"">{{ line.quantity }} {{ line.unit_of_measure }}</td>
        <td class=""text-right"">{{ line.unit_price }}</td>
        <td class=""text-right"">{{ line.line_total }}</td>
    </tr>
{% endfor %}
</tbody>
</table>

<div class=""summary-container"">
    <table class=""summary-table"">
        <tr><td>Subtotal</td><td class=""text-right"">{{ invoice.currency }} {{ invoice.subtotal }}</td></tr>
        {% if invoice.tax_amount > 0 %}
        <tr><td>Tax / VAT</td><td class=""text-right"">{{ invoice.currency }} {{ invoice.tax_amount }}</td></tr>
        {% endif %}
        <tr class=""summary-total""><td>Total Due</td><td class=""text-right"">{{ invoice.currency }} {{ invoice.total_amount }}</td></tr>
        {% if invoice.amount_paid > 0 %}
        <tr><td>Amount Paid</td><td class=""text-right"">{{ invoice.currency }} {{ invoice.amount_paid }}</td></tr>
        <tr style=""font-weight: 700; color: #dc2626;""><td>Balance Due</td><td class=""text-right"">{{ invoice.currency }} {{ invoice.balance_due }}</td></tr>
        {% endif %}
    </table>
</div>

{% if organization.bank_name or organization.mobile_money_details %}
<div class=""bank-box"">
    <div class=""bank-title"">Payment Instructions</div>
    {% if organization.bank_name %}
    <div>Bank: <strong>{{ organization.bank_name }}</strong> | Account Name: <strong>{{ organization.bank_account_name }}</strong></div>
    <div>Account Number: <strong>{{ organization.bank_account_number }}</strong> {% if organization.bank_branch_or_swift %}| Swift/Branch: {{ organization.bank_branch_or_swift }}{% endif %}</div>
    {% endif %}
    {% if organization.mobile_money_details %}
    <div style=""margin-top: 4px;"">Mobile Payment: <strong>{{ organization.mobile_money_details }}</strong></div>
    {% endif %}
</div>
{% endif %}

<div class=""footer"">
    {{ theme.footer_notes }}
</div>
</body>
</html>"),

            DocumentTemplate.Create(
                name: "Classic Corporate",
                documentType: DocumentType.Invoice,
                description: "Traditional framed invoice design with formal header, boxed borders, and authorized stamp area.",
                isDefault: false,
                displayOrder: 2,
                liquidLayout: @"<!DOCTYPE html>
<html>
<head>
<meta charset=""utf-8"" />
<title>Tax Invoice {{ invoice.number }}</title>
<style>
body { font-family: 'Times New Roman', Times, serif; color: #000; padding: 30px; font-size: 13px; line-height: 1.4; }
.outer-border { border: 2px solid #000; padding: 20px; }
.top-header { text-align: center; border-bottom: 2px solid #000; padding-bottom: 15px; margin-bottom: 15px; }
.company-name { font-size: 22px; font-weight: bold; text-transform: uppercase; }
.doc-heading { font-size: 18px; font-weight: bold; margin-top: 8px; text-decoration: underline; }
.info-row { display: flex; justify-content: space-between; margin-bottom: 15px; }
.box { border: 1px solid #000; padding: 10px; width: 48%; }
table { width: 100%; border-collapse: collapse; margin-top: 15px; }
th, td { border: 1px solid #000; padding: 8px; text-align: left; }
th { background: #eee; font-weight: bold; }
.text-right { text-align: right; }
.sign-row { display: flex; justify-content: space-between; margin-top: 50px; }
.sign-line { border-top: 1px solid #000; width: 200px; text-align: center; padding-top: 5px; font-weight: bold; }
</style>
</head>
<body>
<div class=""outer-border"">
    <div class=""top-header"">
        <div class=""company-name"">{{ organization.name }}</div>
        <div>{{ organization.address }}</div>
        <div>Tel: {{ organization.phone }} | Email: {{ organization.email }}</div>
        {% if organization.tin %}<div>TIN: {{ organization.tin }}</div>{% endif %}
        <div class=""doc-heading"">{{ invoice.document_title }}</div>
    </div>
    <div class=""info-row"">
        <div class=""box"">
            <strong>CUSTOMER DETAILS:</strong><br/>
            Name: {{ invoice.customer_name }}<br/>
            Address: {{ invoice.customer_address }}<br/>
            Phone: {{ invoice.customer_phone }}<br/>
            TIN: {{ invoice.customer_tin }}
        </div>
        <div class=""box"">
            <strong>INVOICE DETAILS:</strong><br/>
            Invoice No: {{ invoice.number }}<br/>
            Date: {{ invoice.issue_date }}<br/>
            Due Date: {{ invoice.due_date }}<br/>
            Ref No: {{ invoice.reference_number }}
        </div>
    </div>
    <table>
        <thead>
            <tr><th>No</th><th>Item Description</th><th class=""text-right"">Qty</th><th class=""text-right"">Unit Price</th><th class=""text-right"">Amount</th></tr>
        </thead>
        <tbody>
        {% for line in invoice.lines %}
            <tr>
                <td>{{ forloop.index }}</td>
                <td>{{ line.description }}</td>
                <td class=""text-right"">{{ line.quantity }} {{ line.unit_of_measure }}</td>
                <td class=""text-right"">{{ line.unit_price }}</td>
                <td class=""text-right"">{{ line.line_total }}</td>
            </tr>
        {% endfor %}
        </tbody>
        <tfoot>
            <tr><th colspan=""4"" class=""text-right"">Total Amount:</th><th class=""text-right"">{{ invoice.currency }} {{ invoice.total_amount }}</th></tr>
        </tfoot>
    </table>
    <div class=""sign-row"">
        <div class=""sign-line"">Prepared By</div>
        <div class=""sign-line"">Authorized Signature & Stamp</div>
    </div>
</div>
</body>
</html>"),

            DocumentTemplate.Create(
                name: "Standard Logistics",
                documentType: DocumentType.DeliveryNote,
                description: "Industrial delivery dispatch note with driver, vehicle, and dual-quantity verification columns.",
                isDefault: true,
                displayOrder: 1,
                liquidLayout: @"<!DOCTYPE html>
<html>
<head>
<meta charset=""utf-8"" />
<title>Delivery Note {{ delivery_note.number }}</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; padding: 32px; color: #0f172a; font-size: 14px; }
.header { border-bottom: 2px solid {{ theme.primary_hex }}; padding-bottom: 16px; margin-bottom: 20px; display: flex; justify-content: space-between; }
.title { font-size: 26px; font-weight: 800; color: {{ theme.primary_hex }}; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 24px; }
.panel { background: #f8fafc; border: 1px solid #e2e8f0; padding: 14px; border-radius: 6px; }
.panel-title { font-size: 12px; font-weight: bold; text-transform: uppercase; color: {{ theme.secondary_hex }}; margin-bottom: 4px; }
table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
th { background: {{ theme.primary_hex }}; color: #fff; padding: 10px; text-align: left; }
td { border-bottom: 1px solid #e2e8f0; padding: 10px; }
.text-right { text-align: right; }
.sign-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; margin-top: 40px; }
.sign-box { border: 1px dashed #94a3b8; padding: 20px; border-radius: 6px; text-align: center; }
</style>
</head>
<body>
<div class=""header"">
    <div>
        <div style=""font-size: 20px; font-weight: bold;"">{{ organization.name }}</div>
        <div>{{ organization.address }}</div>
        <div>{{ organization.phone }}</div>
    </div>
    <div style=""text-align: right;"">
        <div class=""title"">DELIVERY NOTE</div>
        <div style=""font-weight: bold; font-size: 16px;""># {{ delivery_note.number }}</div>
        <div>Date: {{ delivery_note.issue_date }}</div>
        {% if delivery_note.invoice_number %}<div>Invoice: <strong>{{ delivery_note.invoice_number }}</strong></div>{% endif %}
    </div>
</div>

<div class=""grid"">
    <div class=""panel"">
        <div class=""panel-title"">Recipient Information</div>
        <div style=""font-size: 16px; font-weight: bold;"">{{ delivery_note.customer_name }}</div>
        {% if delivery_note.customer_attention %}<div>Attn: {{ delivery_note.customer_attention }}</div>{% endif %}
        <div>Phone: {{ delivery_note.customer_phone }}</div>
        <div>Address: {{ delivery_note.delivery_address }}</div>
    </div>
    <div class=""panel"">
        <div class=""panel-title"">Transport & Dispatch Details</div>
        <div>Vehicle Reg No: <strong>{{ delivery_note.vehicle_number }}</strong></div>
        <div>Driver Name: <strong>{{ delivery_note.driver_name }}</strong></div>
        <div>Driver Phone: <strong>{{ delivery_note.driver_phone }}</strong></div>
        <div>Status: <strong>{{ delivery_note.status }}</strong></div>
    </div>
</div>

<table>
<thead>
    <tr>
        <th>#</th>
        <th>Item Description</th>
        <th class=""text-right"">Qty Ordered</th>
        <th class=""text-right"">Qty Delivered</th>
    </tr>
</thead>
<tbody>
{% for item in delivery_note.items %}
    <tr>
        <td>{{ forloop.index }}</td>
        <td>{{ item.description }}</td>
        <td class=""text-right"">{{ item.quantity_ordered }} {{ item.unit_of_measure }}</td>
        <td class=""text-right"" style=""font-weight: bold;"">{{ item.quantity_delivered }} {{ item.unit_of_measure }}</td>
    </tr>
{% endfor %}
</tbody>
</table>

<div class=""sign-grid"">
    <div class=""sign-box"">
        <div style=""margin-bottom: 40px;"">Dispatched By (Driver / Warehouse)</div>
        <div style=""font-weight: bold;"">{{ delivery_note.driver_name }}</div>
        <div>Signature & Date</div>
    </div>
    <div class=""sign-box"">
        <div style=""margin-bottom: 40px;"">Received In Good Condition By</div>
        <div style=""font-weight: bold;"">{{ delivery_note.received_by_name | default: 'Name & Stamp' }}</div>
        <div>Signature & Date</div>
    </div>
</div>
</body>
</html>"),

            DocumentTemplate.Create(
                name: "Thermal POS Slip",
                documentType: DocumentType.Invoice,
                description: "Compact 80mm monospace slip format ideal for thermal receipt rolls.",
                isDefault: false,
                displayOrder: 3,
                liquidLayout: @"<!DOCTYPE html>
<html>
<head>
<meta charset=""utf-8"" />
<title>Receipt {{ invoice.number }}</title>
<style>
body { font-family: monospace; font-size: 12px; width: 300px; margin: 0 auto; padding: 10px; color: #000; }
.center { text-align: center; }
.dashed { border-top: 1px dashed #000; margin: 8px 0; }
table { width: 100%; border-collapse: collapse; }
.right { text-align: right; }
</style>
</head>
<body>
<div class=""center"">
    <strong>{{ organization.name }}</strong><br/>
    {{ organization.phone }}<br/>
    {{ invoice.document_title }}<br/>
    #{{ invoice.number }} | {{ invoice.issue_date }}
</div>
<div class=""dashed""></div>
<div>Cust: {{ invoice.customer_name }}</div>
<div class=""dashed""></div>
<table>
{% for line in invoice.lines %}
<tr>
    <td colspan=""2"">{{ line.description }}</td>
</tr>
<tr>
    <td>{{ line.quantity }}x {{ line.unit_price }}</td>
    <td class=""right"">{{ line.line_total }}</td>
</tr>
{% endfor %}
</table>
<div class=""dashed""></div>
<table>
<tr><td>TOTAL:</td><td class=""right""><strong>{{ invoice.currency }} {{ invoice.total_amount }}</strong></td></tr>
{% if invoice.amount_paid > 0 %}
<tr><td>PAID:</td><td class=""right"">{{ invoice.currency }} {{ invoice.amount_paid }}</td></tr>
<tr><td>BALANCE:</td><td class=""right"">{{ invoice.currency }} {{ invoice.balance_due }}</td></tr>
{% endif %}
</table>
<div class=""dashed""></div>
<div class=""center"">
    Thank you for your business!
</div>
</body>
</html>")
        };

        await _db.DocumentTemplates.AddRangeAsync(templates, cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("Seeded {Count} default marketplace document templates.", templates.Count);
    }
}

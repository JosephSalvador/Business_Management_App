namespace BusinessOS.Infrastructure.Persistence;

/// <summary>
/// PostgreSQL schema catalog. All tables live in the `public` schema during Platform and
/// Foundation phases to keep migrations simple. When a bounded context is ready to move into
/// its own schema (Sales, Inventory, Accounting must be stable first), change only the matching
/// constant below and generate one migration — every mapping picks its schema up from here.
/// </summary>
public static class Schemas
{
    public const string Organization = "public";
    public const string Identity = "public";
    public const string Catalog = "public";
    public const string Inventory = "public";
    public const string Pricing = "public";
    public const string Platform = "public";
    public const string Sales = "public";
    public const string Purchasing = "public";
    public const string Accounting = "public";
}

/// <summary>
/// Table-name catalog grouped by bounded context. Mappings reference these constants instead of
/// raw strings so a table rename or re-schematization happens in exactly one place.
/// </summary>
public static class Tables
{
    public static class Organization
    {
        public const string Tenants = "Tenants";
        public const string Branches = "Branches";
    }

    public static class Identity
    {
        public const string Users = "Users";
        public const string UserBranches = "UserBranches";
        public const string Roles = "Roles";
        public const string Permissions = "Permissions";
        public const string UserRoles = "UserRoles";
        public const string RolePermissions = "RolePermissions";
        public const string RefreshTokens = "RefreshTokens";
    }

    public static class Catalog
    {
        public const string ProductCategories = "ProductCategories";
        public const string Brands = "Brands";
        public const string UnitsOfMeasure = "UnitsOfMeasure";
        public const string Products = "Products";
        public const string ProductVariants = "ProductVariants";
    }

    public static class Inventory
    {
        public const string Warehouses = "Warehouses";
        public const string StockLocations = "StockLocations";
        public const string StockBalances = "StockBalances";
        public const string StockMovements = "StockMovements";
        public const string Transfers = "Transfers";
        public const string TransferLines = "TransferLines";
        public const string StockCounts = "StockCounts";
        public const string StockBatches = "StockBatches";
    }

    public static class Pricing
    {
        public const string PriceLists = "PriceLists";
        public const string ProductPrices = "ProductPrices";
    }

    public static class Platform
    {
        public const string AuditLogs = "AuditLogs";
        public const string FeatureFlags = "FeatureFlags";
        public const string OutboxMessages = "OutboxMessages";
    }

    public static class Sales
    {
        public const string TaxCategories = "TaxCategories";
        public const string TaxRegimes = "TaxRegimes";
        public const string TaxRules = "TaxRules";
        public const string TaxExemptions = "TaxExemptions";
        public const string SalesTable = "Sales";
        public const string SaleLines = "SaleLines";
        public const string SalePayments = "SalePayments";
        public const string NumberSequences = "NumberSequences";
    }

    public static class Purchasing
    {
        public const string Suppliers = "Suppliers";
        public const string PurchaseOrders = "PurchaseOrders";
        public const string PurchaseOrderLines = "PurchaseOrderLines";
        public const string SupplierBills = "SupplierBills";
        public const string SupplierPayments = "SupplierPayments";
    }

    public static class Accounting
    {
        public const string Accounts = "Accounts";
        public const string JournalEntries = "JournalEntries";
        public const string JournalEntryLines = "JournalEntryLines";
        public const string TenantAccountMappings = "TenantAccountMappings";
    }
}

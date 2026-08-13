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
    public const string Platform = "public";
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

    public static class Platform
    {
        public const string AuditLogs = "AuditLogs";
        public const string FeatureFlags = "FeatureFlags";
        public const string OutboxMessages = "OutboxMessages";
    }
}

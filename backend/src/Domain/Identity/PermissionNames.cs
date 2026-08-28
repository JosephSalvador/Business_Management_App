namespace BusinessOS.Domain.Identity;

public static class PermissionNames
{
    public const string DashboardView = "Dashboard.View";

    public const string OrganizationsView = "Organizations.View";
    public const string OrganizationsManage = "Organizations.Manage";

    public const string BranchesView = "Branches.View";
    public const string BranchesCreate = "Branches.Create";
    public const string BranchesUpdate = "Branches.Update";
    public const string BranchesDelete = "Branches.Delete";

    public const string UsersView = "Users.View";
    public const string UsersCreate = "Users.Create";
    public const string UsersUpdate = "Users.Update";
    public const string UsersDelete = "Users.Delete";

    public const string RolesView = "Roles.View";
    public const string RolesManage = "Roles.Manage";

    public const string SalesCreate = "Sales.Create";
    public const string SalesView = "Sales.View";
    public const string SalesDelete = "Sales.Delete";
    public const string SalesReportsView = "Sales.ReportsView";
    public const string SalesReportsExport = "Sales.ReportsExport";

    public const string ProductsView = "Products.View";
    public const string ProductsCreate = "Products.Create";
    public const string ProductsUpdate = "Products.Update";
    public const string ProductsDelete = "Products.Delete";

    public const string CategoriesView = "Categories.View";
    public const string CategoriesManage = "Categories.Manage";

    public const string BrandsView = "Brands.View";
    public const string BrandsManage = "Brands.Manage";

    public const string UnitsView = "Units.View";
    public const string UnitsManage = "Units.Manage";

    public const string WarehousesView = "Warehouses.View";
    public const string WarehousesCreate = "Warehouses.Create";
    public const string WarehousesUpdate = "Warehouses.Update";
    public const string WarehousesDelete = "Warehouses.Delete";

    public const string InventoryView = "Inventory.View";
    public const string InventoryManage = "Inventory.Manage";

    public const string PricingView = "Pricing.View";
    public const string PricingManage = "Pricing.Manage";

    public const string AccountingView = "Accounting.View";
    public const string AccountingCreate = "Accounting.Create";
    public const string AccountingApprove = "Accounting.Approve";

    public const string PurchasingView = "Purchasing.View";
    public const string PurchasingManage = "Purchasing.Manage";

    public const string AuditView = "Audit.View";

    public static IReadOnlyList<string> All { get; } = new[]
    {
        DashboardView,
        OrganizationsView, OrganizationsManage,
        BranchesView, BranchesCreate, BranchesUpdate, BranchesDelete,
        UsersView, UsersCreate, UsersUpdate, UsersDelete,
        RolesView, RolesManage,
        SalesCreate, SalesView, SalesDelete, SalesReportsView, SalesReportsExport,
        ProductsView, ProductsCreate, ProductsUpdate, ProductsDelete,
        CategoriesView, CategoriesManage,
        BrandsView, BrandsManage,
        UnitsView, UnitsManage,
        WarehousesView, WarehousesCreate, WarehousesUpdate, WarehousesDelete,
        InventoryView, InventoryManage,
        PricingView, PricingManage,
        AccountingView, AccountingCreate, AccountingApprove,
        PurchasingView, PurchasingManage,
        AuditView,
    };

    /// <summary>
    /// Permissions granted to the system Staff role: run the POS (create sales),
    /// read products/stock and see sales history. Staff cannot manage the
    /// business, users, roles, pricing or finances.
    /// </summary>
    public static IReadOnlyList<string> Staff { get; } = new[]
    {
        DashboardView,
        SalesCreate, SalesView,
        SalesReportsView,
        ProductsView,
        CategoriesView,
        BrandsView,
        UnitsView,
        InventoryView,
        WarehousesView,
    };
}

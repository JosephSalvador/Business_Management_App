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

    public const string InventoryView = "Inventory.View";
    public const string InventoryManage = "Inventory.Manage";

    public const string AccountingView = "Accounting.View";
    public const string AccountingApprove = "Accounting.Approve";

    public const string AuditView = "Audit.View";

    public static IReadOnlyList<string> All { get; } = new[]
    {
        DashboardView,
        OrganizationsView, OrganizationsManage,
        BranchesView, BranchesCreate, BranchesUpdate, BranchesDelete,
        UsersView, UsersCreate, UsersUpdate, UsersDelete,
        RolesView, RolesManage,
        SalesCreate, SalesView, SalesDelete,
        ProductsView, ProductsCreate, ProductsUpdate, ProductsDelete,
        CategoriesView, CategoriesManage,
        BrandsView, BrandsManage,
        UnitsView, UnitsManage,
        InventoryView, InventoryManage,
        AccountingView, AccountingApprove,
        AuditView,
    };
}

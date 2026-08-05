namespace BusinessOS.Domain.Identity;

public static class PermissionNames
{
    public const string DashboardView = "Dashboard.View";

    public const string UsersView = "Users.View";
    public const string UsersCreate = "Users.Create";
    public const string UsersUpdate = "Users.Update";
    public const string UsersDelete = "Users.Delete";

    public const string RolesView = "Roles.View";
    public const string RolesManage = "Roles.Manage";

    public const string SalesCreate = "Sales.Create";
    public const string SalesView = "Sales.View";
    public const string SalesDelete = "Sales.Delete";

    public const string InventoryView = "Inventory.View";
    public const string InventoryManage = "Inventory.Manage";

    public const string AccountingView = "Accounting.View";
    public const string AccountingApprove = "Accounting.Approve";

    public const string AuditView = "Audit.View";

    public static IReadOnlyList<string> All { get; } = new[]
    {
        DashboardView,
        UsersView, UsersCreate, UsersUpdate, UsersDelete,
        RolesView, RolesManage,
        SalesCreate, SalesView, SalesDelete,
        InventoryView, InventoryManage,
        AccountingView, AccountingApprove,
        AuditView,
    };
}

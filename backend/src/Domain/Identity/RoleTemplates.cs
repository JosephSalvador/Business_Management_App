namespace BusinessOS.Domain.Identity;

/// <summary>
/// The small, ready-to-use role set created with a new business. Starter roles are
/// deliberately ordinary roles: a business can adjust or remove them without being
/// constrained by the platform's system-role rules.
/// </summary>
public static class RoleTemplates
{
    public static IReadOnlyList<RoleTemplate> Starter { get; } =
    [
        new(
            "Manager",
            "Husimamia shughuli za kila siku, mauzo, bidhaa na wafanyakazi.",
            [
                PermissionNames.DashboardView,
                PermissionNames.OrganizationsView,
                PermissionNames.BranchesView, PermissionNames.BranchesCreate, PermissionNames.BranchesUpdate, PermissionNames.BranchesDelete,
                PermissionNames.UsersView, PermissionNames.UsersCreate, PermissionNames.UsersUpdate,
                PermissionNames.RolesView,
                PermissionNames.SalesCreate, PermissionNames.SalesView, PermissionNames.SalesDelete, PermissionNames.SalesReportsView, PermissionNames.SalesReportsExport,
                PermissionNames.ProductsView, PermissionNames.ProductsCreate, PermissionNames.ProductsUpdate, PermissionNames.ProductsDelete,
                PermissionNames.CategoriesView, PermissionNames.CategoriesManage,
                PermissionNames.BrandsView, PermissionNames.BrandsManage,
                PermissionNames.UnitsView, PermissionNames.UnitsManage,
                PermissionNames.WarehousesView, PermissionNames.WarehousesCreate, PermissionNames.WarehousesUpdate, PermissionNames.WarehousesDelete,
                PermissionNames.InventoryView, PermissionNames.InventoryManage,
                PermissionNames.PricingView, PermissionNames.PricingManage,
                PermissionNames.PurchasingView, PermissionNames.PurchasingManage,
                PermissionNames.CustomersView, PermissionNames.CustomersCreate, PermissionNames.CustomersUpdate, PermissionNames.CustomersDelete,
                PermissionNames.ExpensesView, PermissionNames.ExpensesCreate, PermissionNames.ExpensesUpdate,
                PermissionNames.ReceiptsView, PermissionNames.ReceiptsPrint, PermissionNames.ReceiptsManageLayouts,
                PermissionNames.InvoicesView, PermissionNames.InvoicesCreate, PermissionNames.InvoicesManage,
                PermissionNames.NotificationsView, PermissionNames.NotificationsManage,
            ]),
        new(
            "Cashier",
            "Hufanya mauzo na kuchapisha risiti bila kubadilisha mipangilio ya biashara.",
            [
                PermissionNames.DashboardView,
                PermissionNames.SalesCreate, PermissionNames.SalesView,
                PermissionNames.ProductsView, PermissionNames.CategoriesView, PermissionNames.BrandsView, PermissionNames.UnitsView,
                PermissionNames.InventoryView, PermissionNames.WarehousesView,
                PermissionNames.PricingView,
                PermissionNames.CustomersView, PermissionNames.CustomersCreate, PermissionNames.CustomersUpdate,
                PermissionNames.ReceiptsView, PermissionNames.ReceiptsPrint,
                PermissionNames.NotificationsView,
            ]),
        new(
            "Inventory Officer",
            "Husimamia bidhaa, maghala na viwango vya stok.",
            [
                PermissionNames.DashboardView,
                PermissionNames.ProductsView, PermissionNames.ProductsCreate, PermissionNames.ProductsUpdate, PermissionNames.ProductsDelete,
                PermissionNames.CategoriesView, PermissionNames.CategoriesManage,
                PermissionNames.BrandsView, PermissionNames.BrandsManage,
                PermissionNames.UnitsView, PermissionNames.UnitsManage,
                PermissionNames.WarehousesView, PermissionNames.WarehousesCreate, PermissionNames.WarehousesUpdate, PermissionNames.WarehousesDelete,
                PermissionNames.InventoryView, PermissionNames.InventoryManage,
                PermissionNames.PricingView,
                PermissionNames.NotificationsView,
            ]),
        new(
            "Accountant",
            "Husimamia hesabu, matumizi na ripoti za biashara.",
            [
                PermissionNames.DashboardView,
                PermissionNames.SalesView, PermissionNames.SalesReportsView, PermissionNames.SalesReportsExport,
                PermissionNames.AccountingView, PermissionNames.AccountingCreate, PermissionNames.AccountingApprove,
                PermissionNames.PurchasingView,
                PermissionNames.CustomersView,
                PermissionNames.ExpensesView, PermissionNames.ExpensesCreate, PermissionNames.ExpensesUpdate, PermissionNames.ExpensesDelete,
                PermissionNames.ReceiptsView, PermissionNames.ReceiptsPrint,
                PermissionNames.InvoicesView,
                PermissionNames.AuditView,
                PermissionNames.NotificationsView,
            ]),
    ];
}

public sealed record RoleTemplate(
    string Name,
    string Description,
    IReadOnlyList<string> PermissionNames);

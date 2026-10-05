import '../../../l10n/generated/app_localizations.dart';
import '../data/role_models.dart';

class PermissionGroup {
  const PermissionGroup({required this.label, required this.permissions});

  final String label;
  final List<Permission> permissions;
}

List<PermissionGroup> groupPermissionsByArea(List<Permission> permissions) {
  final groups = <String, List<Permission>>{};
  for (final permission in permissions) {
    final area = permission.name.split('.').first;
    groups.putIfAbsent(area, () => []).add(permission);
  }

  return groups.entries
      .map(
        (entry) => PermissionGroup(
          label: entry.key,
          permissions: entry.value..sort((a, b) => a.name.compareTo(b.name)),
        ),
      )
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));
}

/// Display label for a permission-area key (example: `Products`).
String roleAreaLabel(AppLocalizations loc, String area) => switch (area) {
      'Accounting' => loc.permAccounting,
      'Audit' => loc.permAudit,
      'Branches' => loc.permBranches,
      'Brands' => loc.permBrands,
      'Categories' => loc.permCategories,
      'Customers' => loc.permCustomers,
      'Dashboard' => loc.permDashboard,
      'Expenses' => loc.permExpenses,
      'Inventory' => loc.permInventory,
      'Organizations' => loc.permOrganizations,
      'Pricing' => loc.permPricing,
      'Products' => loc.permProducts,
      'Purchasing' => loc.permPurchasing,
      'Receipts' => loc.permReceipts,
      'Roles' => loc.permRoles,
      'Sales' => loc.permSales,
      'Units' => loc.permUnits,
      'Users' => loc.permUsers,
      'Warehouses' => loc.permWarehouses,
      _ => area,
    };

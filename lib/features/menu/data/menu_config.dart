class MenuItem {
  final String title;
  final String route;
  final String icon;
  final List<String> requiredPrivileges;
  final int sortOrder;

  const MenuItem({
    required this.title,
    required this.route,
    required this.icon,
    required this.requiredPrivileges,
    this.sortOrder = 0,
  });
}

class MenuConfig {
  static List<MenuItem> get allMenuItems => [
    const MenuItem(
      title: 'Dashboard',
      route: '/dashboard',
      icon: 'dashboard',
      requiredPrivileges: [], // Available to all logged-in users
      sortOrder: 0,
    ),
    const MenuItem(
      title: 'User Management',
      route: '/users',
      icon: 'people',
      requiredPrivileges: ['Manage Users'],
      sortOrder: 1,
    ),
    const MenuItem(
      title: 'Product Management',
      route: '/products',
      icon: 'inventory',
      requiredPrivileges: ['View Products'],
      sortOrder: 2,
    ),
    const MenuItem(
      title: 'Add Product',
      route: '/products/add',
      icon: 'add_box',
      requiredPrivileges: ['Add Product'],
      sortOrder: 3,
    ),
    const MenuItem(
      title: 'Sales',
      route: '/sales',
      icon: 'point_of_sale',
      requiredPrivileges: ['View Sales'],
      sortOrder: 4,
    ),
    const MenuItem(
      title: 'New Sale',
      route: '/sales/new',
      icon: 'add_shopping_cart',
      requiredPrivileges: ['Create New Sales'],
      sortOrder: 5,
    ),
    const MenuItem(
      title: 'Sales History',
      route: '/sales/history',
      icon: 'history',
      requiredPrivileges: ['View Own Sales History'],
      sortOrder: 6,
    ),
    const MenuItem(
      title: 'Expenses',
      route: '/expenses',
      icon: 'receipt',
      requiredPrivileges: ['View All Expenses'],
      sortOrder: 7,
    ),
    const MenuItem(
      title: 'Financial Reports',
      route: '/reports/financial',
      icon: 'analytics',
      requiredPrivileges: ['Generate Financial Reports'],
      sortOrder: 8,
    ),
    const MenuItem(
      title: 'Department Reports',
      route: '/reports/department',
      icon: 'assessment',
      requiredPrivileges: ['Generate Department Reports'],
      sortOrder: 9,
    ),
    const MenuItem(
      title: 'All Reports',
      route: '/reports',
      icon: 'summarize',
      requiredPrivileges: ['Generate Reports', 'View Reports'],
      sortOrder: 10,
    ),
    const MenuItem(
      title: 'Inventory',
      route: '/inventory',
      icon: 'warehouse',
      requiredPrivileges: ['View Inventory'],
      sortOrder: 11,
    ),
    const MenuItem(
      title: 'Invoices',
      route: '/invoices',
      icon: 'description',
      requiredPrivileges: ['Manage Invoices'],
      sortOrder: 12,
    ),
    const MenuItem(
      title: 'System Settings',
      route: '/settings',
      icon: 'settings',
      requiredPrivileges: ['System Settings'],
      sortOrder: 99,
    ),
  ];

  static List<MenuItem> getMenuItemsForPrivileges(List<String> userPrivileges) {
    return allMenuItems
        .where((item) => 
            item.requiredPrivileges.isEmpty ||
            item.requiredPrivileges.any(userPrivileges.contains))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}


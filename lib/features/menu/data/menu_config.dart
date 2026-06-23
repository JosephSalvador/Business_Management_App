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
      requiredPrivileges: [],
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
      title: 'Sales',
      route: '/sales',
      icon: 'point_of_sale',
      requiredPrivileges: ['View Sales'],
      sortOrder: 2,
    ),
    const MenuItem(
      title: 'New Sale',
      route: '/sales/new',
      icon: 'add_shopping_cart',
      requiredPrivileges: ['Create New Sales'],
      sortOrder: 3,
    ),
    const MenuItem(
      title: 'Sales History',
      route: '/sales/history',
      icon: 'history',
      requiredPrivileges: ['View Own Sales History'],
      sortOrder: 4,
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

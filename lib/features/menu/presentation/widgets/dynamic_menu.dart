import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../data/menu_config.dart';

class DynamicMenu extends StatelessWidget {
  const DynamicMenu({super.key});

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'dashboard':
        return Icons.dashboard;
      case 'people':
        return Icons.people;
      case 'inventory':
        return Icons.inventory_2;
      case 'add_box':
        return Icons.add_box;
      case 'point_of_sale':
        return Icons.point_of_sale;
      case 'add_shopping_cart':
        return Icons.add_shopping_cart;
      case 'history':
        return Icons.history;
      case 'receipt':
        return Icons.receipt;
      case 'analytics':
        return Icons.analytics;
      case 'assessment':
        return Icons.assessment;
      case 'summarize':
        return Icons.summarize;
      case 'warehouse':
        return Icons.warehouse;
      case 'description':
        return Icons.description;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userPrivileges = userProvider.currentUserPrivileges;
    final menuItems = MenuConfig.getMenuItemsForPrivileges(userPrivileges);

    return Drawer(
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            accountName: Text(
              userProvider.currentUser?.fullName ?? 'Guest',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              userProvider.currentUser?.role ?? 'No Role',
              style: GoogleFonts.inter(
                color: Colors.white70,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                userProvider.currentUser?.fullName.substring(0, 1) ?? 'G',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade700, Colors.blue.shade400],
              ),
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return ListTile(
                  leading: Icon(
                    _getIconData(item.icon),
                    color: Colors.blue.shade600,
                  ),
                  title: Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    Navigator.of(context).pop(); // Close drawer
                    context.go(item.route);
                  },
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, size: 20),
                  title: Text(
                    'Profile',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, size: 20),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Provider.of<UserProvider>(context, listen: false).logout();
                context.go('/login');
              },
              child: Text(
                'Logout',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

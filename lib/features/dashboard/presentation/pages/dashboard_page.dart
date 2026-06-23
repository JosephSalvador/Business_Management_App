// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../menu/presentation/widgets/dynamic_menu.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../core/utils/responsive.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _getWelcomeMessage(String role, String name) {
    switch (role) {
      case 'Admin':
        return 'Welcome, $name 👑';
      case 'Manager':
        return 'Hello, $name 📊';
      case 'Salesperson':
        return 'Great to see you, $name 💼';
      case 'Accountant':
        return 'Welcome back, $name 📈';
      case 'Viewer':
        return 'Hello, $name 👀';
      default:
        return 'Welcome, $name';
    }
  }

  String _getRoleDescription(String? role) {
    switch (role) {
      case 'Admin':
        return 'Full system access';
      case 'Manager':
        return 'Department management';
      case 'Salesperson':
        return 'Sales operations';
      case 'Accountant':
        return 'Financial management';
      case 'Viewer':
        return 'Read-only access';
      default:
        return 'Limited access';
    }
  }

  Widget _buildQuickAction(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: non_constant_identifier_names
  Widget _StatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // ignore: deprecated_member_use
            colors: [color.withOpacity(0.85), color.withOpacity(0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    // Define Quick Actions dynamically
    final quickActions = [
      {
        'title': 'Manage Products',
        'icon': Icons.inventory_2,
        'color': Colors.blue,
        'privilege': 'View Products',
        'onTap': () {}
      },
      {
        'title': 'View Sales',
        'icon': Icons.point_of_sale,
        'color': Colors.green,
        'privilege': 'View Sales',
        'onTap': () {}
      },
      {
        'title': 'Generate Reports',
        'icon': Icons.analytics,
        'color': Colors.orange,
        'privilege': 'Generate Reports',
        'onTap': () {}
      },
    ];

    // Define Quick Stats dynamically
    final quickStats = [
      {
        'title': 'Total Products',
        'value': '1,234',
        'icon': Icons.inventory_2,
        'color': Colors.blue,
        'privilege': 'View Products',
      },
      {
        'title': 'Today\'s Sales',
        'value': '\$12,567',
        'icon': Icons.point_of_sale,
        'color': Colors.green,
        'privilege': 'View Sales',
      },
      {
        'title': 'Pending Tasks',
        'value': '12',
        'icon': Icons.task,
        'color': Colors.orange,
        'privilege': null, // visible to all
      },
      {
        'title': 'New Messages',
        'value': '5',
        'icon': Icons.message,
        'color': Colors.purple,
        'privilege': null, // visible to all
      },
    ];

    // Determine columns for Quick Stats grid
    int gridColumns = Responsive.isDesktop(context)
        ? 4
        : Responsive.isTablet(context)
            ? 2
            : 1;

    // Determine spacing for Quick Actions
    double actionSpacing = Responsive.isMobile(context) ? 12 : 20;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                userProvider.logout(); // 👈 no need for context.go()
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child:
                    Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      drawer: const DynamicMenu(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (user?.fullName ?? 'U')[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getWelcomeMessage(
                                  user?.role ?? 'User',
                                  user?.fullName ?? 'User'),
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Role: ${user?.role ?? 'No Role'} • ${_getRoleDescription(user?.role)}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Quick Actions
              Text(
                'Quick Actions',
                style:
                    GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: actionSpacing,
                runSpacing: actionSpacing,
                children: quickActions
                    .where((action) =>
                        action['privilege'] == null ||
                        userProvider.hasPrivilege(action['privilege'] as String))
                    .map((action) => SizedBox(
                          width: Responsive.isMobile(context)
                              ? double.infinity
                              : (Responsive.isTablet(context) ? 250 : 300),
                          child: _buildQuickAction(
                            action['title'] as String,
                            action['icon'] as IconData,
                            action['color'] as Color,
                            action['onTap'] as VoidCallback,
                          ),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 28),

              // Quick Stats
              Text(
                'Quick Stats',
                style:
                    GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: gridColumns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: Responsive.cardAspectRatio(context),
                children: quickStats
                    .where((stat) =>
                        stat['privilege'] == null ||
                        userProvider.hasPrivilege(stat['privilege'] as String))
                    .map((stat) => _StatCard(
                          title: stat['title'] as String,
                          value: stat['value'] as String,
                          icon: stat['icon'] as IconData,
                          color: stat['color'] as Color,
                          onTap: () {},
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: userProvider.hasPrivilege('Create New Sales')
          ? FloatingActionButton(
              onPressed: () {},
              backgroundColor: Colors.blue.shade700,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

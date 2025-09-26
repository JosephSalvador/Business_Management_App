import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../../menu/presentation/widgets/dynamic_menu.dart';
import '../../../../shared/providers/user_provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _getWelcomeMessage(String role, String name) {
    switch (role) {
      case 'Admin':
        return 'Welcome, $name! 👑';
      case 'Manager':
        return 'Hello, $name! 📊';
      case 'Salesperson':
        return 'Great to see you, $name! 💼';
      case 'Accountant':
        return 'Welcome back, $name! 📈';
      case 'Viewer':
        return 'Hello, $name! 👀';
      default:
        return 'Welcome, $name!';
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

  Widget _buildQuickAction(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  Widget _StatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

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
                userProvider.logout();
                context.go('/login');
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Text('Profile', style: GoogleFonts.inter()),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Text('Settings', style: GoogleFonts.inter()),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      drawer: const DynamicMenu(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getWelcomeMessage(user?.role ?? 'User', user?.fullName ?? 'User'),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Role: ${user?.role ?? 'No Role'} • ${_getRoleDescription(user?.role)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (userProvider.hasPrivilege('View Products'))
                      _buildQuickAction(
                        'Manage Products',
                        Icons.inventory_2,
                        Colors.blue,
                        () {},
                      ),
                    if (userProvider.hasPrivilege('View Sales'))
                      _buildQuickAction(
                        'View Sales',
                        Icons.point_of_sale,
                        Colors.green,
                        () {},
                      ),
                    if (userProvider.hasPrivilege('Generate Reports'))
                      _buildQuickAction(
                        'Generate Reports',
                        Icons.analytics,
                        Colors.orange,
                        () {},
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            Text(
              'Quick Stats',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  title: 'Total Products',
                  value: '1,234',
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                  onTap: userProvider.hasPrivilege('View Products') ? () {} : null,
                ),
                _StatCard(
                  title: 'Today\'s Sales',
                  value: '\$12,567',
                  icon: Icons.point_of_sale,
                  color: Colors.green,
                  onTap: userProvider.hasPrivilege('View Sales') ? () {} : null,
                ),
                _StatCard(
                  title: 'Pending Tasks',
                  value: '12',
                  icon: Icons.task,
                  color: Colors.orange,
                  onTap: () {},
                ),
                _StatCard(
                  title: 'New Messages',
                  value: '5',
                  icon: Icons.message,
                  color: Colors.purple,
                  onTap: () {},
                ),
              ],
            ),
          ],
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
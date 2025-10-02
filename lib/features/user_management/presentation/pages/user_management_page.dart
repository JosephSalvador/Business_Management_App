import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/providers/user_provider.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final DateTime joinDate;
  final String avatar;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.joinDate,
    required this.avatar,
  });
}

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final List<User> _users = [
    User(
      id: '1',
      name: 'John Smith',
      email: 'john.smith@company.com',
      role: 'Admin',
      status: 'Active',
      joinDate: DateTime(2023, 1, 15),
      avatar: 'JS',
    ),
    User(
      id: '2',
      name: 'Sarah Johnson',
      email: 'sarah.j@company.com',
      role: 'Manager',
      status: 'Active',
      joinDate: DateTime(2023, 3, 20),
      avatar: 'SJ',
    ),
    User(
      id: '3',
      name: 'Mike Wilson',
      email: 'mike.wilson@company.com',
      role: 'Salesperson',
      status: 'Active',
      joinDate: DateTime(2023, 5, 10),
      avatar: 'MW',
    ),
    User(
      id: '4',
      name: 'Emily Davis',
      email: 'emily.davis@company.com',
      role: 'Accountant',
      status: 'Inactive',
      joinDate: DateTime(2023, 2, 28),
      avatar: 'ED',
    ),
    User(
      id: '5',
      name: 'David Brown',
      email: 'david.b@company.com',
      role: 'Viewer',
      status: 'Active',
      joinDate: DateTime(2023, 6, 15),
      avatar: 'DB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (userProvider.hasPrivilege('Manage Users')) ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddUserDialog(),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          _buildStatsCards(),
          // User List
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) => _buildUserCard(_users[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: userProvider.hasPrivilege('Manage Users')
          ? FloatingActionButton(
              onPressed: () => _showAddUserDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildStatsCards() {
    final activeUsers = _users.where((user) => user.status == 'Active').length;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Total Users',
              value: _users.length.toString(),
              icon: Icons.people,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: 'Active Users',
              value: activeUsers.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.avatar,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(user.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _getRoleColor(user.role),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showUserDetails(user),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin': return Colors.red;
      case 'Manager': return Colors.orange;
      case 'Salesperson': return Colors.green;
      case 'Accountant': return Colors.purple;
      case 'Viewer': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    return status == 'Active' ? Colors.green : Colors.grey;
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Name: ${user.name}', style: GoogleFonts.inter()),
            Text('Email: ${user.email}', style: GoogleFonts.inter()),
            Text('Role: ${user.role}', style: GoogleFonts.inter()),
            Text('Status: ${user.status}', style: GoogleFonts.inter()),
            Text('Join Date: ${user.joinDate.toString().split(' ')[0]}', style: GoogleFonts.inter()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    // Implement add user dialog
  }

  void _showFilterDialog() {
    // Implement filter dialog
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
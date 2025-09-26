import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/providers/user_provider.dart';

class UserSelectionPage extends StatelessWidget {
  const UserSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mockUsers = MockUserData.mockUsers;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.business_center,
                      size: 64,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Business Management System',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a user to login',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // User List
              Expanded(
                child: ListView.builder(
                  itemCount: mockUsers.length,
                  itemBuilder: (context, index) {
                    final user = mockUsers[index];
                    return _UserCard(user: user);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.fullName.substring(0, 1),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          user.fullName,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.role} • ${user.username}',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: user.privileges.take(2).map((privilege) => Chip(
                label: Text(
                  privilege,
                  style: GoogleFonts.inter(fontSize: 10),
                ),
                backgroundColor: Colors.blue.shade50,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Provider.of<UserProvider>(context, listen: false).login(user);
          context.go('/dashboard');
        },
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin': return Colors.red.shade600;
      case 'Manager': return Colors.orange.shade600;
      case 'Salesperson': return Colors.green.shade600;
      case 'Accountant': return Colors.purple.shade600;
      case 'Viewer': return Colors.blue.shade600;
      default: return Colors.grey.shade600;
    }
  }
}
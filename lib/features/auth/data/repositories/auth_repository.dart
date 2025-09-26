import '../../../../shared/models/user_model.dart';

abstract class AuthRepository {
  Future<User> login(String username, String password); // Changed from User?
  Future<bool> register(User user, String password);
  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final List<User> _mockUsers = [
    User(
      id: '1',
      username: 'admin',
      email: 'admin@company.com',
      role: 'Admin',
      fullName: 'System Administrator',
      privileges: [
        'Manage Users',
        'View Products',
        'Add Product',
        'Edit Product',
        'Delete Product',
        'View Sales',
        'Generate Reports',
        'System Settings',
      ],
      createdAt: DateTime.now(),
    ),
    User(
      id: '2',
      username: 'manager',
      email: 'manager@company.com',
      role: 'Manager',
      fullName: 'Operations Manager',
      privileges: [
        'View Products',
        'Add Product',
        'Edit Product',
        'View Sales',
        'Generate Department Reports',
        'View Inventory',
      ],
      createdAt: DateTime.now(),
    ),
    User(
      id: '3',
      username: 'sales',
      email: 'sales@company.com',
      role: 'Salesperson',
      fullName: 'Sales Representative',
      privileges: [
        'View Products',
        'Create New Sales',
        'View Own Sales History',
        'Process Returns',
      ],
      createdAt: DateTime.now(),
    ),
    User(
      id: '4',
      username: 'accountant',
      email: 'accountant@company.com',
      role: 'Accountant',
      fullName: 'Financial Accountant',
      privileges: [
        'View All Expenses',
        'Generate Financial Reports',
        'View Sales Reports',
        'Manage Invoices',
      ],
      createdAt: DateTime.now(),
    ),
    User(
      id: '5',
      username: 'viewer',
      email: 'viewer@company.com',
      role: 'Viewer',
      fullName: 'Guest Viewer',
      privileges: [
        'View Reports',
        'View Products',
      ],
      createdAt: DateTime.now(),
    ),
  ];

  // Simple password mapping
  final Map<String, String> _userPasswords = {
    'admin': 'admin123',
    'manager': 'manager123',
    'sales': 'sales123',
    'accountant': 'accountant123',
    'viewer': 'viewer123',
  };

  @override
  Future<User> login(String username, String password) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    final user = _mockUsers.firstWhere(
      (user) => user.username == username,
      orElse: () => throw Exception('User not found'),
    );

    final correctPassword = _userPasswords[username];
    if (correctPassword == password) {
      return user;
    } else {
      throw Exception('Invalid password');
    }
  }

  @override
  Future<bool> register(User user, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
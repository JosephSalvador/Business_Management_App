class User {
  final String id;
  final String username;
  final String email;
  final String role;
  final List<String> privileges;
  final String fullName;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.privileges,
    required this.fullName,
    this.isActive = true,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: json['role'],
      privileges: List<String>.from(json['priviledges']),
      fullName: json['fullName'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      "role": role,
      'privileges': privileges,
      'fullName': fullName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class MockUserData {
  static List<User> get mockUsers => [
    User(
      id: '1',
      username: 'adminUser',
      email: 'admin@company.com',
      role: 'Admin',
      fullName: 'Admin User',
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
      username: 'managerUser',
      email: 'manager@company.com',
      role: 'Manager',
      fullName: 'Manager User',
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
      username: 'salesUser',
      email: 'sales@company.com',
      role: 'Salesperson',
      fullName: 'Sales User',
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
      username: 'accountantUser',
      email: 'accountant@company.com',
      role: 'Accountant',
      fullName: 'Accountant User',
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
      username: 'viewerUser',
      email: 'viewer@company.com',
      role: 'Viewer',
      fullName: 'Viewer User',
      privileges: [
        'View Reports',
        'View Products',
      ],
      createdAt: DateTime.now(),
    ),
  ];

  static User getDefaultUser() => mockUsers.first;
}
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final bool emailVerified;
  final List<String> roles;
  final DateTime? lastLogin;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.emailVerified,
    required this.roles,
    this.lastLogin,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'],
      emailVerified: json['emailVerified'] ?? false,
      roles: List<String>.from(json['roles'] ?? []),
      lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'emailVerified': emailVerified,
      'roles': roles,
      'lastLogin': lastLogin?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
class IdentityUser {
  const IdentityUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.isActive,
    required this.emailVerified,
    required this.isLockedOut,
    required this.roleIds,
    required this.branchIds,
    this.defaultBranchId,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final bool isActive;
  final bool emailVerified;
  final bool isLockedOut;
  final List<String> roleIds;
  final List<String> branchIds;
  final String? defaultBranchId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory IdentityUser.fromJson(Map<String, dynamic> json) => IdentityUser(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        phone: json['phone'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        emailVerified: json['emailVerified'] as bool? ?? false,
        isLockedOut: json['isLockedOut'] as bool? ?? false,
        roleIds:
            (json['roleIds'] as List<dynamic>?)?.cast<String>() ?? const [],
        branchIds:
            (json['branchIds'] as List<dynamic>?)?.cast<String>() ?? const [],
        defaultBranchId: json['defaultBranchId'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
}

class Role {
  const Role({
    required this.id,
    required this.name,
    this.description,
    required this.isSystem,
    required this.permissionNames,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final bool isSystem;
  final List<String> permissionNames;
  final DateTime createdAt;

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        isSystem: json['isSystem'] as bool? ?? false,
        permissionNames:
            (json['permissionNames'] as List<dynamic>?)?.cast<String>() ??
                const [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class Permission {
  const Permission({
    required this.name,
    this.description,
  });

  final String name;
  final String? description;

  factory Permission.fromJson(Map<String, dynamic> json) => Permission(
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
      );
}

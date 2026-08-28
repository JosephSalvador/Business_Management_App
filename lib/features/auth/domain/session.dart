/// Authenticated user as returned by the backend (`UserDto`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.isActive,
    required this.emailVerified,
    required this.permissions,
  });

  final String id;
  final String tenantId;
  final String email;
  final String fullName;
  final String? phone;
  final bool isActive;
  final bool emailVerified;
  final List<String> permissions;

  bool hasPermission(String permission) => permissions.contains(permission);

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

/// A live session: the user plus token expiry metadata. Token values
/// themselves live only in [TokenStore] — never in widget-visible state.
class Session {
  const Session({
    required this.user,
    required this.accessTokenExpiresAt,
  });

  final AuthUser user;
  final DateTime accessTokenExpiresAt;

  bool get isAccessTokenExpired =>
      DateTime.now().isAfter(accessTokenExpiresAt.toLocal());

  /// Parses backend date payloads defensively; epoch fallback keeps sessions
  /// usable even when the server omits the field.
  static DateTime parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Builds a session from the backend `AuthResponse` payload.
  factory Session.fromAuthResponse(Map<String, dynamic> json) {
    return Session(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      accessTokenExpiresAt: parseDate(json['accessTokenExpiresAt']),
    );
  }

  Session withUser(AuthUser updated) =>
      Session(user: updated, accessTokenExpiresAt: accessTokenExpiresAt);
}

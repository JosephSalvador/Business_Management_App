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
    this.twoFactorEnabled = false,
  });

  final String id;
  final String tenantId;
  final String email;
  final String fullName;
  final String? phone;
  final bool isActive;
  final bool emailVerified;
  final bool twoFactorEnabled;
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
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
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

/// Result of a password sign-in. Either the session is complete, or a second
/// factor is still pending and must be proven before any token is issued.
sealed class LoginOutcome {
  const LoginOutcome();
}

/// The account is signed in and tokens have been stored.
final class AuthenticatedLogin extends LoginOutcome {
  const AuthenticatedLogin(this.session);

  final Session session;
}

/// The password was correct but a second factor is pending. [challengeToken]
/// authorises exactly one verification attempt and carries no permissions.
final class MfaChallenge extends LoginOutcome {
  const MfaChallenge({
    required this.challengeToken,
    required this.email,
  });

  final String challengeToken;
  final String email;
}

/// A device currently holding a refresh token, as shown on the sessions screen.
class AuthSessionDevice {
  const AuthSessionDevice({
    required this.familyId,
    required this.device,
    required this.startedAt,
    required this.isCurrent,
    this.ipAddress,
  });

  final String familyId;
  final String device;
  final String? ipAddress;
  final DateTime startedAt;
  final bool isCurrent;

  factory AuthSessionDevice.fromJson(Map<String, dynamic> json) {
    return AuthSessionDevice(
      familyId: json['familyId'] as String? ?? '',
      device: json['device'] as String? ?? '',
      ipAddress: json['ipAddress'] as String?,
      startedAt: Session.parseDate(json['startedAt']),
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }
}

/// Second-factor state for the signed-in account.
class MfaStatus {
  const MfaStatus({
    required this.enabled,
    required this.pendingSetup,
    required this.recoveryCodesRemaining,
    required this.requiredForThisUser,
    this.enabledAt,
  });

  final bool enabled;
  final bool pendingSetup;
  final DateTime? enabledAt;
  final int recoveryCodesRemaining;

  /// Advisory: the platform will not block a sign-in on this, it only signals
  /// that enrolment is expected for this role.
  final bool requiredForThisUser;

  factory MfaStatus.fromJson(Map<String, dynamic> json) {
    return MfaStatus(
      enabled: json['enabled'] as bool? ?? false,
      pendingSetup: json['pendingSetup'] as bool? ?? false,
      enabledAt: json['enabledAt'] == null
          ? null
          : Session.parseDate(json['enabledAt']),
      recoveryCodesRemaining: json['recoveryCodesRemaining'] as int? ?? 0,
      requiredForThisUser: json['requiredForThisUser'] as bool? ?? false,
    );
  }
}

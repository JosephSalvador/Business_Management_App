import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/session.dart';

/// The account created by registration. Since M2 the backend no longer issues
/// a session at register time — the email must be verified first.
class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.fullName,
    required this.emailVerified,
  });

  final String id;
  final String tenantId;
  final String email;
  final String fullName;
  final bool emailVerified;

  factory RegisteredUser.fromJson(Map<String, dynamic> json) {
    return RegisteredUser(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }
}

/// Authentication against the real backend (`/api/v1/auth/*`).
///
/// The backend is the security authority: it hashes credentials, issues and
/// rotates tokens, enforces lockout, and owns every secret. This repository
/// only transports credentials over TLS at login/registration time and keeps
/// the issued tokens in secure storage.
class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
    void Function()? onSessionEstablished,
  })  : _apiClient = apiClient,
        _tokenStore = tokenStore,
        _onSessionEstablished = onSessionEstablished;

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  /// Fired after every confirmed authenticated exchange (login, refresh,
  /// restore) so the offline window (M5.9) stays anchored to real sessions.
  final void Function()? _onSessionEstablished;

  /// Shared HTTP client for the rest of the app (products, sales, …).
  ApiClient get apiClient => _apiClient;

  /// Registers a new business owner. `organizationName` doubles as the
  /// business name — registration provisions tenant + HQ branch + owner role.
  /// Returns the account only; a verification code is emailed separately and
  /// no session exists until [verifyEmail] + [login] succeed.
  Future<RegisteredUser> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? organizationName,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/auth/register',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        if (organizationName != null && organizationName.trim().isNotEmpty)
          'organizationName': organizationName.trim(),
      },
      extra: _authExchangeExtra,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return RegisteredUser.fromJson(
      Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
    );
  }

  /// Issues a fresh staff invitation code for the owner's business. Renders as
  /// `{ code, expiresAtUtc }`; the code is shown once so the owner can share it.
  Future<({String code, DateTime expiresAtUtc})> issueInvitation() async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/users/invitations',
      body: const {},
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final data = response.data as Map<dynamic, dynamic>;
    final code = data['code'];
    if (code is! String || code.isEmpty) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final expiresAtUtc = DateTime.tryParse(data['expiresAtUtc'] as String? ?? '');
    return (
      code: code,
      expiresAtUtc: expiresAtUtc ?? DateTime.now().toUtc(),
    );
  }

  /// Registers a staff member by redeeming an owner-issued invitation code.
  /// Unlike [register], this does NOT create a new business — the user is
  /// attached to the code's tenant with the Staff role. Returns the account
  /// only; the email must be verified before any login.
  Future<RegisteredUser> registerStaff({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String invitationCode,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/auth/register-staff',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'invitationCode': invitationCode.trim().toUpperCase(),
      },
      extra: _authExchangeExtra,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return RegisteredUser.fromJson(
      Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
    );
  }

  /// Confirms the email address with the 6-digit code from the inbox.
  /// Succeeds silently (HTTP 204); a login is required afterwards.
  Future<void> verifyEmail({required String email, required String code}) async {
    await _apiClient.post<dynamic>(
      '/api/v1/auth/verify-email',
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      },
      extra: _authExchangeExtra,
    );
  }

  /// Asks the backend to queue a fresh verification code. Rate-limited with a
  /// cooldown; [RateLimitException] means the user must wait.
  Future<void> resendVerificationCode({required String email}) async {
    await _apiClient.post<dynamic>(
      '/api/v1/auth/resend-verification',
      body: {'email': email.trim().toLowerCase()},
      extra: _authExchangeExtra,
    );
  }

  /// Requests a password reset email. Always succeeds (204) whether or not the
  /// account exists, so callers cannot probe registered addresses.
  Future<void> requestPasswordReset({required String email}) async {
    await _apiClient.post<dynamic>(
      '/api/v1/auth/forgot-password',
      body: {'email': email.trim().toLowerCase()},
      extra: _authExchangeExtra,
    );
  }

  /// Consumes a reset code and sets a new password. Succeeds silently (204).
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/v1/auth/reset-password',
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
      },
      extra: _authExchangeExtra,
    );
  }

  Future<Session> login({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final response = await _apiClient.post<dynamic>(
      '/api/v1/auth/login',
      body: {
        'identifier': trimmed.contains('@')
            ? trimmed.toLowerCase()
            : trimmed,
        'password': password,
      },
      extra: _authExchangeExtra,
    );
    final session = _persistSession(response);
    _onSessionEstablished?.call();
    return session;
  }

  /// Builds a session from the stored refresh token without credentials.
  /// Returns null when the device has no stored session.
  Future<Session?> restore() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final pair = await refresh(refreshToken);
    final meResponse = await _apiClient.get<dynamic>('/api/v1/users/me');
    if (meResponse.statusCode != 200 || meResponse.data is! Map) {
      throw UnauthorizedException();
    }
    final user = AuthUser.fromJson(
      Map<String, dynamic>.from(meResponse.data as Map<dynamic, dynamic>),
    );
    return Session(user: user, accessTokenExpiresAt: pair.expiresAt);
  }

  /// Refresh-token exchange; also used by [ApiClient] on 401 responses
  /// (wired through [TokenRefresher]).
  Future<TokenPair> refresh(String refreshToken) async {
    final Response<dynamic> response;
    try {
      response = await _apiClient.post<dynamic>(
        '/api/v1/auth/refresh',
        body: {'refreshToken': refreshToken},
        extra: _authExchangeExtra,
      );
    } on AppException {
      // Any failure during refresh means the session is gone.
      throw UnauthorizedException();
    }

    if (response.statusCode != 200 || response.data is! Map) {
      throw UnauthorizedException();
    }
    final data = response.data as Map<dynamic, dynamic>;
    final accessToken = data['accessToken'];
    final nextRefreshToken = data['refreshToken'];
    final expiresAtRaw = data['accessTokenExpiresAt'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        nextRefreshToken is! String ||
        nextRefreshToken.isEmpty) {
      throw UnauthorizedException();
    }

    await _tokenStore.writeTokens(
      accessToken: accessToken,
      refreshToken: nextRefreshToken,
    );

    _onSessionEstablished?.call();
    return TokenPair(
      accessToken: accessToken,
      refreshToken: nextRefreshToken,
      expiresAt: Session.parseDate(expiresAtRaw),
    );
  }

  /// Persists a fresh token pair from register/login and exposes only the
  /// safe, user-visible session to callers.
  Session _persistSession(Response<dynamic> response) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final data = response.data as Map<dynamic, dynamic>;
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }

    // Fire-and-forget persistence; the UI proceeds with the parsed session.
    unawaited(_tokenStore.writeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    ));

    return Session.fromAuthResponse(
      Map<String, dynamic>.from(data),
    );
  }

  /// Revokes the refresh token server-side (best effort) and clears local
  /// tokens unconditionally — logout must always succeed locally.
  Future<void> logout() async {
    try {
      await _apiClient.post<dynamic>(
        '/api/v1/auth/revoke',
        body: {},
        extra: _authExchangeExtra,
      );
    } on AppException {
      // Best effort: network loss must not trap the user in a session.
    }
    await _tokenStore.clear();
  }

  static const _authExchangeExtra = {'skip_auth': true, 'skip_retry': true};
}

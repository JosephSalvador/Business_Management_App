import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/session.dart';
import 'offline_credential_store.dart';
import 'biometric_auth_gate.dart';

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
///
/// When the backend is unreachable, the repository falls back to offline
/// authentication using a PBKDF2-stored password hash and a time-limited
/// HMAC-signed offline token. Biometric verification gates credential access.
class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
    required OfflineCredentialStore offlineCredentialStore,
    void Function()? onSessionEstablished,
  })  : _apiClient = apiClient,
        _tokenStore = tokenStore,
        _offlineCredentialStore = offlineCredentialStore,
        _onSessionEstablished = onSessionEstablished;

  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  final OfflineCredentialStore _offlineCredentialStore;

  /// Fired after every confirmed authenticated exchange (login, refresh,
  /// restore) so the offline window (M5.9) stays anchored to real sessions.
  final void Function()? _onSessionEstablished;

  /// Shared HTTP client for the rest of the app (products, sales, …).
  ApiClient get apiClient => _apiClient;

  /// The offline credential store for offline authentication.
  OfflineCredentialStore get offlineCredentialStore => _offlineCredentialStore;

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
    final expiresAtUtc =
        DateTime.tryParse(data['expiresAtUtc'] as String? ?? '');
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
  Future<void> verifyEmail(
      {required String email, required String code}) async {
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
    // Password changed — invalidate offline hash so the user must re-login
    // online with the new password before offline auth works again.
    await _offlineCredentialStore.clearPasswordHash();
  }

  /// Signs in with a password. Returns either a [Session] or the pending
  /// [MfaChallenge] when the account has a second factor: a correct password is
  /// not yet a session in that case, and no token is issued.
  Future<LoginOutcome> login({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final response = await _apiClient.post<dynamic>(
      '/api/v1/auth/login',
      body: {
        'identifier': trimmed.contains('@') ? trimmed.toLowerCase() : trimmed,
        'password': password,
      },
      extra: _authExchangeExtra,
    );

    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final envelope = Map<String, dynamic>.from(response.data as Map);

    if (envelope['status'] == _mfaRequiredStatus) {
      final challengeToken = envelope['challengeToken'];
      if (challengeToken is! String || challengeToken.isEmpty) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      // The echoed email can be empty when the account has no email on file; the caller
      // falls back to the identifier the user typed.
      return MfaChallenge(
        challengeToken: challengeToken,
        email: envelope['email'] as String? ?? '',
      );
    }

    // Login is always a discriminated envelope: tokens live under `tokens`, never at
    // the top level, so the MFA and non-MFA branches cannot be confused.
    final tokens = envelope['tokens'];
    if (tokens is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }

    final session =
        await _persistSessionResponse(Map<String, dynamic>.from(tokens));

    // Store credentials for offline auth (fire-and-forget).
    unawaited(_storeOfflineCredentials(password: password, user: session.user));

    _onSessionEstablished?.call();
    return AuthenticatedLogin(session);
  }

  /// Completes a pending second-factor sign-in.
  ///
  /// Set [useRecoveryCode] for a printed recovery code. The backend records
  /// which path was taken, and a code typed into the wrong path fails rather
  /// than silently consuming the other credential.
  Future<Session> completeTwoFactorChallenge({
    required String challengeToken,
    required String code,
    required bool useRecoveryCode,
  }) =>
      _completeTwoFactor(
        challengeToken: challengeToken,
        code: code,
        useRecoveryCode: useRecoveryCode,
      );

  Future<Session> _completeTwoFactor({
    required String challengeToken,
    required String code,
    required bool useRecoveryCode,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/auth/two-factor/verify',
      body: {
        'challengeToken': challengeToken,
        'code': code.trim(),
        'useRecoveryCode': useRecoveryCode,
      },
      extra: _authExchangeExtra,
    );

    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }

    // Unlike login, this endpoint answers with the tokens directly: reaching it already
    // means a second factor was proven, so there is no longer a branch to report.
    final session = await _persistSessionResponse(
      Map<String, dynamic>.from(response.data as Map),
    );

    _onSessionEstablished?.call();
    return session;
  }

  static const _mfaRequiredStatus = 'two_factor_required';

  /// Authenticates offline using the locally stored password hash.
  ///
  /// Requires:
  /// 1. Password hash to be stored (previous successful online login)
  /// 2. Password to match the stored hash (PBKDF2 verification)
  /// 3. Biometric authentication (hardware-backed gate)
  /// 4. Offline token to be generated and valid
  ///
  /// Returns a [Session] on success, throws [ValidationException] on failure.
  Future<Session?> loginOffline({
    required String password,
    BiometricAuthGate? biometricGate,
  }) async {
    // Check if offline credentials are available
    if (!await _offlineCredentialStore.isOfflineAuthAvailable()) {
      return null;
    }

    // Verify password against stored hash (enforces lockout)
    final verified = await _offlineCredentialStore.verifyPassword(password);
    if (!verified) {
      throw ValidationException(
        'Nenosiri si sahihi. Jaribu tena.',
      );
    }

    // Require biometric verification for security
    if (biometricGate != null) {
      final biometricOk = await biometricGate.authenticate(
        reason: 'Thibitisha utambulisho ili kuuza nje ya mtandao',
      );
      if (!biometricOk) {
        throw ValidationException(
          'Uthibitisho wa utambulisho umeshindikana.',
        );
      }
    }

    // Generate time-limited offline token
    final cachedUserId = await _offlineCredentialStore.getCachedUserId();
    final cachedTenantId = await _offlineCredentialStore.getCachedTenantId();
    final cachedPermissions =
        await _offlineCredentialStore.getCachedPermissions();
    final cachedEmail = await _offlineCredentialStore.getCachedEmail() ?? '';
    final cachedFullName =
        await _offlineCredentialStore.getCachedFullName() ?? '';

    if (cachedUserId == null || cachedTenantId == null) {
      return null;
    }

    final user = AuthUser(
      id: cachedUserId,
      tenantId: cachedTenantId,
      email: cachedEmail,
      fullName: cachedFullName,
      phone: null,
      isActive: true,
      emailVerified: true,
      permissions: cachedPermissions,
    );

    final token = await _offlineCredentialStore.generateOfflineToken(user);
    if (token == null) return null;

    // Enable biometric-only quick unlock so the next open does NOT require
    // the password again within the quick-unlock window.
    await _offlineCredentialStore.enableQuickUnlock(user);

    _onSessionEstablished?.call();
    return Session(
      user: user,
      accessTokenExpiresAt: DateTime.now().toUtc().add(
            const Duration(hours: 72),
          ),
    );
  }

  /// Biometric-only quick unlock for a returning user on a trusted device.
  ///
  /// Requires:
  /// 1. A quick-unlock token was created by a previous password-verified
  ///    login (online or offline) on this device.
  /// 2. A fresh, hardware-backed biometric match (fingerprint/face).
  ///
  /// No password is ever touched. Returns a [Session] on success or null
  /// when quick unlock is unavailable/expired.
  Future<Session?> loginWithBiometric({
    required BiometricAuthGate biometricGate,
  }) async {
    if (!await _offlineCredentialStore.hasValidQuickUnlock()) {
      return null;
    }
    final biometricOk = await biometricGate.authenticate(
      reason: 'Thibitisha utambulisho ili kuingia kwa haraka',
    );
    if (!biometricOk) {
      throw ValidationException('Uthibitisho wa utambulisho umeshindikana.');
    }

    final session = await _offlineCredentialStore.restoreQuickUnlock();
    if (session == null) return null;

    // Sliding renewal: a fresh biometric match resets the trusted window so
    // an active device is never asked for a password again.
    await _offlineCredentialStore.enableQuickUnlock(session.user);

    _onSessionEstablished?.call();
    return session;
  }

  /// Unlocks a trusted device session using the local unlock PIN — the fast
  /// factor on devices without a biometric sensor.
  ///
  /// Requires a valid quick-unlock token (device trusted via a previous
  /// password-verified login). The PIN is verified against the PBKDF2 hash
  /// with the shared exponential lockout applied. The PIN never leaves the
  /// device and is never the account password.
  Future<Session?> unlockWithPin({required String pin}) async {
    if (!await _offlineCredentialStore.hasValidQuickUnlock()) {
      return null;
    }
    final verified = await _offlineCredentialStore.verifyUnlockPin(pin);
    if (!verified) {
      throw ValidationException('PIN si sahihi. Jaribu tena.');
    }
    final session = await _offlineCredentialStore.restoreQuickUnlock();
    if (session == null) return null;

    // Sliding renewal (mirrors the biometric path).
    await _offlineCredentialStore.enableQuickUnlock(session.user);

    _onSessionEstablished?.call();
    return session;
  }

  /// First trusted-device unlock for a device without a biometric sensor:
  /// sets the 4–6 digit unlock PIN, then releases the trusted session.
  ///
  /// Requires a valid quick-unlock token. Used on the first time a
  /// no-biometric device shows the unlock screen.
  Future<Session?> setupPinAndUnlock({required String pin}) async {
    if (!await _offlineCredentialStore.hasValidQuickUnlock()) {
      return null;
    }
    await _offlineCredentialStore.setUnlockPin(pin);
    final session = await _offlineCredentialStore.restoreQuickUnlock();
    if (session == null) return null;

    await _offlineCredentialStore.enableQuickUnlock(session.user);

    _onSessionEstablished?.call();
    return session;
  }

  /// Builds a session from the stored refresh token without credentials.
  /// Returns null when the device has no stored session.
  ///
  /// Falls back to offline session restore if the refresh token exchange
  /// fails (backend unreachable, token expired).
  Future<Session?> restore() async {
    final refreshToken = await _tokenStore.readRefreshToken();

    // Try online restore first
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final pair = await refresh(refreshToken);
        final meResponse = await _apiClient.get<dynamic>('/api/v1/users/me');
        if (meResponse.statusCode == 200 && meResponse.data is Map) {
          final user = AuthUser.fromJson(
            Map<String, dynamic>.from(meResponse.data as Map<dynamic, dynamic>),
          );
          return Session(user: user, accessTokenExpiresAt: pair.expiresAt);
        }
      } on AppException {
        // Online restore failed — fall through to offline
      }
    }

    // Fallback: try to restore from offline token
    final offlineSession =
        await _offlineCredentialStore.restoreOfflineSession();
    if (offlineSession != null) {
      return offlineSession;
    }

    return null;
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

  /// Writes the token pair and builds the session. Takes the decoded body rather
  /// than the whole [Response] because the two sign-in paths decode differently:
  /// login nests the tokens under `tokens`, while the MFA verify endpoint returns
  /// them directly.
  Future<Session> _persistSessionResponse(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }

    await _tokenStore.writeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return Session.fromAuthResponse(data);
  }

  /// Configures a Quick PIN and optionally enables biometrics for this device.
  Future<void> enableQuickPin({
    required String pin,
    bool enableBiometric = false,
  }) async {
    await _offlineCredentialStore.setUnlockPin(pin);
    await _offlineCredentialStore.setQuickPinEnabled(true);
    await _offlineCredentialStore.setBiometricEnabled(enableBiometric);

    final cachedUserId = await _offlineCredentialStore.getCachedUserId();
    final cachedTenantId = await _offlineCredentialStore.getCachedTenantId();
    if (cachedUserId != null && cachedTenantId != null) {
      final user = AuthUser(
        id: cachedUserId,
        tenantId: cachedTenantId,
        email: await _offlineCredentialStore.getCachedEmail() ?? '',
        fullName: await _offlineCredentialStore.getCachedFullName() ?? '',
        phone: null,
        isActive: true,
        emailVerified: true,
        permissions: await _offlineCredentialStore.getCachedPermissions(),
      );
      await _offlineCredentialStore.enableQuickUnlock(user);
    }
  }

  /// Disables Quick PIN and quick unlock on this device.
  Future<void> disableQuickPin() async {
    await _offlineCredentialStore.clearUnlockPin();
    await _offlineCredentialStore.setBiometricEnabled(false);
    await _offlineCredentialStore.disableQuickUnlock();
  }

  /// Updates biometric opt-in preference on this device.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _offlineCredentialStore.setBiometricEnabled(enabled);
  }

  /// Stores credentials for offline authentication. Does not force quick
  /// unlock unless the user has already configured Quick PIN or biometrics.
  Future<void> _storeOfflineCredentials({
    required String password,
    required AuthUser user,
  }) async {
    try {
      await _offlineCredentialStore.storeCredentials(
        password: password,
        user: user,
      );
      final isPinEnabled = await _offlineCredentialStore.isQuickPinEnabled();
      final isBiometric = await _offlineCredentialStore.isBiometricEnabled();
      if (isPinEnabled || isBiometric) {
        await _offlineCredentialStore.enableQuickUnlock(user);
      }
    } catch (_) {
      // Non-critical: offline auth simply won't work if this fails.
    }
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
    await _offlineCredentialStore.clearOfflineToken();
    await _offlineCredentialStore.disableQuickUnlock();
  }

  static const _authExchangeExtra = {'skip_auth': true, 'skip_retry': true};
}

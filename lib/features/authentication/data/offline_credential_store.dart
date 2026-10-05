import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/app_exception.dart';
import '../domain/session.dart';

/// Secure offline credential store using hardware-backed key storage.
///
/// After a successful online login, the password hash (PBKDF2-SHA256) is
/// stored alongside the user profile. When the backend is unreachable, the
/// user can authenticate offline by proving knowledge of the password.
///
/// Security measures:
/// - PBKDF2 with 100,000 iterations + random 32-byte salt
/// - Exponential lockout after failed attempts
/// - Time-limited offline tokens (72h max)
/// - All data in flutter_secure_storage (Android Keystore / iOS Keychain)
/// - Hardware-backed biometric gate required before credential release
class OfflineCredentialStore {
  OfflineCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                // Device-bound: secrets must never migrate to another device
                // via iCloud-backup restore (stolen-device mitigation).
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;
  final Random _random = Random.secure();

  // -- Secure storage keys --
  static const _passwordHashKey = 'jolinx.auth.offline_password_hash';
  static const _passwordSaltKey = 'jolinx.auth.offline_password_salt';
  static const _offlineTokenKey = 'jolinx.auth.offline_token';
  static const _offlineTokenExpiryKey = 'jolinx.auth.offline_token_expiry';
  static const _quickUnlockKey = 'jolinx.auth.quick_unlock_token';
  static const _quickUnlockExpiryKey = 'jolinx.auth.quick_unlock_expiry';
  static const _unlockPinKey = 'jolinx.auth.unlock_pin';
  static const _unlockPinSaltKey = 'jolinx.auth.unlock_pin_salt';
  static const _userIdKey = 'jolinx.auth.offline_user_id';
  static const _tenantIdKey = 'jolinx.auth.offline_tenant_id';
  static const _permissionsKey = 'jolinx.auth.offline_permissions';
  static const _userFullNameKey = 'jolinx.auth.offline_user_full_name';
  static const _userEmailKey = 'jolinx.auth.offline_user_email';
  static const _failedAttemptsKey = 'jolinx.auth.offline_failed_attempts';
  static const _lockoutUntilKey = 'jolinx.auth.offline_lockout_until';

  // -- Lockout configuration --
  static const _maxAttemptsBeforeLockout = 5;
  static const _initialLockoutDuration = Duration(minutes: 15);
  static const _maxLockoutDuration = Duration(hours: 1);
  static const _offlineTokenTtl = Duration(hours: 72);
  static const _quickUnlockTtl = Duration(days: 7);

  // ------------------------------------------------------------------
  // Storing credentials (called after successful online login)
  // ------------------------------------------------------------------

  /// Stores a PBKDF2 hash of [password] along with cached user data for
  /// offline authentication. Called once after every successful online login
  /// to keep the offline credentials fresh.
  Future<void> storeCredentials({
    required String password,
    required AuthUser user,
  }) async {
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);

    await Future.wait([
      _storage.write(key: _passwordHashKey, value: hash),
      _storage.write(key: _passwordSaltKey, value: base64Url.encode(salt)),
      _storage.write(key: _userIdKey, value: user.id),
      _storage.write(key: _tenantIdKey, value: user.tenantId),
      _storage.write(key: _userFullNameKey, value: user.fullName),
      _storage.write(key: _userEmailKey, value: user.email),
      _storage.write(
        key: _permissionsKey,
        value: jsonEncode(user.permissions),
      ),
      // Reset failed attempts on fresh credential store
      _storage.write(key: _failedAttemptsKey, value: '0'),
      _storage.delete(key: _lockoutUntilKey),
    ]);
  }

  // ------------------------------------------------------------------
  // Offline verification
  // ------------------------------------------------------------------

  /// Verifies [password] against the stored hash without contacting the
  /// backend. Returns true on match, false otherwise.
  ///
  /// Enforces exponential lockout after [_maxAttemptsBeforeLockout] failures.
  Future<bool> verifyPassword(String password) async {
    if (await _isLockedOut()) {
      return false;
    }

    final storedHash = await _storage.read(key: _passwordHashKey);
    final saltBase64 = await _storage.read(key: _passwordSaltKey);
    if (storedHash == null || saltBase64 == null) {
      return false;
    }

    final salt = base64Url.decode(saltBase64);
    final computedHash = _hashPassword(password, salt);

    if (_constantTimeEquals(computedHash, storedHash)) {
      await _resetFailedAttempts();
      return true;
    } else {
      await _recordFailedAttempt();
      return false;
    }
  }

  /// Generates a time-limited offline token after successful password
  /// verification. The token is a signed HMAC of the user identity +
  /// expiry timestamp, stored in secure storage.
  Future<String?> generateOfflineToken(AuthUser user) async {
    final expiry = DateTime.now().toUtc().add(_offlineTokenTtl);
    final payload = jsonEncode({
      'userId': user.id,
      'tenantId': user.tenantId,
      'email': user.email,
      'fullName': user.fullName,
      'permissions': user.permissions,
      'expiry': expiry.toIso8601String(),
    });

    // The token is base64-encoded payload + HMAC signature
    final secret = await _getOrCreateTokenSecret();
    final signature = _hmacSign(payload, secret);
    final token = '${base64Url.encode(utf8.encode(payload))}.$signature';

    await Future.wait([
      _storage.write(key: _offlineTokenKey, value: token),
      _storage.write(
        key: _offlineTokenExpiryKey,
        value: expiry.toIso8601String(),
      ),
    ]);

    return token;
  }

  /// Restores a session from the stored offline token if it is still valid.
  /// Returns null if no token exists or it has expired.
  Future<Session?> restoreOfflineSession() async {
    final token = await _storage.read(key: _offlineTokenKey);
    final expiryStr = await _storage.read(key: _offlineTokenExpiryKey);
    if (token == null || expiryStr == null) return null;

    final expiry = DateTime.tryParse(expiryStr)?.toUtc();
    if (expiry == null || DateTime.now().toUtc().isAfter(expiry)) {
      await clearOfflineToken();
      return null;
    }

    // Verify HMAC signature
    final parts = token.split('.');
    if (parts.length != 2) {
      await clearOfflineToken();
      return null;
    }

    final secret = await _getOrCreateTokenSecret();
    final payload = utf8.decode(base64Url.decode(parts[0]));
    final expectedSig = _hmacSign(payload, secret);
    if (!_constantTimeEquals(parts[1], expectedSig)) {
      await clearOfflineToken();
      return null;
    }

    // Parse the payload
    final payloadMap = jsonDecode(payload) as Map<String, dynamic>;
    final user = AuthUser(
      id: payloadMap['userId'] as String,
      tenantId: payloadMap['tenantId'] as String,
      email: payloadMap['email'] as String,
      fullName: payloadMap['fullName'] as String? ?? '',
      phone: null,
      isActive: true,
      emailVerified: true,
      permissions: (payloadMap['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );

    return Session(
      user: user,
      accessTokenExpiresAt: expiry,
    );
  }

  /// Enables fast unlock on this device. Called once after a successful
  /// password-verified login (online or offline) and re-armed after every
  /// successful biometric/PIN unlock. Stores an HMAC token that is ONLY
  /// released after a fresh fast factor — the user never types their password
  /// again on this trusted device until the sliding [_quickUnlockTtl] window
  /// (7 days, renewed on each unlock) ends.
  Future<void> enableQuickUnlock(AuthUser user) async {
    final expiry = DateTime.now().toUtc().add(_quickUnlockTtl);
    final payload = jsonEncode({
      'userId': user.id,
      'tenantId': user.tenantId,
      'permissions': user.permissions,
      'fullName': user.fullName,
      'email': user.email,
      'expiry': expiry.toIso8601String(),
    });
    final secret = await _getOrCreateTokenSecret();
    final signature = _hmacSign(payload, secret);
    final token = '${base64Url.encode(utf8.encode(payload))}.$signature';

    await Future.wait([
      _storage.write(key: _quickUnlockKey, value: token),
      _storage.write(
        key: _quickUnlockExpiryKey,
        value: expiry.toIso8601String(),
      ),
    ]);
  }

  /// Whether a valid quick-unlock token exists (biometric threshold: the
  /// caller must still present a fresh biometric before using it).
  Future<bool> hasValidQuickUnlock() async {
    final token = await _storage.read(key: _quickUnlockKey);
    final expiryStr = await _storage.read(key: _quickUnlockExpiryKey);
    if (token == null || expiryStr == null) return false;
    final expiry = DateTime.tryParse(expiryStr)?.toUtc();
    if (expiry == null || DateTime.now().toUtc().isAfter(expiry)) {
      await disableQuickUnlock();
      return false;
    }
    // Validate the HMAC so corrupted/stale tokens are not trusted.
    final parts = token.split('.');
    if (parts.length != 2) {
      await disableQuickUnlock();
      return false;
    }
    final secret = await _getOrCreateTokenSecret();
    final payload = utf8.decode(base64Url.decode(parts[0]));
    final expectedSig = _hmacSign(payload, secret);
    if (!_constantTimeEquals(parts[1], expectedSig)) {
      await disableQuickUnlock();
      return false;
    }
    return true;
  }

  /// Restores a session using the quick-unlock token. Call ONLY after a
  /// fresh, successful biometric match. Returns null when the token is
  /// missing, expired, or tampered with.
  Future<Session?> restoreQuickUnlock() async {
    if (!await hasValidQuickUnlock()) return null;
    final token = await _storage.read(key: _quickUnlockKey);
    final parts = token!.split('.');
    final payload = utf8.decode(base64Url.decode(parts[0]));
    final payloadMap = jsonDecode(payload) as Map<String, dynamic>;
    final user = AuthUser(
      id: payloadMap['userId'] as String,
      tenantId: payloadMap['tenantId'] as String,
      email: payloadMap['email'] as String,
      fullName: payloadMap['fullName'] as String? ?? '',
      phone: null,
      isActive: true,
      emailVerified: true,
      permissions: (payloadMap['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
    final expiry = DateTime.tryParse(payloadMap['expiry'] as String) ??
        DateTime.now().toUtc().add(_quickUnlockTtl);
    return Session(user: user, accessTokenExpiresAt: expiry);
  }

  /// Disables biometric quick unlock (on logout, expiry, or password change).
  Future<void> disableQuickUnlock() async {
    await Future.wait([
      _storage.delete(key: _quickUnlockKey),
      _storage.delete(key: _quickUnlockExpiryKey),
    ]);
  }

  /// Whether a local unlock PIN has been set on this device.
  Future<bool> hasUnlockPin() async {
    final pinHash = await _storage.read(key: _unlockPinKey);
    final saltBase64 = await _storage.read(key: _unlockPinSaltKey);
    return (pinHash != null && pinHash.isNotEmpty) &&
        (saltBase64 != null && saltBase64.isNotEmpty);
  }

  /// Stores a device-local unlock PIN (PBKDF2 hash) for fast, offline-capable
  /// unlock on devices without a biometric sensor. The PIN is never the
  /// account password and never leaves the device.
  ///
  /// Accepts exactly 4–6 digits. Throws [ValidationException] otherwise.
  Future<void> setUnlockPin(String pin) async {
    final trimmed = pin.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(trimmed)) {
      throw ValidationException(
        'PIN lazima iwe na tarakimu 4 hadi 6.',
      );
    }
    final salt = _generateSalt();
    final hash = _hashPassword(trimmed, salt);
    await Future.wait([
      _storage.write(key: _unlockPinKey, value: hash),
      _storage.write(key: _unlockPinSaltKey, value: base64Url.encode(salt)),
      // A freshly chosen PIN resets the shared lockout counter.
      _storage.write(key: _failedAttemptsKey, value: '0'),
      _storage.delete(key: _lockoutUntilKey),
    ]);
  }

  /// Verifies [pin] against the stored unlock PIN. Enforces the same
  /// exponential lockout as the offline password check.
  Future<bool> verifyUnlockPin(String pin) async {
    if (await _isLockedOut()) {
      return false;
    }
    final pinHash = await _storage.read(key: _unlockPinKey);
    final saltBase64 = await _storage.read(key: _unlockPinSaltKey);
    if (pinHash == null || saltBase64 == null) {
      return false;
    }
    final salt = base64Url.decode(saltBase64);
    final computedHash = _hashPassword(pin.trim(), salt);
    if (_constantTimeEquals(computedHash, pinHash)) {
      await _resetFailedAttempts();
      return true;
    } else {
      await _recordFailedAttempt();
      return false;
    }
  }

  /// Removes the local unlock PIN (device config cleanup).
  Future<void> clearUnlockPin() async {
    await Future.wait([
      _storage.delete(key: _unlockPinKey),
      _storage.delete(key: _unlockPinSaltKey),
    ]);
  }

  /// Checks whether offline authentication is available (credentials stored,
  /// not locked out).
  Future<bool> isOfflineAuthAvailable() async {
    final hasHash = await _storage.read(key: _passwordHashKey);
    if (hasHash == null || hasHash.isEmpty) return false;
    if (await _isLockedOut()) return false;
    return true;
  }

  /// Returns the cached user permissions for offline permission checks.
  Future<List<String>> getCachedPermissions() async {
    final raw = await _storage.read(key: _permissionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns the cached user ID for offline operations.
  Future<String?> getCachedUserId() => _storage.read(key: _userIdKey);

  /// Returns the cached tenant ID for offline operations.
  Future<String?> getCachedTenantId() => _storage.read(key: _tenantIdKey);

  /// Returns the cached user email for offline display.
  Future<String?> getCachedEmail() => _storage.read(key: _userEmailKey);

  /// Returns the cached user full name for offline display.
  Future<String?> getCachedFullName() => _storage.read(key: _userFullNameKey);

  // ------------------------------------------------------------------
  // Token management
  // ------------------------------------------------------------------

  /// Clears the offline token (but NOT the password hash — the user can
  /// still log in again offline).
  Future<void> clearOfflineToken() async {
    await Future.wait([
      _storage.delete(key: _offlineTokenKey),
      _storage.delete(key: _offlineTokenExpiryKey),
    ]);
  }

  /// Clears ALL offline data — called on logout.
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _passwordHashKey),
      _storage.delete(key: _passwordSaltKey),
      _storage.delete(key: _offlineTokenKey),
      _storage.delete(key: _offlineTokenExpiryKey),
      _storage.delete(key: _quickUnlockKey),
      _storage.delete(key: _quickUnlockExpiryKey),
      _storage.delete(key: _unlockPinKey),
      _storage.delete(key: _unlockPinSaltKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _tenantIdKey),
      _storage.delete(key: _permissionsKey),
      _storage.delete(key: _userFullNameKey),
      _storage.delete(key: _userEmailKey),
      _storage.delete(key: _failedAttemptsKey),
      _storage.delete(key: _lockoutUntilKey),
    ]);
  }

  /// Clears only the password hash (e.g. when password is changed online).
  /// The offline token and quick unlock are also invalidated.
  Future<void> clearPasswordHash() async {
    await Future.wait([
      _storage.delete(key: _passwordHashKey),
      _storage.delete(key: _passwordSaltKey),
      _storage.delete(key: _offlineTokenKey),
      _storage.delete(key: _offlineTokenExpiryKey),
      _storage.delete(key: _quickUnlockKey),
      _storage.delete(key: _quickUnlockExpiryKey),
    ]);
  }

  // ------------------------------------------------------------------
  // Lockout management
  // ------------------------------------------------------------------

  Future<bool> _isLockedOut() async {
    final lockoutUntilStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutUntilStr == null) return false;
    final lockoutUntil = DateTime.tryParse(lockoutUntilStr)?.toUtc();
    if (lockoutUntil == null) return false;
    if (DateTime.now().toUtc().isBefore(lockoutUntil)) return true;
    // Lockout expired — clear it
    await _storage.delete(key: _lockoutUntilKey);
    return false;
  }

  Future<void> _recordFailedAttempt() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    final attempts = int.tryParse(raw ?? '0') ?? 0;
    final newAttempts = attempts + 1;
    await _storage.write(key: _failedAttemptsKey, value: '$newAttempts');

    if (newAttempts >= _maxAttemptsBeforeLockout) {
      // Exponential backoff: 15min, 30min, 1hr (capped)
      final lockoutMinutes = min(
        _initialLockoutDuration.inMinutes *
            (1 << (newAttempts - _maxAttemptsBeforeLockout)),
        _maxLockoutDuration.inMinutes,
      );
      final lockoutUntil =
          DateTime.now().toUtc().add(Duration(minutes: lockoutMinutes));
      await _storage.write(
        key: _lockoutUntilKey,
        value: lockoutUntil.toIso8601String(),
      );
    }
  }

  Future<void> _resetFailedAttempts() async {
    await Future.wait([
      _storage.write(key: _failedAttemptsKey, value: '0'),
      _storage.delete(key: _lockoutUntilKey),
    ]);
  }

  // ------------------------------------------------------------------
  // Cryptographic helpers
  // ------------------------------------------------------------------

  List<int> _generateSalt() {
    return List<int>.generate(32, (_) => _random.nextInt(256));
  }

  /// PBKDF2-SHA256 with 100,000 iterations.
  String _hashPassword(String password, List<int> salt) {
    final bytes = utf8.encode(password);
    final key = _pbkdf2(bytes, salt, 100000, 32);
    return base64Url.encode(key);
  }

  /// PBKDF2 implementation using HMAC-SHA256.
  List<int> _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final result = List<int>.filled(keyLength, 0);
    final blockSize = sha256.blockSize;
    final numBlocks = (keyLength + blockSize - 1) ~/ blockSize;

    for (var blockIndex = 0; blockIndex < numBlocks; blockIndex++) {
      final blockNumber = blockIndex + 1;
      var u = _hmacWithSalt(hmac, salt, blockNumber);
      var xorResult = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = _hmacBytes(hmac, u);
        for (var j = 0; j < u.length; j++) {
          xorResult[j] ^= u[j];
        }
      }

      final offset = blockIndex * blockSize;
      final length = keyLength - offset;
      for (var i = 0; i < (length < blockSize ? length : blockSize); i++) {
        if (offset + i < keyLength) {
          result[offset + i] = xorResult[i];
        }
      }
    }

    return result;
  }

  List<int> _hmacWithSalt(Hmac hmac, List<int> salt, int blockNumber) {
    final blockBytes = [
      (blockNumber >> 24) & 0xff,
      (blockNumber >> 16) & 0xff,
      (blockNumber >> 8) & 0xff,
      blockNumber & 0xff,
    ];
    return _hmacBytes(hmac, [...salt, ...blockBytes]);
  }

  List<int> _hmacBytes(Hmac hmac, List<int> data) {
    return hmac.convert(data).bytes;
  }

  /// HMAC-SHA256 for offline token signing.
  String _hmacSign(String payload, String secret) {
    final keyBytes = utf8.encode(secret);
    final payloadBytes = utf8.encode(payload);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(payloadBytes);
    return base64Url.encode(digest.bytes);
  }

  /// Constant-time string comparison to prevent timing attacks.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Gets or creates the HMAC secret used for offline token signing.
  /// Stored in secure storage, generated once per installation.
  Future<String> _getOrCreateTokenSecret() async {
    const key = 'jolinx.auth.offline_token_secret';
    final existing = await _storage.read(key: key);
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final secret = base64Url.encode(bytes);
    await _storage.write(key: key, value: secret);
    return secret;
  }
}

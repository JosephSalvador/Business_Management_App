import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import 'auth_repository.dart';
import '../domain/session.dart';

/// Own-account security management: second-factor enrolment and the device list.
///
/// Reads through [AuthRepository]'s client so the session's access token is
/// attached and a 401 triggers the normal refresh-and-retry path — these calls
/// run while signed in, unlike the login exchange.
class SecurityRepository {
  SecurityRepository(this._auth);

  final AuthRepository _auth;

  ApiClient get _apiClient => _auth.apiClient;

  Future<MfaStatus> fetchMfaStatus() async {
    final response =
        await _apiClient.get<dynamic>('/api/v1/me/security/two-factor');
    return MfaStatus.fromJson(_asMap(response));
  }

  /// Generates a secret and stages it. The secret is returned in plain text
  /// because the user has to type it into an authenticator by hand; nothing is
  /// active until [confirmTwoFactor] succeeds.
  Future<TwoFactorEnrollment> beginTwoFactorSetup() async {
    final response = await _apiClient
        .post<dynamic>('/api/v1/me/security/two-factor/setup', body: const {});
    final data = _asMap(response);

    final secret = data['secret'];
    final uri = data['provisioningUri'];
    if (secret is! String || secret.isEmpty || uri is! String || uri.isEmpty) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }

    return TwoFactorEnrollment(secret: secret, provisioningUri: uri);
  }

  /// Activates the staged factor once a valid code is supplied, and returns the
  /// first batch of recovery codes. The codes are shown exactly once — only
  /// their hashes are stored server-side.
  Future<RecoveryCodes> confirmTwoFactor(String code) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/me/security/two-factor/confirm',
      body: {'code': code.trim()},
    );

    return RecoveryCodes(_readCodes(_asMap(response)));
  }

  /// Removes the second factor. Requires the current code so a hijacked session
  /// cannot quietly downgrade the account's security.
  Future<void> disableTwoFactor(String code) async {
    await _apiClient.post<dynamic>(
      '/api/v1/me/security/two-factor/disable',
      body: {'code': code.trim()},
    );
  }

  /// Issues a fresh recovery-code batch and drops every previous one.
  Future<RecoveryCodes> regenerateRecoveryCodes() async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/me/security/two-factor/recovery-codes',
      body: const {},
    );

    return RecoveryCodes(_readCodes(_asMap(response)));
  }

  Future<List<AuthSessionDevice>> listSessions() async {
    final response =
        await _apiClient.get<dynamic>('/api/v1/me/security/sessions');
    final data = response.data;

    if (data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }

    return data
        .whereType<Map>()
        .map((item) =>
            AuthSessionDevice.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  /// Signs one device out. The current device is included: "sign out here too"
  /// is the safer reading of the request, and the client clears its own tokens
  /// when it notices the session is gone.
  Future<void> revokeSession(String familyId) async {
    await _apiClient.delete<dynamic>('/api/v1/me/security/sessions/$familyId');
  }

  Future<void> revokeAllSessions() async {
    await _apiClient.delete<dynamic>('/api/v1/me/security/sessions');
  }

  Map<String, dynamic> _asMap(Response<dynamic> response) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Reads the raw codes from either the confirm response (nested under
  /// `recoveryCodes`) or the regenerate response (a bare `codes` array).
  List<String> _readCodes(Map<String, dynamic> data) {
    final nested = data['recoveryCodes'];
    final source = nested is Map ? nested['codes'] : data['codes'];

    if (source is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }

    final codes =
        source.whereType<String>().where((c) => c.isNotEmpty).toList();
    if (codes.isEmpty) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return codes;
  }
}

/// A staged enrolment: the base32 secret to type in, and the QR target.
class TwoFactorEnrollment {
  const TwoFactorEnrollment({
    required this.secret,
    required this.provisioningUri,
  });

  final String secret;
  final String provisioningUri;
}

/// Raw recovery codes, returned exactly once. The app must make the user confirm
/// they have saved them before discarding this object.
class RecoveryCodes {
  const RecoveryCodes(this.codes);

  final List<String> codes;
}

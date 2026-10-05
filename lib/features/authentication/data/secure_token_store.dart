import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';

/// [TokenStore] backed by the platform keystore / Keychain via
/// flutter_secure_storage. Tokens never touch SharedPreferences or logs.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  static const _accessTokenKey = 'jolinx.auth.access_token';
  static const _refreshTokenKey = 'jolinx.auth.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() =>
      _storage.read(key: _accessTokenKey).then(_sanitize);

  @override
  Future<String?> readRefreshToken() =>
      _storage.read(key: _refreshTokenKey).then(_sanitize);

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  String? _sanitize(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}

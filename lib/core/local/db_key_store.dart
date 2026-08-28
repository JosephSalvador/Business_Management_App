import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owns the SQLCipher encryption key for the local database.
///
/// The key is generated once (32 random bytes, base64url) and stored only in
/// flutter_secure_storage (Android Keystore / iOS Keychain). It never appears
/// in source, .env, SharedPreferences or plain files. Losing the keystore
/// entry means losing local history — acceptable: the server remains
/// authoritative for all confirmed data.
class DbKeyStore {
  DbKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
            );

  static const _keyName = 'jolinx.db.encryption_key';

  final FlutterSecureStorage _storage;
  final Random _random = Random.secure();

  /// Returns the existing key or creates and persists a new one.
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final key = base64Url.encode(bytes);
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  /// Test/inspection hook: whether a key exists without creating one.
  Future<bool> hasKey() async {
    final value = await _storage.read(key: _keyName);
    return value != null && value.isNotEmpty;
  }
}

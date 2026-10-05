import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persistent installation identity (M5.2).
///
/// A random UUIDv4 generated once per installation and kept in secure
/// storage. It identifies the DEVICE, never the user: it survives restarts
/// and logins, and is deliberately not derived from email/phone/tenant.
/// Offline operations stamp it as `device_id` for audit and future
/// multi-terminal reporting.
class DeviceIdentity {
  DeviceIdentity({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  static const _idName = 'jolinx.device.installation_id';

  final FlutterSecureStorage _storage;
  String? _cached;

  Future<String> get() async {
    final existing = _cached ?? await _storage.read(key: _idName);
    if (existing != null && existing.isNotEmpty) {
      return _cached = existing;
    }
    final id = const Uuid().v4();
    await _storage.write(key: _idName, value: id);
    return _cached = id;
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jolinx_app/core/storage/db_key_store.dart';
import 'package:jolinx_app/core/platform/device_info.dart';

class InMemorySecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      values.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      values[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(values);

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InMemorySecureStoragePlatform platform;

  setUp(() {
    platform = InMemorySecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = platform;
  });

  group('DbKeyStore', () {
    test('generates a key once and reuses it', () async {
      final store = DbKeyStore(
        storage: const FlutterSecureStorage(),
      );
      final first = await store.getOrCreate();
      expect(first, isNotEmpty);
      expect(await store.hasKey(), isTrue);

      expect(await store.getOrCreate(), first,
          reason: 'the same key must be reused forever');
      // Key material lives only in secure storage.
      expect(platform.values.length, 1);
    });

    test('two stores share the same underlying key', () async {
      final a = DbKeyStore(storage: const FlutterSecureStorage());
      final b = DbKeyStore(storage: const FlutterSecureStorage());
      expect(await b.getOrCreate(), await a.getOrCreate());
    });
  });

  group('DeviceIdentity', () {
    test('survives restarts and new instances', () async {
      final first = DeviceIdentity(storage: const FlutterSecureStorage());
      final id = await first.get();
      expect(id, isNotEmpty);
      // UUIDv4 shape.
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
      );

      final second = DeviceIdentity(storage: const FlutterSecureStorage());
      expect(await second.get(), id);
    });

    test('does not derive identity from user or tenant data', () async {
      final store = DeviceIdentity(storage: const FlutterSecureStorage());
      final id = await store.get();
      expect(id.contains('tenant'), isFalse);
      expect(id.contains('@'), isFalse);
    });
  });
}

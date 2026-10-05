import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jolinx_app/core/storage/locale_store.dart';
import 'package:jolinx_app/l10n/generated/app_localizations.dart';

/// Minimal in-memory platform so writes never hit the method channel.
class _MemoryStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      values[key];

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
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(values);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStoragePlatform.instance = _MemoryStoragePlatform();
  });

  group('LocaleController', () {
    test('defaults to the device language when it is supported', () {
      expect(
        LocaleController.resolveDeviceLocale(const Locale('en')).languageCode,
        'en',
      );
      expect(
        LocaleController.resolveDeviceLocale(const Locale('sw')).languageCode,
        'sw',
      );
    });

    test('falls back to Swahili when the device language is not supported',
        () {
      expect(
        LocaleController.resolveDeviceLocale(const Locale('fr')).languageCode,
        'sw',
      );
    });

    test('restore applies a stored preference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(localeControllerProvider.notifier);
      controller.restore('en');
      expect(controller.state.languageCode, 'en');
    });

    test('restore ignores null and unknown codes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(localeControllerProvider.notifier);
      final initial = controller.state;
      controller.restore(null);
      expect(controller.state, initial);

      controller.restore('fr');
      expect(controller.state, initial,
          reason: 'only supported locales may be applied');
    });

    test('setLocale switches and persists the choice', () async {
      final store = LocaleStore();
      final container = ProviderContainer(overrides: [
        localeStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(localeControllerProvider.notifier);

      await controller.setLocale(const Locale('en'));
      expect(controller.state.languageCode, 'en');
      expect(await store.read(), 'en');
    });
  });

  group('AppLocalizations', () {
    test('Swahili and English both resolve every auth string', () {
      final sw = lookupAppLocalizations(const Locale('sw'));
      final en = lookupAppLocalizations(const Locale('en'));

      for (final getter in [
        (AppLocalizations l) => l.identifierLabel,
        (AppLocalizations l) => l.forgotPassword,
        (AppLocalizations l) => l.createAccount,
        (AppLocalizations l) => l.resetCodeLabel,
        (AppLocalizations l) => l.acceptTermsLink,
        (AppLocalizations l) => l.strengthStrong,
        (AppLocalizations l) => l.termsTitle,
      ]) {
        expect(getter(sw), isNotEmpty);
        expect(getter(en), isNotEmpty);
        expect(getter(sw), isNot(equals(getter(en))),
            reason: 'translations must actually differ');
      }
    });
  });
}

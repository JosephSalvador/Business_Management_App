import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's language choice. Secure storage is reused because it is
/// already wired and proven on-device; the locale code is not a secret, it
/// simply has no other store yet.
class LocaleStore {
  LocaleStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  static const _keyName = 'jolinx.locale';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _keyName);

  Future<void> write(String languageCode) =>
      _storage.write(key: _keyName, value: languageCode);
}

/// Holds the active locale. Defaults to the device language and falls back
/// to Swahili when the device language is not among supported locales.
class LocaleController extends Notifier<Locale> {
  static const supported = [Locale('sw'), Locale('en')];

  @override
  Locale build() => _deviceLocale;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref.read(localeStoreProvider).write(locale.languageCode);
  }

  /// Applies a stored preference at startup. Unknown values or null keep the
  /// device locale.
  void restore(String? languageCode) {
    if (languageCode == null) return;
    final match = supported.where(
      (locale) => locale.languageCode == languageCode,
    );
    if (match.isNotEmpty) {
      state = match.first;
    }
  }

  static Locale get _deviceLocale =>
      resolveDeviceLocale(PlatformDispatcher.instance.locale);

  /// Matches a device locale against supported locales. Falls back to
  /// Swahili if the device language is not supported.
  @visibleForTesting
  static Locale resolveDeviceLocale(Locale deviceLocale) {
    final match = supported.where(
      (locale) => locale.languageCode == deviceLocale.languageCode,
    );
    return match.isNotEmpty ? match.first : const Locale('sw');
  }
}

final localeStoreProvider = Provider<LocaleStore>((_) => LocaleStore());

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

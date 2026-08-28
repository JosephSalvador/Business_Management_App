import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's language choice (auth screens first). Secure storage is
/// reused because it is already wired and proven on-device; the locale code is
/// not a secret, it simply has no other store yet.
class LocaleStore {
  LocaleStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
            );

  static const _keyName = 'jolinx.locale';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _keyName);

  Future<void> write(String languageCode) =>
      _storage.write(key: _keyName, value: languageCode);
}

/// Holds the active locale. Defaults to Swahili — the product is
/// Swahili-first — and falls back to Swahili when nothing (or something
/// unknown) is stored.
class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._store, {Locale initial = const Locale('sw')})
      : super(initial);

  static const supported = [Locale('sw'), Locale('en')];

  final LocaleStore _store;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _store.write(locale.languageCode);
  }

  /// Applies a stored preference at startup. Unknown values keep the default.
  void restore(String? languageCode) {
    if (languageCode == null) {
      return;
    }
    final match = supported.where(
      (locale) => locale.languageCode == languageCode,
    );
    if (match.isNotEmpty) {
      state = match.first;
    }
  }
}

final localeStoreProvider = Provider<LocaleStore>((ref) => LocaleStore());

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>(
  (ref) => LocaleController(ref.watch(localeStoreProvider)),
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's theme mode preference (System / Light / Dark).
class ThemeStore {
  ThemeStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _keyName = 'jolinx.themeMode';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _keyName);

  Future<void> write(String value) =>
      _storage.write(key: _keyName, value: value);
}

/// Controls the app's theme mode. Defaults to [ThemeMode.system] so the app
/// follows the device setting. The user can override to Light or Dark.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(themeStoreProvider).write(mode.name);
  }

  /// Applies a stored preference at startup.
  void restore(String? stored) {
    if (stored == null) return;
    final match = ThemeMode.values.where((m) => m.name == stored);
    if (match.isNotEmpty) {
      state = match.first;
    }
  }
}

final themeStoreProvider = Provider<ThemeStore>((_) => ThemeStore());

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

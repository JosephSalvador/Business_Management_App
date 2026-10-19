import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/di/core_providers.dart';
import '../core/network/api_client.dart';
import '../core/storage/db_key_store.dart';
import '../core/storage/local_database.dart';
import '../core/storage/locale_store.dart';
import '../core/storage/printer_store.dart';
import '../core/storage/theme_store.dart';
import '../features/authentication/data/secure_token_store.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final config = AppConfig.load();

  // The encrypted local database is opened before the app starts: the
  // SQLCipher key comes from secure storage (M5.1) and any operation caught
  // mid-flight by a crash returns to the pending queue (M5.6).
  final db = await LocalDatabase.open(
    keyProvider: () => DbKeyStore().getOrCreate(),
  );

  // Language preference is read before the first frame so the auth screens
  // render in the chosen language immediately.
  final localeStore = LocaleStore();
  final savedLocale = await localeStore.read();

  // Theme mode preference (System / Light / Dark).
  final themeStore = ThemeStore();
  final savedThemeMode = await themeStore.read();

  // Printer paper width preference (58mm vs 80mm).
  final printerStore = PrinterStore();
  final savedPaperWidth = await printerStore.getPaperWidth();

  final tokenStore = SecureTokenStore();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        localDatabaseProvider.overrideWithValue(db),
        localeStoreProvider.overrideWithValue(localeStore),
        tokenStoreProvider.overrideWithValue(tokenStore),
        // Default client for unauthenticated probes (health check).
        // Auth layer overrides this with the authenticated client.
        apiClientProvider.overrideWithValue(
          ApiClient(
            config: config,
            tokenStore: tokenStore,
            refresher: (_) async => throw UnimplementedError(),
          ),
        ),
      ],
      child: BusinessOsApp(
        savedLanguageCode: savedLocale,
        savedThemeMode: savedThemeMode,
        savedPaperWidth: savedPaperWidth,
      ),
    ),
  );
}

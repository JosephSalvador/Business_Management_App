import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/config/app_config.dart';
import 'core/di/providers.dart';
import 'core/local/db_key_store.dart';
import 'core/local/local_database.dart';
import 'core/local/locale_store.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        localDatabaseProvider.overrideWithValue(db),
        localeStoreProvider.overrideWithValue(localeStore),
      ],
      child: BusinessOsApp(savedLanguageCode: savedLocale),
    ),
  );
}

class BusinessOsApp extends ConsumerStatefulWidget {
  const BusinessOsApp({required this.savedLanguageCode, super.key});

  final String? savedLanguageCode;

  @override
  ConsumerState<BusinessOsApp> createState() => _BusinessOsAppState();
}

class _BusinessOsAppState extends ConsumerState<BusinessOsApp> {
  @override
  void initState() {
    super.initState();
    ref.read(localeControllerProvider.notifier).restore(widget.savedLanguageCode);
    // Crash recovery + first sync attempt once providers are alive.
    Future.microtask(() async {
      await ref.read(localSalesServiceProvider).recoverFromRestart();
      ref.read(syncEngineProvider);
      ref.read(syncStatusProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'JOLINX Business OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}

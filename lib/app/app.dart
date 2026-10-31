import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../core/session/app_lock.dart';
import '../core/storage/locale_store.dart';
import '../core/storage/theme_store.dart';
import '../features/authentication/application/auth_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import '../features/invoices/application/sync_queue_processor.dart';
import '../l10n/generated/app_localizations.dart';

class BusinessOsApp extends ConsumerStatefulWidget {
  const BusinessOsApp({
    required this.savedLanguageCode,
    this.savedThemeMode,
    this.savedPaperWidth,
    super.key,
  });

  final String? savedLanguageCode;
  final String? savedThemeMode;
  final String? savedPaperWidth;

  @override
  ConsumerState<BusinessOsApp> createState() => _BusinessOsAppState();
}

class _BusinessOsAppState extends ConsumerState<BusinessOsApp>
    with WidgetsBindingObserver {
  DateTime? _lastInteraction;
  DateTime? _backgroundedAt;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastInteraction = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(localeControllerProvider.notifier)
          .restore(widget.savedLanguageCode);
      ref
          .read(themeModeControllerProvider.notifier)
          .restore(widget.savedThemeMode);
      ref
          .read(receiptPaperWidthProvider.notifier)
          .restore(widget.savedPaperWidth);
      ref.read(printerControllerProvider.notifier).restore();
      ref.read(localSalesServiceProvider).recoverFromRestart();
      ref.read(syncEngineProvider);
      ref.read(syncQueueProcessorProvider);
      ref.read(syncStatusProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  AppLockPolicy get _policy => ref.read(appLockPolicyProvider);

  bool get _isAuthenticated {
    final auth = ref.read(authControllerProvider);
    return auth is AuthAuthenticated || auth is AuthLocked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final pausedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (pausedAt != null &&
            _isAuthenticated &&
            _policy.lockAfterBackground(
                backgroundedAt: pausedAt, now: DateTime.now())) {
          ref.read(authControllerProvider.notifier).lock();
        }
        _startIdleTimer();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Resets the idle countdown on every user interaction.
  void _registerInteraction() {
    _lastInteraction = DateTime.now();
    _startIdleTimer();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    if (!_isAuthenticated || !_policy.enabled) return;
    _idleTimer = Timer(_policy.idleTimeout, () {
      if (!mounted) return;
      if (!_isAuthenticated) return;
      if (_policy.lockAfterIdle(
        lastInteraction: _lastInteraction ?? DateTime.now(),
        now: DateTime.now(),
      )) {
        ref.read(authControllerProvider.notifier).lock();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'JOLINX Business OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: LocaleController.supported,
      localeResolutionCallback: (locale, supportedLocales) {
        // Match by language code only (e.g., 'en_US' → 'en', 'sw_TZ' → 'sw').
        if (locale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == locale.languageCode) {
              return supported;
            }
          }
        }
        // Default to Swahili when device language is unsupported.
        return const Locale('sw');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _registerInteraction(),
        child: child,
      ),
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}

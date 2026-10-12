import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment names the app understands. Only [dev] relaxes transport checks.
enum AppEnvironment { dev, staging, production }

/// Immutable, load-once application configuration.
///
/// Security rules enforced here:
/// - Non-dev environments MUST use HTTPS base URLs (both primary and fallback).
/// - This file never carries secrets: tokens live in secure storage, and every
///   backend secret (JWT signing keys, DB passwords, payment keys) stays server-side.
class AppConfig {
  AppConfig._({
    required this.environment,
    required this.apiBaseUrl,
    this.apiFallbackUrl,
  }) {
    if (environment != AppEnvironment.dev && apiBaseUrl.scheme != 'https') {
      throw StateError(
        'API_BASE_URL must use HTTPS outside the dev environment.',
      );
    }
    if (apiFallbackUrl != null &&
        environment != AppEnvironment.dev &&
        apiFallbackUrl!.scheme != 'https') {
      throw StateError(
        'API_FALLBACK_URL must use HTTPS outside the dev environment.',
      );
    }
  }

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  /// Optional secondary/backup API base URL for automatic multi-cloud failover
  /// when the primary host is unreachable or returns 502/503/504.
  final Uri? apiFallbackUrl;

  /// IANA timezone name from the device (e.g. `EAT`).
  String get timezone => DateTime.now().timeZoneName;

  /// Compile-time overrides win over `.env` values
  /// (`flutter build apk --dart-define=API_BASE_URL=https://...`).
  static const _dartDefineApiUrl = String.fromEnvironment('API_BASE_URL');
  static const _dartDefineFallbackUrl =
      String.fromEnvironment('API_FALLBACK_URL');
  static const _dartDefineEnv = String.fromEnvironment('APP_ENV');

  static AppConfig? _instance;

  /// Loaded in `main()` before `runApp`. Throws when configuration is unsafe.
  static AppConfig load() {
    String read(String key) {
      final compileTime = switch (key) {
        'API_BASE_URL' => _dartDefineApiUrl,
        'API_FALLBACK_URL' => _dartDefineFallbackUrl,
        'APP_ENV' => _dartDefineEnv,
        _ => '',
      };
      if (compileTime.isNotEmpty) {
        return compileTime;
      }
      return dotenv.maybeGet(key) ?? '';
    }

    final envName = read('APP_ENV').trim().toLowerCase();
    final environment = switch (envName) {
      'dev' || 'development' => AppEnvironment.dev,
      'staging' => AppEnvironment.staging,
      'production' || 'prod' => AppEnvironment.production,
      _ => AppEnvironment.production,
    };

    final rawUrl = read('API_BASE_URL').trim();
    if (rawUrl.isEmpty) {
      throw StateError('API_BASE_URL is not configured.');
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL is not a valid URL: $rawUrl');
    }

    if (environment != AppEnvironment.dev && uri.scheme != 'https') {
      throw StateError(
        'API_BASE_URL must use HTTPS outside the dev environment.',
      );
    }

    Uri? fallbackUri;
    final rawFallback = read('API_FALLBACK_URL').trim();
    if (rawFallback.isNotEmpty) {
      final parsedFallback = Uri.tryParse(rawFallback);
      if (parsedFallback == null ||
          !parsedFallback.hasScheme ||
          parsedFallback.host.isEmpty) {
        throw StateError('API_FALLBACK_URL is not a valid URL: $rawFallback');
      }
      if (environment != AppEnvironment.dev &&
          parsedFallback.scheme != 'https') {
        throw StateError(
          'API_FALLBACK_URL must use HTTPS outside the dev environment.',
        );
      }
      fallbackUri = parsedFallback;
    }

    _instance = AppConfig._(
      environment: environment,
      apiBaseUrl: uri,
      apiFallbackUrl: fallbackUri,
    );
    return _instance!;
  }

  /// Test seam: build a config directly without touching dotenv.
  factory AppConfig.forTest({
    required AppEnvironment environment,
    required Uri apiBaseUrl,
    Uri? apiFallbackUrl,
  }) {
    return AppConfig._(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      apiFallbackUrl: apiFallbackUrl,
    );
  }

  static AppConfig get instance {
    final config = _instance;
    if (config == null) {
      throw StateError('AppConfig.load() must be called before first use.');
    }
    return config;
  }

  bool get isDev => environment == AppEnvironment.dev;
}

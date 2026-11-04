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
    this.verificationBaseUrl,
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

  /// Explicit override for verification base URL (e.g. `https://verify.joberthix.xyz/v`).
  final String? verificationBaseUrl;

  /// Public verification base URL for invoice QR codes (e.g. `https://verify.joberthix.xyz/v`).
  /// Always uses branded Cloudflare domain in production to shield Azure infrastructure.
  String get publicVerificationBaseUrl {
    if (verificationBaseUrl != null && verificationBaseUrl!.isNotEmpty) {
      return verificationBaseUrl!.replaceAll(RegExp(r'/+$'), '');
    }
    if (_dartDefineVerificationUrl.isNotEmpty) {
      return _dartDefineVerificationUrl.replaceAll(RegExp(r'/+$'), '');
    }
    if (environment == AppEnvironment.production) {
      return 'https://verify.joberthix.xyz/v';
    }
    return '${apiBaseUrl.origin}/v';
  }

  /// Helper to build public verification URL for a given token.
  String buildVerificationUrl(String token) => '$publicVerificationBaseUrl/$token';

  /// IANA timezone name from the device (e.g. `EAT`).
  String get timezone => DateTime.now().timeZoneName;

  /// Compile-time overrides win over `.env` values
  /// (`flutter build apk --dart-define=API_BASE_URL=https://...`).
  static const _dartDefineApiUrl = String.fromEnvironment('API_BASE_URL');
  static const _dartDefineFallbackUrl =
      String.fromEnvironment('API_FALLBACK_URL');
  static const _dartDefineEnv = String.fromEnvironment('APP_ENV');
  static const _dartDefineVerificationUrl =
      String.fromEnvironment('PUBLIC_VERIFICATION_URL');

  static AppConfig? _instance;

  /// Loaded in `main()` before `runApp`. Throws when configuration is unsafe.
  static AppConfig load() {
    String read(String key) {
      final compileTime = switch (key) {
        'API_BASE_URL' => _dartDefineApiUrl,
        'API_FALLBACK_URL' => _dartDefineFallbackUrl,
        'APP_ENV' => _dartDefineEnv,
        'PUBLIC_VERIFICATION_URL' => _dartDefineVerificationUrl,
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

    final rawVerification = read('PUBLIC_VERIFICATION_URL').trim();
    final verificationBaseUrl =
        rawVerification.isNotEmpty ? rawVerification : null;

    _instance = AppConfig._(
      environment: environment,
      apiBaseUrl: uri,
      apiFallbackUrl: fallbackUri,
      verificationBaseUrl: verificationBaseUrl,
    );
    return _instance!;
  }

  /// Test seam: build a config directly without touching dotenv.
  factory AppConfig.forTest({
    required AppEnvironment environment,
    required Uri apiBaseUrl,
    Uri? apiFallbackUrl,
    String? verificationBaseUrl,
  }) {
    return AppConfig._(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      apiFallbackUrl: apiFallbackUrl,
      verificationBaseUrl: verificationBaseUrl,
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

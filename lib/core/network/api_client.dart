import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'app_exception.dart';
import 'error_mapper.dart';

/// Contract for reading/writing the session tokens. Implemented with
/// flutter_secure_storage in production and fakes in tests.
abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

/// Result of a successful token rotation.
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

/// Performs the refresh-token exchange against `/api/v1/auth/refresh`.
/// Implemented by the auth feature (which owns session persistence) and
/// injected here so the network layer stays generic.
typedef TokenRefresher = Future<TokenPair> Function(String refreshToken);

/// Called when the session becomes unrecoverable (refresh rejected), so the
/// auth layer can route the user back to login.
typedef SessionExpiredCallback = void Function();

typedef PaymentRequiredCallback = Future<void> Function();

/// Central HTTP client for every backend call.
///
/// PATH CONVENTION: [baseUrl] points at the server root. Versioned business
/// endpoints are built with `ApiRoutes.v1('/...')` (→ `/api/v1/...`);
/// infrastructure probes use the unversioned constants on [ApiRoutes].
///
/// Security behaviour:
/// - Bearer access token attached from [TokenStore]; never cached elsewhere.
/// - On 401, performs a single-flight refresh via [refresher] and replays the
///   original request once. If refresh fails, clears the store and fires
///   [onSessionExpired].
/// - Logging never prints headers or bodies; release builds log failures only.
class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStore tokenStore,
    required TokenRefresher refresher,
    Dio? dio,
  })  : _tokenStore = tokenStore,
        _refresher = refresher,
        _primaryBaseUrl = config.apiBaseUrl.toString(),
        _fallbackBaseUrl = config.apiFallbackUrl?.toString() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: config.apiBaseUrl.toString(),
            connectTimeout: const Duration(seconds: 45),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              'X-Client-Timezone': config.timezone,
            },
          ),
        );
    _dio.interceptors.addAll([
      InterceptorsWrapper(onRequest: _attachAuth),
      QueuedInterceptorsWrapper(onError: _handleResponseError),
      _buildLoggingInterceptor(),
    ]);
  }

  final TokenStore _tokenStore;
  final TokenRefresher _refresher;
  final String _primaryBaseUrl;
  final String? _fallbackBaseUrl;
  late final Dio _dio;

  /// Set by the auth layer so it can route the user back to login when the
  /// session becomes unrecoverable mid-use. Mutable by design: the auth
  /// controller registers itself after both providers are constructed.
  SessionExpiredCallback? onSessionExpired;
  PaymentRequiredCallback? onPaymentRequired;

  /// In-flight refresh guard so parallel 401s trigger exactly one refresh.
  Future<TokenPair>? _refreshInFlight;
  Future<void>? _paymentRequiredInFlight;

  Dio get dio => _dio;

  /// The currently active base URL (primary or fallback after failover).
  String get activeBaseUrl => _dio.options.baseUrl;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic> extra = const {},
    CancelToken? cancelToken,
  }) =>
      _send(
        () => _dio.get<T>(
          path,
          queryParameters: query,
          options: Options(extra: extra),
          cancelToken: cancelToken,
        ),
      );

  Future<Response<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String> headers = const {},
    Map<String, dynamic> extra = const {},
    CancelToken? cancelToken,
  }) =>
      _send(
        () => _dio.post<T>(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers, extra: extra),
          cancelToken: cancelToken,
        ),
      );

  Future<Response<T>> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic> extra = const {},
  }) =>
      _send(() => _dio.put<T>(
            path,
            data: body,
            options: Options(
              headers: {'Content-Type': Headers.jsonContentType},
              extra: extra,
            ),
          ));

  Future<Response<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic> extra = const {},
  }) =>
      _send(() =>
          _dio.patch<T>(path, data: body, options: Options(extra: extra)));

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic> extra = const {},
  }) =>
      _send(() => _dio.delete<T>(path, options: Options(extra: extra)));

  /// Raw escape hatch for callers that must bypass the typed error mapping
  /// (e.g. file downloads). Prefer the typed methods above.
  Dio get raw => _dio;

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (_canFailover(error)) {
        _switchActiveHost();
        try {
          return await request();
        } on DioException catch (retryError) {
          if (retryError.response?.statusCode == 402) {
            await _notifyPaymentRequired();
          }
          throw mapDioException(retryError);
        }
      }
      if (error.response?.statusCode == 402) {
        await _notifyPaymentRequired();
      }
      throw mapDioException(error);
    }
  }

  bool _canFailover(DioException error) {
    final fallback = _fallbackBaseUrl;
    if (fallback == null || fallback.isEmpty || fallback == _primaryBaseUrl) {
      return false;
    }
    final status = error.response?.statusCode;
    if (status == 502 || status == 503 || status == 504) {
      return true;
    }
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  void _switchActiveHost() {
    final fallback = _fallbackBaseUrl;
    if (fallback == null || fallback.isEmpty) return;
    _dio.options.baseUrl =
        _dio.options.baseUrl == _primaryBaseUrl ? fallback : _primaryBaseUrl;
  }

  Future<void> _attachAuth(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skip_auth'] != true) {
      final token = await _tokenStore.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';

        // The access token carries no session identity, so the session list needs a way to
        // tell "this device" apart from the user's others. The refresh token is attached
        // *only* to that request rather than to every call: it is long-lived, and putting it
        // on all traffic would widen its exposure to any log or proxy along the way.
        // The server treats it as a display marker only, matching it against the stored hash.
        if (options.path.endsWith('/me/security/sessions')) {
          final refresh = await _tokenStore.readRefreshToken();
          if (refresh != null && refresh.isNotEmpty) {
            options.headers['X-Refresh-Token'] = refresh;
          }
        }
      }
    }
    handler.next(options);
  }

  Future<void> _handleResponseError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response?.statusCode != 401 ||
        err.requestOptions.extra['skip_retry'] == true) {
      handler.next(err);
      return;
    }

    try {
      final tokens = await (_refreshInFlight ??= _rotateTokens());
      final replay = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${tokens.accessToken}'
        ..extra['skip_retry'] = true;
      final resolved = await _dio.fetch<dynamic>(replay);
      handler.resolve(resolved);
    } on AppException {
      await _tokenStore.clear();
      onSessionExpired?.call();
      handler.next(err);
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _notifyPaymentRequired() async {
    final current = _paymentRequiredInFlight;
    if (current != null) {
      await current;
      return;
    }
    final request = _refreshEntitlement();
    _paymentRequiredInFlight = request;
    try {
      await request;
    } finally {
      if (identical(_paymentRequiredInFlight, request)) {
        _paymentRequiredInFlight = null;
      }
    }
  }

  Future<void> _refreshEntitlement() async {
    try {
      await onPaymentRequired?.call();
    } on Object {
      return;
    }
  }

  Future<TokenPair> _rotateTokens() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw UnauthorizedException();
    }

    // The refresher owns persistence of the new pair.
    return _refresher(refreshToken);
  }

  Interceptor _buildLoggingInterceptor() => InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!kReleaseMode) {
            debugPrint('→ ${options.method} ${options.uri.path}');
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;
          debugPrint(
            '← ${status ?? 'NO RESPONSE'} ${error.requestOptions.uri}',
          );
          if (status == 404 && !kReleaseMode) {
            // A 404 on a known route means client/server path drift —
            // surface the FULL url to make the mismatch obvious.
            debugPrint(
              '  ⚠ 404 — check ApiRoutes vs backend endpoint mapping '
              '(${error.requestOptions.uri})',
            );
          }
          handler.next(error);
        },
      );

  /// Strips credentials from header maps before any logging.
  @visibleForTesting
  static Map<String, String> redactHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (key.toLowerCase() == 'authorization') {
        return MapEntry(key, '<redacted>');
      }
      return MapEntry(key, value.toString());
    });
  }
}

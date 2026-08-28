import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' show Options, DioException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_routes.dart';
import 'app_exception.dart';

/// How usable the connection to the Business OS API currently is.
///
/// Interface presence alone means nothing (Wi-Fi without internet is the
/// classic shop-floor case): [online] is only reached after a successful API
/// probe or a recent successful authenticated call.
enum ConnectionQuality {
  /// Not yet measured.
  unknown,

  /// No network interface, or repeated failures — sell offline.
  offline,

  /// Interface up but the API is not reachable right now — sell offline,
  /// keep retrying in the background.
  unreachable,

  /// API confirmed reachable — normal online flow.
  online,
}

/// Watches connectivity_plus events and verifies actual API reachability
/// with a cheap unauthenticated health probe plus hysteresis so flapping
/// links don't flip the POS banner every second.
class ConnectivityMonitor extends StateNotifier<ConnectionQuality> {
  ConnectivityMonitor({
    required ApiClient apiClient,
    Connectivity? connectivity,
  })  : _apiClient = apiClient,
        _connectivity = connectivity ?? Connectivity(),
        super(ConnectionQuality.unknown) {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (_) => scheduleCheck(),
    );
    scheduleCheck();
  }

  final ApiClient _apiClient;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;
  int _consecutiveFailures = 0;

  static const _probePath = ApiRoutes.healthLive;
  static const _probeTimeout = Duration(seconds: 5);

  /// Fired exactly once per offline→online transition so listeners can kick
  /// the sync engine.
  void Function()? onRestored;

  void scheduleCheck() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => check());
  }

  /// Re-evaluates reachability now.
  Future<void> check() async {
    final hasInterface = await _hasInterface();
    if (!hasInterface) {
      _consecutiveFailures = 0;
      _set(ConnectionQuality.offline);
      return;
    }
    final reachable = await _probe();
    if (reachable) {
      final wasOffline =
          state == ConnectionQuality.offline || state == ConnectionQuality.unreachable;
      _consecutiveFailures = 0;
      _set(ConnectionQuality.online);
      if (wasOffline) {
        onRestored?.call();
      }
      return;
    }
    _consecutiveFailures++;
    if (_consecutiveFailures >= 2) {
      _set(ConnectionQuality.unreachable);
    } else {
      // One failure: don't flip the whole POS yet.
      state = state == ConnectionQuality.online
          ? ConnectionQuality.unreachable
          : state;
    }
  }

  /// Lets the network layer report ground truth: any successful authenticated
  /// response proves reachability better than a probe can.
  void noteApiSuccess() {
    _consecutiveFailures = 0;
    final wasOffline =
        state == ConnectionQuality.offline || state == ConnectionQuality.unreachable;
    if (state != ConnectionQuality.online && wasOffline) {
      onRestored?.call();
    }
    if (state != ConnectionQuality.online) {
      state = ConnectionQuality.online;
    }
  }

  Future<bool> _hasInterface() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<bool> _probe() async {
    try {
      await _apiClient.raw.get<dynamic>(
        _probePath,
        options: Options(
          sendTimeout: _probeTimeout,
          receiveTimeout: _probeTimeout,
          // Unauthenticated endpoint: never touch token storage here. The
          // auth-interceptor read contends with session bootstrap at app
          // start, and concurrent flutter_secure_storage platform-channel
          // reads can deadlock on some Android builds — parking the whole
          // journey on the splash screen.
          extra: const {'skip_auth': true},
        ),
      );
      return true;
    } on DioException {
      return false;
    } on AppException {
      return false;
    }
  }

  void _set(ConnectionQuality quality) {
    if (state != quality) {
      state = quality;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/network/api_client.dart';
import '../application/auth_controller.dart';
import '../application/security_controller.dart';
import 'auth_repository.dart';
import 'security_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  final journal = ref.watch(sessionJournalProvider);
  final offlineStore = ref.watch(offlineCredentialStoreProvider);

  late final AuthRepository repository;
  final client = ApiClient(
    config: config,
    tokenStore: tokenStore,
    refresher: (refreshToken) => repository.refresh(refreshToken),
  );
  repository = AuthRepository(
    apiClient: client,
    tokenStore: tokenStore,
    offlineCredentialStore: offlineStore,
    onSessionEstablished: () => journal.markAuthenticated(),
  );
  return repository;
});

/// Concrete [ApiClient] wired from the [AuthRepository].
final apiClientProvider = Provider<ApiClient>(
  (ref) => ref.watch(authRepositoryProvider).apiClient,
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Own-account security screen state: second-factor enrolment and device list.
final securityControllerProvider =
    NotifierProvider<SecurityController, SecurityState>(SecurityController.new);

/// Own-account security: second-factor enrolment and the device list.
///
/// Separate from `authControllerProvider` because these are management screens
/// reached after signing in, and they want their own loading/error state rather
/// than the global auth lifecycle state.
final securityRepositoryProvider = Provider<SecurityRepository>(
  (ref) => SecurityRepository(ref.watch(authRepositoryProvider)),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../platform/device_info.dart';
import '../session/app_lock.dart';
import '../storage/db_key_store.dart';
import '../storage/local_database.dart';
import '../storage/offline_cache_dao.dart';
import '../storage/session_journal.dart';
import '../../features/authentication/data/biometric_auth_gate.dart';
import '../../features/authentication/data/offline_credential_store.dart';
import '../../features/authentication/data/secure_token_store.dart';
import '../../features/sales/data/branch_cache.dart';
import '../sync/local_sales_service.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.instance);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError(
      'localDatabaseProvider must be overridden at bootstrap'),
);

final dbKeyStoreProvider = Provider<DbKeyStore>((ref) => DbKeyStore());

final deviceIdentityProvider =
    Provider<DeviceIdentity>((ref) => DeviceIdentity());

final sessionJournalProvider = Provider<SessionJournal>(
  (ref) => SessionJournal(ref.watch(localDatabaseProvider)),
);

final localSalesServiceProvider = Provider<LocalSalesService>(
  (ref) => LocalSalesService(database: ref.watch(localDatabaseProvider)),
);

final offlineCacheDaoProvider = Provider<OfflineCacheDao>(
  (ref) => OfflineCacheDao(ref.watch(localDatabaseProvider)),
);

/// Abstract: overridden by [auth_providers.dart] with the authenticated client.
final apiClientProvider = Provider<ApiClient>(
  (ref) =>
      throw UnimplementedError('apiClientProvider must be overridden by auth'),
);

final offlineCredentialStoreProvider = Provider<OfflineCredentialStore>(
  (ref) => OfflineCredentialStore(),
);

final biometricAuthGateProvider = Provider<BiometricAuthGate>(
  (ref) => BiometricAuthGate(),
);

final branchCacheProvider = Provider<BranchCache>(
  (ref) => BranchCache(),
);

/// Idle/background auto-lock policy (theft mitigation). Overridable in tests.
final appLockPolicyProvider = Provider<AppLockPolicy>(
  (ref) => const AppLockPolicy(),
);

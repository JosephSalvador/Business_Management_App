import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart' show localDatabaseProvider;
import '../../authentication/data/auth_providers.dart';
import 'capabilities_dao.dart';
import 'capabilities_repository.dart';

final capabilitiesDaoProvider = Provider<CapabilitiesDao>((ref) {
  return CapabilitiesDao(ref.watch(localDatabaseProvider));
});

final capabilitiesRepositoryProvider = Provider<CapabilitiesRepository>((ref) {
  return CapabilitiesRepository(
    apiClient: ref.watch(apiClientProvider),
    dao: ref.watch(capabilitiesDaoProvider),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/role_models.dart';

export '../application/roles_controller.dart';
export 'role_repository.dart';

final roleRepositoryProvider = Provider<RoleRepository>(
  (ref) => RoleRepository(apiClient: ref.watch(apiClientProvider)),
);

final rolesControllerProvider = NotifierProvider<RolesController, RolesState>(
  RolesController.new,
);

final permissionsProvider = FutureProvider<List<Permission>>((ref) async {
  final repository = ref.watch(roleRepositoryProvider);
  return repository.permissions();
});

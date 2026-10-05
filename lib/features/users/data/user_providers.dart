import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../../roles/data/role_models.dart';
import '../application/users_controller.dart';
import 'user_repository.dart';

export '../application/users_controller.dart';
export 'user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(apiClient: ref.watch(apiClientProvider)),
);

final usersControllerProvider = NotifierProvider<UsersController, UsersState>(
  UsersController.new,
);

final rolesProvider = FutureProvider<List<Role>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.roles();
});

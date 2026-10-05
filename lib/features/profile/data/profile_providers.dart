import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/profile_controller.dart';
import 'profile_repository.dart';

export '../application/profile_controller.dart';
export 'profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(apiClient: ref.watch(apiClientProvider)),
);

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);

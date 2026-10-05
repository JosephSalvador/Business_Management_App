import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/workspace_controller.dart';
import 'workspace_repository.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(apiClient: ref.watch(apiClientProvider)),
);

final workspaceControllerProvider =
    NotifierProvider<WorkspaceController, WorkspaceState>(
  WorkspaceController.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace.dart';

/// Lifecycle of the workspace journey after authentication.
sealed class WorkspaceState {
  const WorkspaceState();
}

/// Bootstrapping: the workspace list has not been fetched yet.
class WorkspaceLoading extends WorkspaceState {
  const WorkspaceLoading();
}

/// Authenticated but no business exists yet — onboarding must run.
class WorkspaceEmpty extends WorkspaceState {
  const WorkspaceEmpty();
}

/// Workspaces are known; [selected] drives which one the app operates on.
class WorkspaceReady extends WorkspaceState {
  const WorkspaceReady({required this.workspaces, this.selected});

  final List<Workspace> workspaces;
  final Workspace? selected;

  bool get hasSelection => selected != null;
}

class WorkspaceFailure extends WorkspaceState {
  const WorkspaceFailure(this.message);

  final String message;
}

/// Loads workspaces on login and drives selection + onboarding completion.
class WorkspaceController extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() => const WorkspaceLoading();

  WorkspaceRepository get _repository => ref.read(workspaceRepositoryProvider);

  /// Fetches `/workspaces/mine` and transitions to empty/ready.
  Future<void> load() async {
    state = const WorkspaceLoading();
    try {
      final workspaces = await _repository.mine();
      if (workspaces.isEmpty) {
        state = const WorkspaceEmpty();
        return;
      }
      state = WorkspaceReady(
        workspaces: workspaces,
        selected: workspaces.first,
      );
    } on AppException catch (error) {
      state = WorkspaceFailure(error.message);
    }
  }

  /// Picks the workspace subsequent screens operate on.
  void select(Workspace workspace) {
    final current = state;
    if (current is! WorkspaceReady) {
      return;
    }
    if (!current.workspaces.any((w) => w.id == workspace.id)) {
      return;
    }
    state = WorkspaceReady(workspaces: current.workspaces, selected: workspace);
  }

  /// Submits onboarding for the (single) tenant and refreshes the list.
  /// [load] auto-selects the refreshed workspace on success.
  Future<void> createBusiness(OnboardingDraft draft) async {
    await _repository.completeOnboarding(draft);
    await load();
  }

  /// Clears journey state on logout/session loss.
  void reset() {
    state = const WorkspaceLoading();
  }
}

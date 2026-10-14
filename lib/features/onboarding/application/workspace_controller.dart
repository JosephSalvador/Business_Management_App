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
  ///
  /// Uses a stale-while-revalidate strategy: if a cached workspace is found,
  /// immediately transitions to [WorkspaceReady] so UI navigation isn't blocked,
  /// then revalidates in background with `/api/v1/workspaces/mine`.
  Future<void> load() async {
    // 1. Optimistic hydration from local storage if state isn't already ready
    if (state is! WorkspaceReady) {
      final cached = await _repository.getCachedWorkspace();
      if (cached != null) {
        state = WorkspaceReady(
          workspaces: [cached],
          selected: cached,
        );
      } else {
        state = const WorkspaceLoading();
      }
    }

    // 2. Fetch authoritative state from backend
    try {
      final workspaces = await _repository.mine();
      if (workspaces.isEmpty) {
        state = const WorkspaceEmpty();
        return;
      }

      // Preserve existing valid selection if possible, otherwise default to first
      final currentSelected = (state is WorkspaceReady)
          ? (state as WorkspaceReady).selected
          : null;

      final selected = (currentSelected != null &&
              workspaces.any((w) => w.id == currentSelected.id))
          ? workspaces.firstWhere((w) => w.id == currentSelected.id)
          : workspaces.first;

      state = WorkspaceReady(
        workspaces: workspaces,
        selected: selected,
      );

      // Persist chosen workspace to cache
      await _repository.saveCachedWorkspace(selected);
    } on AppException catch (error) {
      // If we already have optimistic cached data, don't crash to failure view;
      // keep the user working offline.
      if (state is! WorkspaceReady) {
        state = WorkspaceFailure(error.message);
      }
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
    _repository.saveCachedWorkspace(workspace);
  }

  /// Submits onboarding for the (single) tenant and refreshes the list.
  /// [load] auto-selects the refreshed workspace on success.
  Future<void> createBusiness(OnboardingDraft draft) async {
    final workspace = await _repository.completeOnboarding(draft);
    await _repository.saveCachedWorkspace(workspace);
    await load();
  }

  /// Clears journey state on logout/session loss.
  void reset() {
    state = const WorkspaceLoading();
    _repository.clearCachedWorkspace();
  }
}

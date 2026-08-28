import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../application/workspace_controller.dart';
import '../../domain/workspace.dart';

/// Chooses which business the app operates on. With the current single-tenant
/// data model this list always holds exactly one entry, but the screen (and
/// the endpoint) are ready for a memberships redesign.
class WorkspacePickerPage extends ConsumerWidget {
  const WorkspacePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final workspaces =
        state is WorkspaceReady ? state.workspaces : const <Workspace>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Biashara zako')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final workspace in workspaces)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    workspace.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '${workspace.countryCode} · ${workspace.currency}'
                    '${workspace.onboardingComplete ? '' : ' · Haijakamilika'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ref
                      .read(workspaceControllerProvider.notifier)
                      .select(workspace),
                ),
              ),
            if (workspaces.isEmpty)
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
              },
              child: const Text('Toka'),
            ),
          ],
        ),
      ),
    );
  }
}

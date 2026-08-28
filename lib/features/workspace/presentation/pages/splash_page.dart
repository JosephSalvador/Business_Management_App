import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../application/workspace_controller.dart';

/// Shown while the session/workspace bootstrap resolves. Also renders the
/// workspace failure state with a retry action — the router parks every
/// undetermined situation here, so this screen must never redirect on its own.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceControllerProvider);

    return Scaffold(
      body: Center(
        child: switch (workspace) {
          WorkspaceFailure(:final message) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(workspaceControllerProvider.notifier).load(),
                  child: const Text('Jaribu tena'),
                ),
              ],
            ),
          _ => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Business OS',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ),
        },
      ),
    );
  }
}

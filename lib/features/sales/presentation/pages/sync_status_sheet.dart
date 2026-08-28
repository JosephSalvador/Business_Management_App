import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/connectivity_monitor.dart';

/// A small, calm summary of how sales are doing against the internet
/// (M5.16). No queues, no retries, no HTTP — just what a shop worker needs.
Future<void> showSyncStatusSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _SyncStatusSheet(),
  );
}

class _SyncStatusSheet extends ConsumerWidget {
  const _SyncStatusSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final connection = ref.watch(connectivityMonitorProvider);
    final theme = Theme.of(context);

    final (icon, internetLabel, color) = switch (connection) {
      ConnectionQuality.online => (
          Icons.wifi,
          'Internet: Ipo',
          theme.colorScheme.primary
        ),
      ConnectionQuality.offline => (
          Icons.wifi_off,
          'Internet: Offline',
          Colors.orange.shade800
        ),
      ConnectionQuality.unreachable => (
          Icons.cloud_off,
          'Internet: Haifiki kwa sasa',
          Colors.orange.shade800
        ),
      ConnectionQuality.unknown => (
          Icons.help_outline,
          'Internet: Inaangaliwa...',
          theme.colorScheme.outline
        ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Text(internetLabel, style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(height: 28),
            _Row(
              icon: Icons.hourglass_top,
              label: 'Mauzo yanayosubiri:',
              value: '${status.pendingCount}',
            ),
            if (status.conflictCount > 0)
              _Row(
                icon: Icons.error_outline,
                label: 'Yanahitaji kuangaliwa:',
                value: '${status.conflictCount}',
                valueColor: theme.colorScheme.error,
              ),
            if (status.lastSyncAt != null)
              _Row(
                icon: Icons.check_circle_outline,
                label: 'Mara ya mwisho ya sawazisha:',
                value: _timeAgo(status.lastSyncAt!),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: connection == ConnectionQuality.online
                    ? const Icon(Icons.sync)
                    : const Icon(Icons.sync_disabled),
                label: const Text('Sawazisha sasa'),
                onPressed: connection == ConnectionQuality.online
                    ? () async {
                        final engine = ref.read(syncEngineProvider);
                        await engine.drain(forceRetryAll: true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Muhtasari umesasishwa.'),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime utc) {
    final diff = DateTime.now().toUtc().difference(utc);
    if (diff.inMinutes < 1) {
      return 'sasa hivi';
    }
    if (diff.inHours < 1) {
      return 'dakika ${diff.inMinutes} zilizopita';
    }
    return 'saa ${diff.inHours} zilizopita';
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

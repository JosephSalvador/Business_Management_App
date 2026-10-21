import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/connectivity_monitor.dart';
import '../../../../core/storage/local_database.dart';

/// A comprehensive, calm outbox and sync status sheet (M5.16).
/// Shows connection quality, pending outbox sales, conflicts, and lets the
/// cashier trigger a manual sync with live visual feedback.
Future<void> showSyncStatusSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
          'Mtandao: Upo tayari',
          theme.colorScheme.primary
        ),
      ConnectionQuality.offline => (
          Icons.wifi_off,
          'Mtandao: Haukata (Offline)',
          Colors.orange.shade800
        ),
      ConnectionQuality.unreachable => (
          Icons.cloud_off,
          'Mtandao: Seva haipatikani',
          Colors.orange.shade800
        ),
      ConnectionQuality.unknown => (
          Icons.help_outline,
          'Mtandao: Inaangaliwa...',
          theme.colorScheme.outline
        ),
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Text(
                    internetLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Onyesha upya',
                    onPressed: () =>
                        ref.read(syncStatusProvider.notifier).refresh(),
                  ),
                ],
              ),
              if (status.isSyncing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              const Divider(height: 24),
              _Row(
                icon: Icons.hourglass_top,
                label: 'Mauzo yanayosubiri kutumwa (Outbox):',
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
                  label: 'Mara ya mwisho kusawazisha:',
                  value: _timeAgo(status.lastSyncAt!),
                ),
              if (status.pendingSales.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Stakabadhi za Outbox (${status.pendingSales.length}):',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: status.pendingSales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sale = status.pendingSales[index];
                      return _PendingSaleTile(sale: sale);
                    },
                  ),
                ),
              ],
              if (status.conflictSales.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Hitilafu zilizotokea (${status.conflictSales.length}):',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: status.conflictSales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sale = status.conflictSales[index];
                      return _ConflictSaleTile(sale: sale);
                    },
                  ),
                ),
              ],
              if (connection != ConnectionQuality.online &&
                  status.pendingCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mauzo yote yamehifadhiwa salama kwenye simu. Yatasawazishwa kiotomatiki mtandao ukirudi.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: status.isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : (connection == ConnectionQuality.online
                          ? const Icon(Icons.sync)
                          : const Icon(Icons.sync_disabled)),
                  label: Text(
                    status.isSyncing ? 'Inasawazisha...' : 'Sawazisha sasa',
                  ),
                  onPressed: (!status.isSyncing &&
                          connection == ConnectionQuality.online)
                      ? () async {
                          await ref
                              .read(syncStatusProvider.notifier)
                              .triggerSync();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Usawazishaji umekamilika.'),
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
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

class _PendingSaleTile extends StatelessWidget {
  const _PendingSaleTile({required this.sale});

  final LocalSale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr =
        '${sale.effectiveAt.hour.toString().padLeft(2, '0')}:${sale.effectiveAt.minute.toString().padLeft(2, '0')}';
    final idShort = sale.clientSaleId.length > 8
        ? sale.clientSaleId.substring(0, 8).toUpperCase()
        : sale.clientSaleId.toUpperCase();

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFFFF3E0),
        child: Icon(Icons.receipt_long, size: 16, color: Colors.orange),
      ),
      title: Text(
        'OFFLINE #$idShort',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text('Saa $timeStr • Pesa Taslimu / Nje ya Mtandao'),
      trailing: Text(
        '${sale.currency} ${sale.totalEstimate.toStringAsFixed(0)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ConflictSaleTile extends StatelessWidget {
  const _ConflictSaleTile({required this.sale});

  final LocalSale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idShort = sale.clientSaleId.length > 8
        ? sale.clientSaleId.substring(0, 8).toUpperCase()
        : sale.clientSaleId.toUpperCase();

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.red.shade50,
        child: Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
      ),
      title: Text(
        '#$idShort',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.error,
        ),
      ),
      subtitle: Text(
        sale.errorMessage ?? 'Hitilafu wakati wa kutuma mauzo',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${sale.currency} ${sale.totalEstimate.toStringAsFixed(0)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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

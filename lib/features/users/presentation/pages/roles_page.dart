import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../../../roles/data/role_models.dart';

class RolesPage extends ConsumerStatefulWidget {
  const RolesPage({super.key});

  @override
  ConsumerState<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends ConsumerState<RolesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(rolesControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rolesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.navRoles),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/roles/new'),
          ),
        ],
      ),
      body: WaveBackground(
        child: switch (state) {
          RolesLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          RolesFailure(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(rolesControllerProvider.notifier).load(),
                    child: Text(context.loc.commonRetry),
                  ),
                ],
              ),
            ),
          RolesLoaded(:final items) => RefreshIndicator(
              onRefresh: () =>
                  ref.read(rolesControllerProvider.notifier).load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final role = items[index];
                  return _buildRoleTile(role);
                },
              ),
            ),
        },
      ),
    );
  }

  Widget _buildRoleTile(Role role) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: role.isSystem
                ? const Color(0xFFFFA502).withValues(alpha: 0.1)
                : const Color(0xFF0066FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            role.isSystem ? Icons.shield : Icons.security,
            color: role.isSystem
                ? const Color(0xFFFFA502)
                : const Color(0xFF0066FF),
            size: 20,
          ),
        ),
        title: Text(role.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role.description != null && role.description!.isNotEmpty)
              Text(role.description!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            if (!role.isSystem && _isStarterRole(role.name))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.loc.rolesStarterBadge,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              context.loc
                  .rolesPermissionCount('${role.permissionNames.length}'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: role.isSystem
            ? const Icon(Icons.chevron_right)
            : PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, role),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.loc.commonDelete,
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
        onTap: () => context.push('/roles/${role.id}/edit'),
      ),
    );
  }

  bool _isStarterRole(String roleName) => const {
        'Manager',
        'Cashier',
        'Inventory Officer',
        'Accountant',
      }.contains(roleName);

  void _handleMenuAction(String action, Role role) {
    switch (action) {
      case 'delete':
        _confirmDelete(role);
        break;
    }
  }

  void _confirmDelete(Role role) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.rolesDeleteTitle),
        content: Text(context.loc.rolesDeleteMessage(role.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(rolesControllerProvider.notifier).delete(role.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.loc.commonDelete),
          ),
        ],
      ),
    );
  }
}

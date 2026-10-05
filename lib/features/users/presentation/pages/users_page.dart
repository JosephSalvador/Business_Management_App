import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../../../users/data/user_models.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(usersControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.usersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push('/users/new'),
          ),
        ],
      ),
      body: WaveBackground(
        child: switch (state) {
          UsersLoading() => const Center(child: CircularProgressIndicator()),
          UsersFailure(:final message) => Center(child: Text(message)),
          UsersLoaded(:final items) => RefreshIndicator(
              onRefresh: () =>
                  ref.read(usersControllerProvider.notifier).load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final user = items[index];
                  return _buildUserTile(user);
                },
              ),
            ),
        },
      ),
    );
  }

  Widget _buildUserTile(IdentityUser user) {
    final name = user.fullName.isNotEmpty ? user.fullName : user.email;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive
              ? const Color(0xFF0066FF).withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          child: Text(
            initials,
            style: TextStyle(
              color: user.isActive ? const Color(0xFF0066FF) : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(user.email,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, user),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(user.isActive
                  ? context.loc.usersDeactivate
                  : context.loc.usersActivate),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(context.loc.usersDelete,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => context.push('/users/${user.id}/edit'),
      ),
    );
  }

  void _handleMenuAction(String action, IdentityUser user) {
    final controller = ref.read(usersControllerProvider.notifier);
    switch (action) {
      case 'toggle':
        controller.toggleStatus(user.id, !user.isActive);
        break;
      case 'delete':
        _confirmDelete(user);
        break;
    }
  }

  void _confirmDelete(IdentityUser user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.usersDeleteTitle),
        content: Text(context.loc.usersDeleteMessage(
            user.fullName.isNotEmpty ? user.fullName : user.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(usersControllerProvider.notifier).delete(user.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.loc.usersDeleteConfirm),
          ),
        ],
      ),
    );
  }
}

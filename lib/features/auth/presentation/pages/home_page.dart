import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../l10n/loc.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../products/presentation/pages/stock_page.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../workspace/application/workspace_controller.dart';
import '../../application/auth_controller.dart';

/// The authenticated Business OS shell. Navigation stays intentionally small:
/// Mauzo / Bidhaa / Stock / Ripoti / Zaidi. POS becomes the primary tab in M4.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late int _tab = widget.initialTab.clamp(0, 4);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final session = auth is AuthAuthenticated ? auth.session : null;
    final workspace = ref.watch(workspaceControllerProvider);
    final business = workspace is WorkspaceReady ? workspace.selected?.name : null;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const PosPage(),
          const ProductsPage(),
          const StockPage(),
          const _PlaceholderTab(
            icon: Icons.bar_chart,
            title: 'Ripoti',
            message: 'Ripoti zinakuja hivi karibuni.',
          ),
          _MoreTab(
            businessName: business,
            email: session?.user.email,
            isOwner: session?.user.hasPermission('Users.Create') ?? false,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Mauzo'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Bidhaa'),
          NavigationDestination(icon: Icon(Icons.warehouse_outlined), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Ripoti'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Zaidi'),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MoreTab extends ConsumerWidget {
  const _MoreTab({
    required this.businessName,
    required this.email,
    required this.isOwner,
  });

  final String? businessName;
  final String? email;
  final bool isOwner;

  /// Logout must never silently abandon pending offline sales (M5.17): the
  /// worker is warned and must confirm. Tokens are cleared regardless; the
  /// encrypted local database is retained so a later login on this device
  /// can finish syncing.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final pendingCount =
        await ref.read(localSalesServiceProvider).pendingSaleCount();
    if (!context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Toka?'),
        content: pendingCount > 0
            ? Text(
                'Mauzo $pendingCount yanasubiri intaneti. '
                'Yatahifadhiwa kwenye kifaa hiki na yatasawazishwa '
                'ukirudi kama mtumiaji huyu.',
              )
            : const Text('Unataka kutoka kwenye akaunti?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Baki'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Toka'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zaidi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (businessName != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: Text(businessName!),
                subtitle: email == null ? null : Text(email!),
              ),
            ),
          const SizedBox(height: 8),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.group),
              title: Text(context.loc.staffTitle),
              onTap: () => context.push(Routes.staff),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Toka'),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }
}

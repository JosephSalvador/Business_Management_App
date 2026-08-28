import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../products/application/catalog_controller.dart';
import '../../../workspace/application/workspace_controller.dart';

/// First-run business setup, shown once after creating the business and
/// before the first product. Confirms what was configured, prepares starter
/// units of measure, and hands over to the products screen.
class BusinessSetupPage extends ConsumerStatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  ConsumerState<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends ConsumerState<BusinessSetupPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(catalogControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceControllerProvider);
    final catalog = ref.watch(catalogControllerProvider);
    final selected =
        workspace is WorkspaceReady ? workspace.selected : null;
    if (selected == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final unitsReady = catalog is CatalogReady;
    final catalogFailed = catalog is CatalogFailure;

    return Scaffold(
      appBar: AppBar(title: const Text('Tuanzishe biashara yako')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Karibu! Biashara yako imeandikishwa.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Biashara', selected.name),
                  if (selected.businessType != null)
                    _row('Aina', selected.businessType!),
                  _row('Nchi', selected.countryCode),
                  _row('Sarafu', selected.currency),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(
                unitsReady ? Icons.check_circle : Icons.hourglass_top,
                color: unitsReady
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_preparationMessage(unitsReady, catalogFailed))),
            ],
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: unitsReady
                ? () => context.go('/home?tab=bidhaa')
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Anza kuongeza bidhaa'),
          ),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Baadaye — nenda kwenye biashara'),
          ),
        ],
      ),
    );
  }

  static String _preparationMessage(bool ready, bool failed) {
    if (ready) {
      return 'Vipimo na mahali pa kuhifadhi viko tayari.';
    }
    if (failed) {
      return 'Imeshindikana kuandaa vipimo. Jaribu tena baadaye.';
    }
    return 'Tunaandaa vipimo vya kawaida…';
  }

  static Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

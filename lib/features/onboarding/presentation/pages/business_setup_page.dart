import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../../../products/application/catalog_controller.dart';
import '../../application/workspace_controller.dart';

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
    final selected = workspace is WorkspaceReady ? workspace.selected : null;
    if (selected == null) {
      return Scaffold(
        body: WaveBackground(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final unitsReady = catalog is CatalogReady;
    final catalogFailed = catalog is CatalogFailure;

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.businessSetupTitle)),
      body: WaveBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              context.loc.businessSetupWelcome,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(context.loc.businessSetupBusiness, selected.name),
                    if (selected.businessType != null)
                      _row(context.loc.businessSetupType,
                          selected.businessType!),
                    _row(context.loc.createBusinessCountry,
                        selected.countryCode),
                    _row(context.loc.createBusinessCurrency, selected.currency),
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
                Expanded(
                    child: Text(_preparationMessage(
                        context, unitsReady, catalogFailed))),
              ],
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: unitsReady ? () => context.go('/home?tab=1') : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: Text(context.loc.businessSetupAddProducts),
            ),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text(context.loc.businessSetupLater),
            ),
          ],
        ),
      ),
    );
  }

  static String _preparationMessage(
      BuildContext context, bool ready, bool failed) {
    final loc = context.loc;
    if (ready) {
      return loc.businessSetupUnitsReady;
    }
    if (failed) {
      return loc.businessSetupUnitsFailed;
    }
    return loc.businessSetupPreparing;
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

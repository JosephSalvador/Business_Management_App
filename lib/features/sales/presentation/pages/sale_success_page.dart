import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/format/money.dart';
import '../../domain/sale.dart';

/// Shown after a successful sale. The fastest action — selling again — is the
/// primary button.
class SaleSuccessPage extends StatelessWidget {
  const SaleSuccessPage({super.key, required this.sale});

  final SaleDto sale;

  @override
  Widget build(BuildContext context) {
    final method =
        sale.payments.isEmpty ? '' : sale.payments.first.label;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.check_circle,
                    color: theme.colorScheme.primary, size: 96),
                const SizedBox(height: 16),
                Text(
                  'Muamala umekamilika',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (sale.pendingLocally) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mauzo ya Offline — yatasawazishwa internet ikirudi.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.orange.shade900),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _Row(
                            label: 'Risiti',
                            value: sale.number.isEmpty
                                ? 'Itakamilika baadaye'
                                : sale.number),
                        const SizedBox(height: 8),
                        _Row(
                          label: 'Jumla',
                          value: formatMoney(sale.totalAmount),
                        ),
                        const SizedBox(height: 8),
                        _Row(label: 'Malipo', value: method),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go(Routes.pos),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child:
                      const Text('Uza tena', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () =>
                      context.push(Routes.receipt(sale.id)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Chapisha risiti'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () =>
                      context.push(Routes.saleDetail(sale.id)),
                  child: const Text('Shiriki'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

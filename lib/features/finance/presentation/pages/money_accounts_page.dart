import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/payment_labels.dart';
import '../../data/money_account_providers.dart';

class MoneyAccountsPage extends ConsumerStatefulWidget {
  const MoneyAccountsPage({super.key});

  @override
  ConsumerState<MoneyAccountsPage> createState() => _MoneyAccountsPageState();
}

class _MoneyAccountsPageState extends ConsumerState<MoneyAccountsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(moneyAccountsControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moneyAccountsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.moneyAccountsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/finance/accounts/new'),
          ),
        ],
      ),
      body: WaveBackground(
        child: switch (state) {
          MoneyAccountsLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          MoneyAccountsFailure(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(moneyAccountsControllerProvider.notifier)
                        .load(),
                    child: Text(context.loc.commonRetry),
                  ),
                ],
              ),
            ),
          MoneyAccountsLoaded(
            :final accounts,
            :final isEmpty,
            :final totalBalance
          ) =>
            isEmpty
                ? EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: context.loc.moneyAccountsEmpty,
                    message: context.loc.moneyAccountsEmptyMessage,
                    actionLabel: context.loc.createAccountTitle,
                    onAction: () => context.push('/finance/accounts/new'),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(moneyAccountsControllerProvider.notifier)
                        .load(),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0066FF).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.loc.moneyAccountsTotalBalance,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatMoney(totalBalance),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0066FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: accounts.length,
                            itemBuilder: (context, index) =>
                                _buildAccountTile(accounts[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
        },
      ),
    );
  }

  Widget _buildAccountTile(Map<String, dynamic> account) {
    final name = account['name'] ?? '';
    final type = account['type'] as int? ?? 0;
    final balance = (account['balance'] ?? 0).toDouble();
    final isActive = account['isActive'] ?? true;

    final (icon, typeLabel, color) = switch (type) {
      0 => (
          Icons.payments,
          moneyAccountTypeLabel(context.loc, 0),
          const Color(0xFF16A34A)
        ),
      1 => (
          Icons.phone_android,
          moneyAccountTypeLabel(context.loc, 1),
          const Color(0xFF0066FF)
        ),
      2 => (
          Icons.account_balance,
          moneyAccountTypeLabel(context.loc, 2),
          const Color(0xFF8B5CF6)
        ),
      _ => (
          Icons.more_horiz,
          moneyAccountTypeLabel(context.loc, type),
          Colors.grey
        ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          typeLabel,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(balance),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (!isActive)
              Text(
                context.loc.moneyAccountsInactive,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
          ],
        ),
        onTap: () => context.push('/finance/accounts/${account['id']}'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/payment_labels.dart';
import '../../data/money_account_providers.dart';

final _accountDetailFutureProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(moneyAccountsControllerProvider.notifier).getById(id);
});

final _accountTransactionsFutureProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, accountId) async {
  return ref
      .read(moneyAccountsControllerProvider.notifier)
      .getTransactions(accountId);
});

class MoneyAccountDetailPage extends ConsumerWidget {
  const MoneyAccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccount = ref.watch(_accountDetailFutureProvider(accountId));
    final asyncTransactions =
        ref.watch(_accountTransactionsFutureProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.moneyAccountTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'income',
                child: Text(context.loc.moneyAccountAddIncome),
              ),
              PopupMenuItem(
                value: 'expense',
                child: Text(context.loc.moneyAccountAddExpense),
              ),
              PopupMenuItem(
                value: 'transfer',
                child: Text(context.loc.moneyAccountTransfer),
              ),
            ],
          ),
        ],
      ),
      body: WaveBackground(
        child: asyncAccount.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              Center(child: Text(context.loc.moneyAccountNotFound)),
          data: (account) =>
              _buildContent(context, ref, account, asyncTransactions),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'income':
        context.push('/finance/accounts/$accountId/income');
        break;
      case 'expense':
        context.push('/finance/accounts/$accountId/expense');
        break;
      case 'transfer':
        context.push('/finance/accounts/$accountId/transfer');
        break;
    }
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> account,
    AsyncValue<List<Map<String, dynamic>>> asyncTransactions,
  ) {
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

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  typeLabel,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Text(
                  formatMoney(balance),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: balance >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
                if (!isActive) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.loc.moneyAccountInactive,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.loc.moneyAccountRecentActivity,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(
                      _accountTransactionsFutureProvider(accountId)),
                  child: Text(context.loc.moneyAccountUpdate),
                ),
              ],
            ),
          ),
          asyncTransactions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.loc.commonWithError(e.toString())),
            ),
            data: (transactions) {
              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        context.loc.moneyAccountNoActivity,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: transactions.length,
                itemBuilder: (context, index) =>
                    _buildTransactionTile(context, transactions[index]),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, Map<String, dynamic> tx) {
    final type = tx['type'] as int? ?? 0;
    final amount = (tx['amount'] ?? 0).toDouble();
    final description = tx['description'] ?? '';
    final dateStr = tx['createdAt'] ?? '';
    final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr)?.toLocal() : null;

    final (icon, color, label) = switch (type) {
      0 => (
          Icons.arrow_downward,
          const Color(0xFF16A34A),
          context.loc.moneyTransactionIncoming
        ),
      1 => (
          Icons.arrow_upward,
          const Color(0xFFDC2626),
          context.loc.moneyTransactionOutgoing
        ),
      2 => (
          Icons.swap_horiz,
          const Color(0xFF0066FF),
          context.loc.moneyTransactionTransfer
        ),
      _ => (Icons.help_outline, Colors.grey, context.loc.commonOther),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          description.isNotEmpty ? description : label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: date != null
            ? Text(
                DateFormat('dd/MM/yyyy HH:mm').format(date),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              )
            : null,
        trailing: Text(
          '${type == 0 ? '+' : type == 1 ? '-' : ''}${formatMoney(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: type == 0
                ? const Color(0xFF16A34A)
                : type == 1
                    ? const Color(0xFFDC2626)
                    : null,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../pages/record_payment_page.dart';

final _customerDetailFutureProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(customersControllerProvider.notifier).getById(id);
});

final _customerCreditFutureProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, customerId) async {
  return ref.read(customersControllerProvider.notifier).getCredit(customerId);
});

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCustomer = ref.watch(_customerDetailFutureProvider(customerId));
    final asyncCredit = ref.watch(_customerCreditFutureProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.customerDetailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/customers/$customerId/edit'),
          ),
        ],
      ),
      body: WaveBackground(
        child: asyncCustomer.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              Center(child: Text(context.loc.customerDetailNotFound)),
          data: (customer) =>
              _buildContent(context, ref, customer, asyncCredit.value),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> customer, Map<String, dynamic>? credit) {
    final name = customer['name'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF0066FF).withValues(alpha: 0.1),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0066FF),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildCreditCard(context, ref, name, credit),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoTile(Icons.phone, context.loc.settingsPhone,
                      customer['phone'] ?? '-'),
                  const Divider(),
                  _infoTile(Icons.email, context.loc.settingsEmail,
                      customer['email'] ?? '-'),
                  const Divider(),
                  _infoTile(Icons.location_on, context.loc.settingsAddress,
                      customer['address'] ?? '-'),
                  const Divider(),
                  _infoTile(Icons.receipt, context.loc.settingsTIN,
                      customer['tin'] ?? '-'),
                  const Divider(),
                  _infoTile(
                    Icons.verified,
                    context.loc.customerFormVatRegistered,
                    (customer['isVatRegistered'] ?? false)
                        ? context.loc.commonYes
                        : context.loc.commonNo,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.recordNotes,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customer['notes'] ?? context.loc.customerDetailNoNotes,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0066FF)),
      title: Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      subtitle:
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildCreditCard(BuildContext context, WidgetRef ref, String name,
      Map<String, dynamic>? credit) {
    final balance = (credit?['balance'] as num?)?.toDouble() ?? 0.0;
    final limit = (credit?['creditLimit'] as num?)?.toDouble() ?? 0.0;

    if (balance == 0 && limit == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      color: balance > 0 ? const Color(0xFFFDF2F2) : const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.customerDetailDebtTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc.customerDetailDebt,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      'TSh ${balance.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: balance > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.loc.customerDetailLimit,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      'TSh ${limit.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (balance > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordPaymentPage(
                          customerId: customerId,
                          customerName: name,
                          balance: balance,
                        ),
                      ),
                    );
                    if (result == true) {
                      ref.invalidate(_customerCreditFutureProvider(customerId));
                    }
                  },
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text(context.loc.customerDetailPayDebt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

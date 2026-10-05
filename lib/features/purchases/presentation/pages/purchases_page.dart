import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../application/purchases_controller.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchasesControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchasesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.purchasesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/purchases/new'),
          ),
        ],
      ),
      body: WaveBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppSearchBar(
                hintText: context.loc.purchasesSearchHint,
                onChanged: (v) {
                  ref
                      .read(purchasesControllerProvider.notifier)
                      .load(search: v);
                },
              ),
            ),
            Expanded(
              child: _buildBody(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PurchasesState state) {
    if (state is PurchasesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is PurchasesFailure) {
      return Center(child: Text(state.message));
    }
    final loaded = state as PurchasesLoaded;
    if (loaded.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: context.loc.purchasesEmpty,
        message: context.loc.purchasesEmptyMessage,
        actionLabel: context.loc.purchasesAdd,
        onAction: () => context.push('/purchases/new'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(purchasesControllerProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: loaded.items.length,
        itemBuilder: (context, index) {
          final purchase = loaded.items[index];
          return _buildPurchaseTile(purchase);
        },
      ),
    );
  }

  Widget _buildPurchaseTile(Map<String, dynamic> purchase) {
    final ref = purchase['reference'] ?? '';
    final supplierName = purchase['supplierName'] ?? '';
    final total = (purchase['totalAmount'] ?? 0).toDouble();
    final status = purchase['status'] ?? '';
    final dateStr = purchase['orderDate'] ?? '';
    final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'draft':
        statusColor = Colors.grey;
        break;
      case 'submitted':
        statusColor = const Color(0xFFFFA502);
        break;
      case 'received':
        statusColor = const Color(0xFF2ED573);
        break;
      case 'cancelled':
        statusColor = const Color(0xFFFF4757);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.shopping_cart, color: statusColor, size: 20),
        ),
        title: Text(ref.isNotEmpty ? ref : context.loc.purchasesOrderLabel,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplierName.isNotEmpty) Text(supplierName),
            if (date != null)
              Text(
                DateFormat('dd/MM/yyyy').format(date),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatMoney(total),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        onTap: () => context.push('/purchases/${purchase['id']}'),
      ),
    );
  }
}

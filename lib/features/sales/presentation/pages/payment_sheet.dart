import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../core/network/app_exception.dart';
import '../../application/checkout_controller.dart';
import '../../domain/sale.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Payment bottom sheet — clean, focused, no distractions.
Future<void> showPaymentSheet(
  BuildContext context,
  WidgetRef ref, {
  String? customerId,
  String? customerName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentSheet(
      initialCustomerId: customerId,
      initialCustomerName: customerName,
    ),
  );
  if (ref.read(checkoutControllerProvider) is! CheckoutSubmitting) {
    ref.read(checkoutControllerProvider.notifier).reset();
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({this.initialCustomerId, this.initialCustomerName});

  final String? initialCustomerId;
  final String? initialCustomerName;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  int _method = PaymentMethod.cash;
  late final TextEditingController _receivedController;
  double _received = 0;
  String? _customerId;
  String? _customerName;
  late final TextEditingController _initialController;
  double _initialPaid = 0;

  bool get _isCredit => _method == PaymentMethod.credit;

  @override
  void initState() {
    super.initState();
    final total = ref.read(cartControllerProvider).total;
    _received = total;
    _receivedController = TextEditingController(text: _formatAmount(total));
    _initialController = TextEditingController(text: '0');
    // Pre-fill customer from POS app bar selection
    _customerId = widget.initialCustomerId;
    _customerName = widget.initialCustomerName;
    ref.listenManual<CheckoutState>(
      checkoutControllerProvider,
      _onCheckoutStateChanged,
    );
  }

  @override
  void dispose() {
    _receivedController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  void _onCheckoutStateChanged(CheckoutState? previous, CheckoutState next) {
    if (next is CheckoutSuccess && mounted) {
      ref.read(cartControllerProvider.notifier).clear();
      // Reload only the POS-facing data the next sale needs immediately; the
      // history, dashboard, reports and products pages refresh when opened.
      ref.read(stockControllerProvider.notifier).load();
      ref.read(posCatalogControllerProvider.notifier).load();
      Navigator.of(context).pop();
      context.pushReplacement(Routes.posSuccess, extra: next.sale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final submitting = checkout is CheckoutSubmitting;
    final failure = checkout is CheckoutFailure ? checkout.message : null;
    final loc = context.loc;

    final isCash = _method == PaymentMethod.cash;
    final total = cart.total;
    final isTenderedShort = isCash && _received < total;
    final outstanding = isCash
        ? 0.0
        : _isCredit && _initialPaid < total
            ? total - _initialPaid
            : 0.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total
            Text(
              loc.posTotal,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.resolveTextSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(total),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.resolveTextPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Payment method
            Text(
              loc.posPaymentMethod,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.resolveTextPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MethodButton(
                    label: loc.posCash,
                    icon: Icons.payments_outlined,
                    selected: _method == PaymentMethod.cash,
                    onTap: () => setState(() => _method = PaymentMethod.cash),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MethodButton(
                    label: loc.posMobileMoney,
                    icon: Icons.smartphone,
                    selected: _method == PaymentMethod.mobileMoney,
                    onTap: () =>
                        setState(() => _method = PaymentMethod.mobileMoney),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MethodButton(
                    label: loc.posCredit,
                    icon: Icons.account_balance_wallet_outlined,
                    selected: _method == PaymentMethod.credit,
                    onTap: () => setState(() => _method = PaymentMethod.credit),
                  ),
                ),
              ],
            ),

            // Cash received + change (cash only; electronic pays exact total)
            if (isCash) ...[
              const SizedBox(height: 16),
              Text(
                loc.posCashReceived,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _receivedController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9.]'),
                  ),
                ],
                decoration: InputDecoration(
                  hintText: loc.posCashReceivedHint,
                  prefixText: 'TSh ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                onChanged: (_) {
                  final parsed = double.tryParse(
                    _receivedController.text.trim(),
                  );
                  setState(() => _received = parsed ?? 0);
                },
              ),
              const SizedBox(height: 12),
              _ChangeRow(
                total: total,
                received: isTenderedShort ? 0 : _received,
                short: isTenderedShort,
                shortAmount: total - _received,
                loc: loc,
              ),
            ],

            // Credit: customer + initial payment + remaining balance.
            if (_isCredit) ...[
              const SizedBox(height: 16),
              Text(
                loc.posCreditCustomer,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              _CustomerButton(
                label: _customerName ?? loc.posCreditCustomer,
                onTap: _pickCustomer,
              ),
              if (_customerId == null) ...[
                const SizedBox(height: 6),
                Text(
                  loc.posCreditCustomerRequired,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                loc.posCreditReceived,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _initialController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9.]'),
                  ),
                ],
                decoration: InputDecoration(
                  prefixText: 'TSh ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                onChanged: (_) {
                  final parsed = double.tryParse(
                    _initialController.text.trim(),
                  );
                  setState(() => _initialPaid = parsed ?? 0);
                },
              ),
              if (outstanding > 0) ...[
                const SizedBox(height: 12),
                _OutstandingRow(outstanding: outstanding),
              ],
            ],

            if (failure != null) ...[
              const SizedBox(height: 12),
              Text(
                failure,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Pay button
            FilledButton(
              onPressed: submitting ||
                      cart.isEmpty ||
                      (isCash && isTenderedShort) ||
                      (_isCredit && _customerId == null)
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      isCash && _received > total
                          ? '${loc.posPay} · ${loc.posChange} ${_fmt(_received - total)}'
                          : loc.posPay,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final lines = ref.read(cartControllerProvider).lines;
    final tendered = _method == PaymentMethod.cash
        ? _received
        : _method == PaymentMethod.credit
            ? _initialPaid
            : null;
    await ref.read(checkoutControllerProvider.notifier).submit(
          lines: lines,
          paymentMethod: _method,
          amountTendered: tendered,
          customerId: _isCredit ? _customerId : null,
          customerName: _isCredit ? _customerName : null,
        );
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<CustomerPick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked != null && mounted) {
      setState(() {
        _customerId = picked.id;
        _customerName = picked.name;
      });
    }
  }

  static String _fmt(double value) => formatMoney(value);
  static String _formatAmount(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
}

/// Shows change (received − total) when sufficient, or the shortfall (!) red
/// when the cash handed over is less than the total.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.total,
    required this.received,
    required this.short,
    required this.shortAmount,
    required this.loc,
  });

  final double total;
  final double received;
  final bool short;
  final double shortAmount;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    if (short) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${loc.posChangeDue}: ${formatMoney(shortAmount)}',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.receipt_long, size: 18, color: AppColors.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${loc.posChange}: ${formatMoney(received - total)}',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: selected ? AppColors.primaryContainer : null,
        side: BorderSide(
          width: selected ? 2 : 1,
          color: selected ? AppColors.primary : AppColors.outline,
        ),
        foregroundColor: selected
            ? AppColors.primary
            : AppColors.resolveTextSecondary(context),
      ),
    );
  }
}

/// A picked customer (id + display name) returned by the picker sheet.
class CustomerPick {
  const CustomerPick({required this.id, required this.name});

  final String id;
  final String name;
}

/// Opens the customer search sheet and returns the chosen customer.
class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(customerRepositoryProvider)
          .list(search: _searchController.text.trim());
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _addCustomer() async {
    final loc = context.loc;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showDialog<({String name, String? phone})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.posAddCustomer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: loc.posAddCustomerName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: loc.posAddCustomerPhone),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop((
                name: name,
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
              ));
            },
            child: Text(loc.posAddCustomerSave),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      try {
        final created = await ref.read(customerRepositoryProvider).create({
          'name': result.name,
          if (result.phone != null) 'phone': result.phone,
        });
        if (mounted) {
          Navigator.of(context).pop(CustomerPick(
            id: created['id'] as String? ?? '',
            name: result.name,
          ));
        }
      } on AppException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.posCreditCustomer,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.resolveTextPrimary(context),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _addCustomer,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(loc.posAddCustomer),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: loc.posCreditCustomerHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(loc.posCreditNoCustomers),
              )
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final name = item['name'] as String? ?? '';
                    final phone = item['phone'] as String?;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(name),
                      subtitle: phone == null ? null : Text(phone),
                      onTap: () => Navigator.of(context).pop(
                        CustomerPick(
                          id: item['id'] as String? ?? '',
                          name: name,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Selectable customer row in the payment sheet.
class _CustomerButton extends StatelessWidget {
  const _CustomerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.person_search_outlined, size: 20),
      label: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

/// Shows the credit balance a customer will owe after this sale.
class _OutstandingRow extends StatelessWidget {
  const _OutstandingRow({required this.outstanding});

  final double outstanding;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Row(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 18,
          color: AppColors.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${loc.posCreditOutstanding}: ${formatMoney(outstanding)}',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

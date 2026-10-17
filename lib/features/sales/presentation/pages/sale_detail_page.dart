import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../features/authentication/application/auth_controller.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../shared/format/money.dart';
import '../../domain/sale.dart';

/// Sale details: totals, lines and payments, with the receipt one tap away.
/// Loads directly through the repository — a tiny read-only screen.
class SaleDetailPage extends ConsumerStatefulWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  SaleDto? _sale;
  String? _error;
  bool _voiding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sale =
          await ref.read(saleRepositoryProvider).getById(widget.saleId);
      if (mounted) {
        setState(() => _sale = sale);
      }
    } on Exception catch (_) {
      // Offline or not yet synced: serve the provisional local copy.
      final local = await ref
          .read(localSalesServiceProvider)
          .findProvisionalDto(widget.saleId);
      if (mounted) {
        setState(() {
          if (local != null) {
            _sale = local;
          } else {
            _error = context.loc.saleDetailLoadFailed;
          }
        });
      }
    }
  }

  Future<void> _confirmVoid() async {
    final loc = context.loc;
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HardenedVoidDialog(
        saleNumber: _sale?.number ?? '',
      ),
    );
    if (reason == null || !mounted) return;

    setState(() => _voiding = true);
    try {
      final updated = await ref
          .read(saleRepositoryProvider)
          .voidSale(widget.saleId, reason);
      if (mounted) {
        setState(() {
          _sale = updated;
          _voiding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(loc.saleVoided)),
              ],
            ),
          ),
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _voiding = false);
      final message =
          error is AppException ? error.message : loc.saleVoidFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canVoid = auth is AuthAuthenticated &&
        auth.session.user.hasPermission('Sales.Delete');

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.saleDetailTitle)),
      floatingActionButton: _sale == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.receipt),
              label: Text(context.loc.posReceipt),
              onPressed: () => context.push(Routes.receipt(_sale!.id)),
            ),
      body: WaveBackground(
        child: switch ((_sale, _error)) {
          (null, null) => const Center(child: CircularProgressIndicator()),
          (_, final error?) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                      onPressed: _load, child: Text(context.loc.commonRetry)),
                ],
              ),
            ),
          (final sale?, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(sale.number,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(_formatDate(sale.saleDate.toLocal())),
                if (sale.isVoided) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.loc.saleVoided,
                      style: const TextStyle(
                        color: AppColors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Divider(height: 24),
                for (final line in sale.lines)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.productName),
                    subtitle: Text(
                      '${line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 2)} x '
                      '${formatMoney(line.unitPrice)}',
                    ),
                    trailing:
                        Text(formatMoney(line.lineTotal - line.discountAmount)),
                  ),
                const Divider(),
                _SummaryRow(
                    label: context.loc.saleSummarySubtotal,
                    value: sale.subtotal),
                if (sale.taxAmount > 0)
                  _SummaryRow(
                      label: context.loc.saleSummaryTax, value: sale.taxAmount),
                if (sale.discountAmount > 0)
                  _SummaryRow(
                      label: context.loc.saleSummaryDiscount,
                      value: -sale.discountAmount),
                _SummaryRow(
                    label: context.loc.saleSummaryTotal,
                    value: sale.totalAmount,
                    bold: true),
                const Divider(),
                for (final payment in sale.payments)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.payment_outlined),
                    title: Text(payment.label),
                    trailing: Text(formatMoney(payment.amount)),
                  ),
                if (sale.change > 0) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.loc.saleSummaryChange,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          formatMoney(sale.change),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!sale.pendingLocally && !sale.isVoided && canVoid) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _voiding ? null : _confirmVoid,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: Text(
                      _voiding
                          ? context.loc.commonLoading
                          : context.loc.saleVoid,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ],
            ),
        },
      ),
    );
  }

  String _formatDate(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(formatMoney(value), style: style)],
      ),
    );
  }
}

/// Anti-theft hardened void confirmation dialog.
///
/// Enforces manager PIN authorization, mandatory structured reasons with
/// minimum length validation, and clear audit warning before allowing a sale to be voided.
class _HardenedVoidDialog extends ConsumerStatefulWidget {
  const _HardenedVoidDialog({required this.saleNumber});

  final String saleNumber;

  @override
  ConsumerState<_HardenedVoidDialog> createState() =>
      _HardenedVoidDialogState();
}

class _HardenedVoidDialogState extends ConsumerState<_HardenedVoidDialog> {
  final _reasonController = TextEditingController();
  final _pinController = TextEditingController();
  String? _selectedCategory;
  String? _errorMessage;
  bool _verifyingPin = false;

  static const _presetReasons = [
    'Mteja alighairi kabla ya kuchukua bidhaa',
    'Bidhaa au Bei ilikosewa wakati wa mauzo',
    'Muamala ulijirudia kimakosa (Duplicate sale)',
    'Sababu nyingine (toa maelezo kamili chini)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = _presetReasons.first;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _reasonController.text.trim();
    final fullReason = _selectedCategory == _presetReasons.last
        ? note
        : (_selectedCategory ?? 'Sababu');

    final compositeReason = note.isEmpty ? fullReason : '$fullReason - $note';

    if (compositeReason.length < 6) {
      setState(() {
        _errorMessage =
            'Tafadhali andika sababu kamili ya kufuta (angalau herufi 6).';
      });
      return;
    }

    final store = ref.read(offlineCredentialStoreProvider);
    final hasPin = await store.hasUnlockPin();

    if (hasPin) {
      final pin = _pinController.text.trim();
      if (pin.length < 4) {
        setState(() {
          _errorMessage =
              'Ingiza PIN sahihi ya Meneja/Mmiliki (tarakimu 4-6).';
        });
        return;
      }

      setState(() => _verifyingPin = true);
      final ok = await store.verifyUnlockPin(pin);
      if (!mounted) return;
      setState(() => _verifyingPin = false);

      if (!ok) {
        setState(() {
          _errorMessage =
              'PIN ya Meneja si sahihi! Kitendo kimesitishwa kwa usalama.';
        });
        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pop(compositeReason);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Futa Mauzo (${widget.saleNumber})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ TAHADHARI YA KIUSALAMA NA WIZI',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kufuta mauzo haya kutarudisha idadi ya bidhaa stoo na kupunguza hesabu ya fedha za leo. Tukio hili litaripotiwa moja kwa moja kwa simu ya Mmiliki.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chagua Sababu ya Kufuta:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _presetReasons
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Maelezo ya ziada (Maelezo ya tukio)*',
                hintText:
                    'Mfano: Mteja amebadili mawazo mara moja kabla ya kuondoka...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Idhini ya Meneja / Mmiliki:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                labelText: 'Ingiza PIN ya Meneja (Quick PIN)',
                hintText: '****',
                counterText: '',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ghairi (Cancel)'),
        ),
        FilledButton.icon(
          onPressed: _verifyingPin ? null : _submit,
          icon: _verifyingPin
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.delete_forever, size: 18),
          label: const Text('Thibitisha Kufuta (Void)'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
        ),
      ],
    );
  }
}

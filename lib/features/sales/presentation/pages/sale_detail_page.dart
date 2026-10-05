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
      builder: (context) => _VoidReasonDialog(
        title: loc.saleVoidConfirmTitle,
        message: loc.saleVoidConfirmMessage,
        reasonHint: loc.saleVoidReasonHint,
        reasonRequired: loc.saleVoidReasonRequired,
        confirmLabel: loc.saleVoid,
        cancelLabel: loc.commonCancel,
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
          SnackBar(content: Text(loc.saleVoided)),
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

/// Asks for a void reason and returns it, or null when cancelled.
class _VoidReasonDialog extends StatefulWidget {
  const _VoidReasonDialog({
    required this.title,
    required this.message,
    required this.reasonHint,
    required this.reasonRequired,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String reasonHint;
  final String reasonRequired;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_VoidReasonDialog> createState() => _VoidReasonDialogState();
}

class _VoidReasonDialogState extends State<_VoidReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = widget.reasonRequired);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: widget.reasonHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              errorText: _error,
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

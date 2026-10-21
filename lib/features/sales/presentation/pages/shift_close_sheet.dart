import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../data/offline_shift_register_service.dart';
import '../../data/sales_providers.dart';

/// Opens the Shift Close and Thermal Z-Report bottom sheet.
Future<void> showShiftCloseSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ShiftCloseSheet(),
  );
}

class _ShiftCloseSheet extends ConsumerStatefulWidget {
  const _ShiftCloseSheet();

  @override
  ConsumerState<_ShiftCloseSheet> createState() => _ShiftCloseSheetState();
}

class _ShiftCloseSheetState extends ConsumerState<_ShiftCloseSheet> {
  final _countedCashController = TextEditingController();
  final _openingCashController = TextEditingController(text: '0');

  ShiftSummary? _summary;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _countedCashController.dispose();
    _openingCashController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    try {
      final register = ref.read(offlineShiftRegisterServiceProvider);
      final opening = double.tryParse(_openingCashController.text.trim()) ?? 0;
      final counted = double.tryParse(_countedCashController.text.trim());
      final res = await register.computeShiftSummary(
        openingCash: opening,
        countedCash: counted,
      );
      if (mounted) {
        setState(() {
          _summary = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCashChanged(String _) {
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              : summary == null
                  ? const Center(
                      child: Text('Imeshindwa kukokotoa hesabu ya siku.'),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFE8F5E9),
                                child: Icon(Icons.point_of_sale,
                                    size: 20, color: Color(0xFF2E7D32)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kufunga Hesabu ya Siku',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Ripoti ya Z-Hesabu (Inafanya kazi Nje ya Mtandao)',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // ── Summary Cards ─────────────────────────
                          _CardSection(
                            title: 'Mauzo ya Leo (${summary.saleCount})',
                            icon: Icons.receipt_long,
                            children: [
                              _MetricRow(
                                label: 'Pesa Taslimu (Cash):',
                                value: formatMoney(summary.cashSales),
                              ),
                              _MetricRow(
                                label: 'Simu / Benki:',
                                value: formatMoney(summary.electronicSales),
                              ),
                              _MetricRow(
                                label: 'Mauzo ya Mkopo:',
                                value: formatMoney(summary.creditSales),
                              ),
                              const Divider(height: 12),
                              _MetricRow(
                                label: 'JUMLA YA MAUZO:',
                                value: formatMoney(summary.totalSales),
                                isBold: true,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          _CardSection(
                            title: 'Mwenendo wa Pesa Drooni (Till)',
                            icon: Icons.account_balance_wallet_outlined,
                            children: [
                              _MetricRow(
                                label: 'Mtaji wa Kuanzia:',
                                value: formatMoney(summary.openingCash),
                              ),
                              _MetricRow(
                                label: '+ Mauzo ya Taslimu:',
                                value: formatMoney(summary.cashSales),
                                color: const Color(0xFF2E7D32),
                              ),
                              _MetricRow(
                                label: '+ Malipo ya Madeni:',
                                value: formatMoney(summary.debtCashCollected),
                                color: const Color(0xFF2E7D32),
                              ),
                              _MetricRow(
                                label: '- Matumizi ya Dukani:',
                                value: formatMoney(summary.cashExpenses),
                                color: theme.colorScheme.error,
                              ),
                              const Divider(height: 12),
                              _MetricRow(
                                label: 'PESA INAYOTARAJIWA DROONI:',
                                value: formatMoney(summary.expectedCash),
                                isBold: true,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Cash Count Input ──────────────────────
                          Text(
                            'Pesa Zilizopo Drooni Mkononi (Counted Cash):',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _countedCashController,
                            keyboardType: TextInputType.number,
                            onChanged: _onCashChanged,
                            decoration: InputDecoration(
                              hintText: 'Ingiza pesa uliyoihesabu...',
                              prefixText: 'TZS  ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              isDense: true,
                            ),
                          ),

                          if (summary.countedCash != null &&
                              summary.variance != null) ...[
                            const SizedBox(height: 10),
                            _VarianceBadge(variance: summary.variance!),
                          ],

                          const SizedBox(height: 20),

                          // ── Action Buttons ────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.print_outlined),
                                  label: const Text('Z-Report'),
                                  onPressed: () => _showZReportPreview(summary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle),
                                  label: const Text('Funga Hesabu'),
                                  onPressed: _saving ? null : _saveShift,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  void _showZReportPreview(ShiftSummary summary) {
    final register = ref.read(offlineShiftRegisterServiceProvider);
    final reportText = register.generateZReportText(summary);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripoti ya Z-Hesabu (Thermal)'),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              reportText,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Nakili'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportText));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Ripoti imenakiliwa!')),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Tuma WhatsApp'),
            onPressed: () {
              SharePlus.instance.share(reportText, subject: 'Z-Report Hesabu ya Leo');
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Funga'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveShift() async {
    final summary = _summary;
    if (summary == null) return;
    setState(() => _saving = true);

    try {
      final register = ref.read(offlineShiftRegisterServiceProvider);
      await register.saveShiftClose(summary);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hesabu ya siku imefungwa na kuhifadhiwa kikamilifu!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hitilafu: $e')),
        );
      }
    }
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _VarianceBadge extends StatelessWidget {
  const _VarianceBadge({required this.variance});

  final double variance;

  @override
  Widget build(BuildContext context) {
    final isExact = variance.abs() < 1;
    final isSurplus = variance > 0;

    final bgColor = isExact
        ? const Color(0xFFE8F5E9)
        : (isSurplus ? const Color(0xFFE3F2FD) : const Color(0xFFFFEBEE));
    final textColor = isExact
        ? const Color(0xFF2E7D32)
        : (isSurplus ? const Color(0xFF1565C0) : const Color(0xFFC62828));
    final icon = isExact
        ? Icons.check_circle_outline
        : (isSurplus ? Icons.trending_up : Icons.trending_down);
    final text = isExact
        ? 'Hesabu imelingana sawa sawa (Tofauti: TSh 0)'
        : (isSurplus
            ? 'Ziada ya Pesa Drooni: +${formatMoney(variance)}'
            : 'Upungufu wa Pesa Drooni: -${formatMoney(variance.abs())}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

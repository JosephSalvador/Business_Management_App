import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/barcode/hardware_scanner_listener.dart';
import '../../../../core/barcode/mobile_barcode_scanner_modal.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/stock_controller.dart';
import '../widgets/digital_stockroom_sheet.dart';

/// The Stock tab: on-hand quantity per product with digital stockroom locator,
/// barcode scanning, and multi-branch inspection.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(stockControllerProvider.notifier).load(),
    );
  }

  Future<void> _handleStockBarcodeScan(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return;

    final auth = ref.read(authControllerProvider);
    final tenantId = auth.maybeWhen(
      authenticated: (s) => s.tenant.id,
      orElse: () => '',
    );
    if (tenantId.isEmpty) return;

    final dao = ref.read(localSalesServiceProvider).catalog;
    final product = await dao.byBarcodeOrSku(tenantId, clean);

    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.barcodeNotFound(clean)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    HapticFeedback.mediumImpact();
    if (mounted) {
      showDigitalStockroomSheet(context, productId: product.productId);
    }
  }

  Future<void> _scanToInspectStock() async {
    final code = await showMobileBarcodeScanner(context);
    if (code != null && code.isNotEmpty) {
      _handleStockBarcodeScan(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockControllerProvider);
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.stockPageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: loc.barcodeDigitalStockroomTitle,
            onPressed: _scanToInspectStock,
          ),
        ],
      ),
      body: HardwareScannerListener(
        onBarcodeScanned: _handleStockBarcodeScan,
        child: WaveBackground(
          child: switch (state) {
            StockLoading() => const Center(child: CircularProgressIndicator()),
            StockFailure(:final message) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          ref.read(stockControllerProvider.notifier).load(),
                      child: Text(loc.stockPageRetry),
                    ),
                  ],
                ),
              ),
            StockEmpty() => Center(
                child: Text(loc.stockPageEmpty),
              ),
            StockReady() => RefreshIndicator(
                onRefresh: () =>
                    ref.read(stockControllerProvider.notifier).load(),
                child: ListView.separated(
                  itemCount: state.rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = state.rows[index];
                    final isLow = line.quantity <= 5 && line.quantity > 0;
                    final isOut = line.quantity <= 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      onTap: () {
                        showDigitalStockroomSheet(context,
                            productId: line.productId);
                      },
                      leading: CircleAvatar(
                        backgroundColor: isOut
                            ? Colors.red.shade100
                            : (isLow
                                ? Colors.amber.shade100
                                : Colors.green.shade100),
                        child: Icon(
                          isOut
                              ? Icons.warning_amber
                              : (isLow
                                  ? Icons.inventory_2_outlined
                                  : Icons.check_circle_outline),
                          color: isOut
                              ? Colors.red.shade800
                              : (isLow
                                  ? Colors.amber.shade900
                                  : Colors.green.shade800),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        line.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Row(
                        children: [
                          Text(line.warehouseName),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.resolveSurfaceSecondary(context),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.resolveBorder(context)),
                            ),
                            child: Text(
                              loc.barcodeLocation,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.resolveTextSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _format(line.quantity),
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isOut
                                          ? Colors.red.shade800
                                          : (isLow
                                              ? Colors.amber.shade900
                                              : Colors.black87),
                                    ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                    );
                  },
                ),
              ),
          },
        ),
      ),
    );
  }

  static String _format(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/locale_store.dart';
import '../../../../core/storage/printer_store.dart';
import '../../../../core/storage/receipt_customization_store.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../receipts/data/receipt_providers.dart';
import '../../../receipts/domain/receipt_customization.dart';
import '../../../receipts/domain/receipt_format.dart';
import '../../../receipts/domain/receipt_preview.dart';
import '../../../receipts/domain/receipt_renderer.dart';
import '../../../receipts/presentation/widgets/receipt_ticket_card.dart';
import '../../../sales/data/receipt_printer_service.dart';
import '../../../workspaces/application/workspace_controller.dart';

class ReceiptSettingsPage extends ConsumerStatefulWidget {
  const ReceiptSettingsPage({super.key});

  @override
  ConsumerState<ReceiptSettingsPage> createState() =>
      _ReceiptSettingsPageState();
}

class _ReceiptSettingsPageState extends ConsumerState<ReceiptSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _taglineController;
  late final TextEditingController _thanksController;
  late final TextEditingController _policyController;
  late final TextEditingController _contactController;

  late bool _showTin;
  late bool _showCashier;
  late bool _showCustomer;

  bool _isSaving = false;
  bool _isPrinting = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final initial = ref.read(receiptCustomizationProvider);
    _taglineController =
        TextEditingController(text: initial.headerTagline ?? '');
    _thanksController =
        TextEditingController(text: initial.footerThanks ?? '');
    _policyController =
        TextEditingController(text: initial.footerPolicy ?? '');
    _contactController =
        TextEditingController(text: initial.footerContact ?? '');

    _showTin = initial.showTin;
    _showCashier = initial.showCashier;
    _showCustomer = initial.showCustomer;

    _taglineController.addListener(() => setState(() {}));
    _thanksController.addListener(() => setState(() {}));
    _policyController.addListener(() => setState(() {}));
    _contactController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taglineController.dispose();
    _thanksController.dispose();
    _policyController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  ReceiptCustomization get _currentCustomization => ReceiptCustomization(
        headerTagline: _taglineController.text.trim().isEmpty
            ? null
            : _taglineController.text.trim(),
        showTin: _showTin,
        showCashier: _showCashier,
        showCustomer: _showCustomer,
        footerThanks: _thanksController.text.trim().isEmpty
            ? null
            : _thanksController.text.trim(),
        footerPolicy: _policyController.text.trim().isEmpty
            ? null
            : _policyController.text.trim(),
        footerContact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
      );

  String get _businessName {
    final workspace = ref.read(workspaceControllerProvider);
    return workspace is WorkspaceReady && workspace.selected != null
        ? workspace.selected!.name
        : 'Biashara Yangu / My Business';
  }

  ReceiptPreview _buildSampleReceipt() {
    return ReceiptPreview(
      saleId: 'sample-001',
      saleNumber: 'REC-2026-0042',
      saleDate: DateTime.now(),
      isVoided: false,
      hasMetadata: false,
      isReprint: false,
      printCount: 0,
      businessName: _businessName,
      tin: '123-456-789',
      address: 'Kariakoo, Msimbazi St, Dar es Salaam',
      phone: '+255 712 345 678',
      branchName: 'Tawi Kuu / Main Branch',
      cashierName: 'Amina Juma',
      customerName: 'Juma Mwamba',
      currency: 'TZS',
      qrPayload: 'sample-jolinx-receipt-verification-payload',
      lines: const [
        ReceiptLine(
          productName: 'Mchele Safi Super (5kg)',
          quantity: 2,
          unitPrice: 15000,
          discountAmount: 0,
          taxCode: 'A',
          taxAmount: 0,
          lineTotal: 30000,
        ),
        ReceiptLine(
          productName: 'Mafuta ya Kupikia Korie (1L)',
          quantity: 1,
          unitPrice: 7500,
          discountAmount: 0,
          taxCode: 'A',
          taxAmount: 0,
          lineTotal: 7500,
        ),
        ReceiptLine(
          productName: 'Sabuni ya Unga Omo 500g',
          quantity: 3,
          unitPrice: 2500,
          discountAmount: 0,
          taxCode: 'A',
          taxAmount: 0,
          lineTotal: 7500,
        ),
      ],
      payments: const [
        ReceiptPayment(method: 'CASH', amount: 45000),
      ],
      subtotal: 45000,
      taxAmount: 0,
      discountAmount: 0,
      totalAmount: 45000,
      amountPaid: 45000,
      change: 0,
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(receiptCustomizationProvider.notifier)
          .update(_currentCustomization);
      if (mounted) {
        final isSwahili =
            Localizations.localeOf(context).languageCode == 'sw';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              isSwahili
                  ? 'Mipangilio ya risiti imehifadhiwa kikamilifu.'
                  : 'Receipt settings saved successfully.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetToDefault() {
    final def = ReceiptCustomization.defaultConfiguration;
    setState(() {
      _taglineController.text = def.headerTagline ?? '';
      _thanksController.text = def.footerThanks ?? '';
      _policyController.text = def.footerPolicy ?? '';
      _contactController.text = def.footerContact ?? '';
      _showTin = def.showTin;
      _showCashier = def.showCashier;
      _showCustomer = def.showCustomer;
    });
  }

  Future<void> _printTestSlip() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    final isSwahili = Localizations.localeOf(context).languageCode == 'sw';
    final sample = _buildSampleReceipt();
    final custom = _currentCustomization;

    try {
      // 1. Android Native Bluetooth SPP
      if (!kIsWeb && Platform.isAndroid) {
        final printerController =
            ref.read(printerControllerProvider.notifier);
        final printerState = ref.read(printerControllerProvider);
        var address = printerState.address;

        if (address == null) {
          final device =
              await FlutterBluetoothPrinter.selectDevice(context);
          if (!mounted || device == null) return;
          address = device.address;
          await printerController.selectPrinter(
            device.address,
            device.name ?? 'Printer',
          );
          if (!mounted) return;
        }

        final locale = ref.read(localeControllerProvider);
        final paperWidth = ref.read(receiptPaperWidthProvider);
        final service = ReceiptPrinterService(
          language: receiptLanguageForCode(locale.languageCode),
          paperWidth: paperWidth,
          customization: custom,
        );

        final ok = await service.printToDevice(
          address: address,
          receipt: sample,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? (isSwahili
                        ? 'Sampuli imechapishwa kikamilifu!'
                        : 'Test receipt printed successfully!')
                    : (isSwahili
                        ? 'Hitilafu ya kuchapa sampuli.'
                        : 'Failed to print test receipt.'),
              ),
            ),
          );
        }
        return;
      }

      // 2. Web Bluetooth or Browser Print
      final printerService = ref.read(receiptPrinterServiceProvider);
      if (kIsWeb && printerService.hasWebBluetooth) {
        final ok = await printerService.printViaWebBluetooth(receipt: sample);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? (isSwahili
                        ? 'Sampuli imechapishwa!'
                        : 'Test receipt printed!')
                    : (isSwahili
                        ? 'Hitilafu ya kuchapa.'
                        : 'Failed to print test receipt.'),
              ),
            ),
          );
        }
        return;
      }

      // 3. Browser Print Fallback
      if (printerService.hasBrowserPrinting) {
        await printerService.printViaBrowser(receipt: sample);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSwahili
                  ? 'Kifaa hiki hakiwezi kuchapa moja kwa moja.'
                  : 'Direct printing is not supported on this device.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSwahili = Localizations.localeOf(context).languageCode == 'sw';
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSwahili ? 'Muundo wa Risiti' : 'Receipt Header & Footer',
        ),
        actions: [
          IconButton(
            tooltip: isSwahili ? 'Rejesha ya Awali' : 'Reset to Default',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetToDefault,
          ),
        ],
        bottom: isWide
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.edit_note, size: 20),
                    text: isSwahili ? 'Mipangilio' : 'Settings',
                  ),
                  Tab(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    text: isSwahili ? 'Muonekano (Live)' : 'Live Preview',
                  ),
                ],
              ),
      ),
      body: WaveBackground(
        child: isWide
            ? _buildWideLayout(context, isSwahili)
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildFormView(context, isSwahili),
                  _buildPreviewView(context, isSwahili),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPrinting ? null : _printTestSlip,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print, size: 18),
                  label: Text(
                    isSwahili ? 'Chapa Sampuli' : 'Print Test Slip',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(
                    isSwahili ? 'Hifadhi Mipangilio' : 'Save Settings',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, bool isSwahili) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildFormView(context, isSwahili),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: _buildPreviewView(context, isSwahili),
        ),
      ],
    );
  }

  Widget _buildFormView(BuildContext context, bool isSwahili) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section: Header
        _FormSection(
          title: isSwahili ? 'SEHEMU YA JUU (HEADER)' : 'HEADER SECTION',
          children: [
            TextField(
              controller: _taglineController,
              decoration: InputDecoration(
                labelText: isSwahili
                    ? 'Kaulimbiu / Ujumbe wa Juu'
                    : 'Header Tagline / Slogan',
                hintText: isSwahili
                    ? 'mf. Karibu Tukuhudumie / Quality Groceries'
                    : 'e.g. Quality Goods & Fast Delivery',
                prefixIcon: const Icon(Icons.subtitles_outlined),
                helperText: isSwahili
                    ? 'Huonekana chini ya jina la biashara'
                    : 'Appears directly below your business name',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              title: Text(
                isSwahili ? 'Onyesha Namba ya TIN' : 'Show TIN Number',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                isSwahili
                    ? 'Ikiwashwa, TIN ya duka itaandikwa kwenye risiti'
                    : 'Print business TIN if configured',
                style: const TextStyle(fontSize: 12),
              ),
              value: _showTin,
              onChanged: (val) => setState(() => _showTin = val),
            ),
            SwitchListTile.adaptive(
              title: Text(
                isSwahili
                    ? 'Onyesha Jina la Mhudumu (Cashier)'
                    : 'Show Cashier Name',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                isSwahili
                    ? 'Onyesha jina la aliyefanya mauzo'
                    : 'Display the cashier who completed the sale',
                style: const TextStyle(fontSize: 12),
              ),
              value: _showCashier,
              onChanged: (val) => setState(() => _showCashier = val),
            ),
            SwitchListTile.adaptive(
              title: Text(
                isSwahili
                    ? 'Onyesha Jina la Mteja (Customer)'
                    : 'Show Customer Name',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                isSwahili
                    ? 'Onyesha jina la mteja iwapo alirekodiwa'
                    : 'Display customer name when selected',
                style: const TextStyle(fontSize: 12),
              ),
              value: _showCustomer,
              onChanged: (val) => setState(() => _showCustomer = val),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Section: Footer
        _FormSection(
          title: isSwahili ? 'SEHEMU YA CHINI (FOOTER)' : 'FOOTER SECTION',
          children: [
            TextField(
              controller: _thanksController,
              decoration: InputDecoration(
                labelText: isSwahili
                    ? 'Ujumbe wa Shukrani'
                    : 'Thank-You Message',
                hintText: isSwahili
                    ? 'mf. Asante kwa kufanya biashara nasi!'
                    : 'e.g. Thank you for shopping with us!',
                prefixIcon: const Icon(Icons.favorite_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _policyController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isSwahili
                    ? 'Sera ya Kurudisha / Warranty'
                    : 'Return Policy / Warranty',
                hintText: isSwahili
                    ? 'mf. Bidhaa zilizouzwa hazirudishwi.'
                    : 'e.g. Goods once sold will not be accepted back.',
                prefixIcon: const Icon(Icons.policy_outlined),
                helperText: isSwahili
                    ? 'Mistari mirefu itagawanywa kiotomatiki'
                    : 'Long text wraps nicely on 58mm & 80mm',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: isSwahili
                    ? 'Mawasiliano ya Ziada au Lipa Namba'
                    : 'Additional Contact or Till / Paybill',
                hintText: isSwahili
                    ? 'mf. Lipa Namba: 5544332 | Simu: 0712 000 111'
                    : 'e.g. Till: 5544332 | Help: 0712 000 111',
                prefixIcon: const Icon(Icons.contact_phone_outlined),
                helperText: isSwahili
                    ? 'Hiari: Inakaa chini kabisa kabla ya nembo ya mfumo'
                    : 'Optional: Appears above the powered-by line',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPreviewView(BuildContext context, bool isSwahili) {
    final sample = _buildSampleReceipt();
    final custom = _currentCustomization;
    final paperWidth = ref.watch(receiptPaperWidthProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isSwahili ? 'Upana wa Karatasi: ' : 'Paper Width: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              SegmentedButton<ReceiptPaperWidth>(
                segments: const [
                  ButtonSegment(
                    value: ReceiptPaperWidth.mm80,
                    label: Text('80 mm'),
                    icon: Icon(Icons.receipt_long, size: 16),
                  ),
                  ButtonSegment(
                    value: ReceiptPaperWidth.mm58,
                    label: Text('58 mm'),
                    icon: Icon(Icons.receipt, size: 16),
                  ),
                ],
                selected: {paperWidth},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    ref
                        .read(receiptPaperWidthProvider.notifier)
                        .setWidth(set.first);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: ReceiptTicketCard(
              receipt: sample,
              isReprint: false,
              customization: custom,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.resolveTextSecondary(context),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

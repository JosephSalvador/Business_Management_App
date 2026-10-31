import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/document_template_controller.dart';
import '../../domain/document_template.dart';
import '../widgets/color_hex_picker.dart';
import '../widgets/preview_frame/preview_frame.dart';
import '../widgets/print_document_button.dart';
import '../widgets/template_marketplace_grid.dart';

class DocumentTemplatesPage extends ConsumerStatefulWidget {
  const DocumentTemplatesPage({super.key});

  @override
  ConsumerState<DocumentTemplatesPage> createState() =>
      _DocumentTemplatesPageState();
}

class _DocumentTemplatesPageState extends ConsumerState<DocumentTemplatesPage>
    with SingleTickerProviderStateMixin {
  late TabController _mobileTabController;
  final TextEditingController _customLiquidController = TextEditingController();
  final TextEditingController _footerNotesController = TextEditingController();
  bool _showCustomEditor = false;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(documentTemplateControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    _customLiquidController.dispose();
    _footerNotesController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF0F172A);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentTemplateControllerProvider);
    final notifier = ref.read(documentTemplateControllerProvider.notifier);
    final isSw = Localizations.localeOf(context).languageCode == 'sw';

    // Synchronize text fields if updated from state
    if (_customLiquidController.text != state.customLiquidOverride &&
        !_showCustomEditor) {
      _customLiquidController.text = state.customLiquidOverride;
    }
    if (_footerNotesController.text != state.footerNotes) {
      _footerNotesController.text = state.footerNotes;
    }

    final isWide = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSw
              ? 'Violezo vya Ankara na Delivery'
              : 'Invoice & Delivery Templates',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (state.saveSuccess)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.check_circle,
                    size: 16, color: Colors.green),
                label: Text(
                  isSw ? 'Imehifadhiwa' : 'Saved',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                backgroundColor: const Color(0xFFF0FDF4),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: state.isSaving
                  ? null
                  : () async {
                      final success = await notifier.saveConfiguration();
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isSw
                                  ? 'Mipangilio ya kiolezo imehifadhiwa kikamilifu!'
                                  : 'Document template settings saved successfully!',
                            ),
                            backgroundColor: const Color(0xFF0D9488),
                          ),
                        );
                      }
                    },
              icon: state.isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(
                state.isSaving
                    ? (isSw ? 'Inahifadhi...' : 'Saving...')
                    : (isSw ? 'Hifadhi' : 'Save'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        bottom: isWide
            ? null
            : TabBar(
                controller: _mobileTabController,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    text: isSw ? 'Mipangilio' : 'Settings',
                  ),
                  Tab(
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                    text: isSw ? 'Hakiki Moja kwa Moja' : 'Live Preview',
                  ),
                ],
              ),
      ),
      body: WaveBackground(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : isWide
                ? _buildSplitScreen(context, state, notifier, isSw)
                : TabBarView(
                    controller: _mobileTabController,
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildConfigSide(
                            context, state, notifier, isSw, false),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildPreviewSide(context, state, isSw),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSplitScreen(
    BuildContext context,
    DocumentTemplateState state,
    DocumentTemplateController notifier,
    bool isSw,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Template Selection, Colors & Configurations
        SizedBox(
          width: 480,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildConfigSide(context, state, notifier, isSw, true),
            ),
          ),
        ),

        // Right Column: Isolated Real-time Preview & Cashier Print
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: _buildPreviewSide(context, state, isSw),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigSide(
    BuildContext context,
    DocumentTemplateState state,
    DocumentTemplateController notifier,
    bool isSw,
    bool isWide,
  ) {
    final primaryColor = _parseColor(state.themePrimaryHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Document Type Segmented Toggle (Invoice vs Delivery Note)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SegmentTabButton(
                  icon: Icons.receipt_long_outlined,
                  label: isSw ? 'Ankara (Invoice)' : 'Customer Invoice',
                  isSelected:
                      state.selectedDocumentType == DocumentType.invoice,
                  onTap: () =>
                      notifier.switchDocumentType(DocumentType.invoice),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SegmentTabButton(
                  icon: Icons.local_shipping_outlined,
                  label:
                      isSw ? 'Kukabidhi (Delivery)' : 'Delivery Note',
                  isSelected:
                      state.selectedDocumentType == DocumentType.deliveryNote,
                  onTap: () =>
                      notifier.switchDocumentType(DocumentType.deliveryNote),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Marketplace Templates Grid Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isSw ? 'Violezo Vilivyopo' : 'Marketplace Templates',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '${state.currentTypeTemplates.length} ${isSw ? 'violezo' : 'layouts'}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Marketplace Grid
        TemplateMarketplaceGrid(
          templates: state.currentTypeTemplates,
          selectedTemplateId: state.activeTemplateId,
          primaryColor: primaryColor,
          onTemplateSelected: (summary) =>
              notifier.selectTemplate(summary.id),
        ),
        const SizedBox(height: 24),

        // Branding & Colors Section
        _SectionCard(
          title: isSw ? 'Rangi za Chapa' : 'Branding Colors',
          icon: Icons.palette_outlined,
          child: Column(
            children: [
              ColorHexPicker(
                label: isSw ? 'Rangi Kuu (Primary)' : 'Primary Theme Color',
                subtitle: isSw
                    ? 'Inatumika kwenye vichwa, jedwali na mihuri'
                    : 'Headers, table bars, and primary badges',
                selectedHex: state.themePrimaryHex,
                onColorChanged: notifier.updatePrimaryHex,
              ),
              const Divider(height: 28),
              ColorHexPicker(
                label:
                    isSw ? 'Rangi ya Pili (Secondary)' : 'Secondary Accent Color',
                subtitle: isSw
                    ? 'Inatumika kwenye viashiria na mistari'
                    : 'Accents, dividers, and highlight badges',
                selectedHex: state.themeSecondaryHex,
                onColorChanged: notifier.updateSecondaryHex,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Options: Logo & Footer
        _SectionCard(
          title: isSw ? 'Chaguzi za Hati' : 'Document Options',
          icon: Icons.tune_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: state.showLogo,
                onChanged: notifier.updateShowLogo,
                title: Text(
                  isSw ? 'Onyesha Nembo ya Biashara' : 'Show Business Logo',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  isSw
                      ? 'Huonyesha nembo iliyopakiwa kwenye mpangilio'
                      : 'Display organization logo at top of document',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                activeColor: const Color(0xFF0D9488),
              ),
              const Divider(height: 20),
              Text(
                isSw
                    ? 'Maelezo ya Chini (Footer Notes / Terms)'
                    : 'Footer Notes / Terms',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _footerNotesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: isSw
                      ? 'Mfano: Asante kwa kufanya biashara nasi. Bidhaa havirudishwi baada ya siku 3.'
                      : 'E.g. Thank you for your business. Payment due in 14 days.',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: notifier.updateFooterNotes,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Custom Liquid Override Accordion
        _SectionCard(
          title: isSw ? 'Badilisha Liquid / HTML' : 'Custom Liquid Layout',
          icon: Icons.code_outlined,
          trailing: IconButton(
            icon: Icon(
              _showCustomEditor
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: const Color(0xFF64748B),
            ),
            onPressed: () {
              setState(() => _showCustomEditor = !_showCustomEditor);
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw
                    ? 'Unaweza kuandika kodi maalum ya Liquid/HTML kuboresha muundo. Mfumo husafisha kodi zote zenye hatari.'
                    : 'Enter custom Liquid/HTML tokens. Dangerous script and iframe tags will be automatically sanitized.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              if (_showCustomEditor) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customLiquidController,
                  maxLines: 10,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        '<div class="invoice-box">\n  <h1>{{ invoice.number }}</h1>\n</div>',
                    hintStyle: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  cursorColor: const Color(0xFF38BDF8),
                  onChanged: notifier.updateCustomLiquid,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _customLiquidController.clear();
                        notifier.updateCustomLiquid('');
                      },
                      icon: const Icon(Icons.restart_alt, size: 14),
                      label: Text(
                        isSw ? 'Rejesha Chaguo-Msingi' : 'Reset to Default',
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPreviewSide(
    BuildContext context,
    DocumentTemplateState state,
    bool isSw,
  ) {
    final isThermal = state.isThermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar inside Preview Area
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isThermal
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isThermal ? Icons.receipt_long : Icons.article_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isThermal
                            ? 'POS Tape (80mm Thermal)'
                            : (state.selectedDocumentType ==
                                    DocumentType.invoice
                                ? 'Ankara A4 Standard'
                                : 'Hati ya Delivery A4'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isPreviewLoading) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSw ? 'Inahuisha...' : 'Compiling...',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
            // Cashier One-Click Print Component
            PrintDocumentButton(
              htmlContent: state.previewHtml,
              isThermal: isThermal,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live isolated <iframe> / Embedded preview view
        Expanded(
          child: documentPreviewFrame.buildFrame(
            context: context,
            htmlContent: state.previewHtml,
            isThermal: isThermal,
            isLoading: state.isPreviewLoading,
          ),
        ),
      ],
    );
  }
}

class _SegmentTabButton extends StatelessWidget {
  const _SegmentTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

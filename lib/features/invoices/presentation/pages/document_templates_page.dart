import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/responsive_layout_builder.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/document_template_controller.dart';
import '../../domain/document_template.dart';
import '../widgets/commercial_palette_picker.dart';
import '../widgets/custom_override_field.dart';
import '../widgets/document_selector_toggle.dart';
import '../widgets/preview_frame/preview_frame.dart';
import '../widgets/print_profile_selector.dart';
import '../widgets/template_marketplace_grid.dart';
import '../widgets/uniform_command_bar.dart';

class DocumentTemplatesPage extends ConsumerStatefulWidget {
  const DocumentTemplatesPage({super.key});

  @override
  ConsumerState<DocumentTemplatesPage> createState() =>
      _DocumentTemplatesPageState();
}

class _DocumentTemplatesPageState extends ConsumerState<DocumentTemplatesPage>
    with SingleTickerProviderStateMixin {
  late TabController _phoneTabController;
  final TextEditingController _footerNotesController = TextEditingController();
  bool _isPrinting = false;
  bool _tabletSheetCollapsed = true;

  @override
  void initState() {
    super.initState();
    _phoneTabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(documentTemplateControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _phoneTabController.dispose();
    _footerNotesController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return AppColors.primary;
  }

  Future<void> _handlePrintNow(DocumentTemplateState state) async {
    if (_isPrinting || state.previewHtml == null) return;
    setState(() => _isPrinting = true);
    try {
      await documentPreviewFrame.printDocument(state.previewHtml);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleSaveConfiguration(
      DocumentTemplateController notifier, bool isSw) async {
    final success = await notifier.saveConfiguration();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSw
                ? 'Mipangilio ya kiolezo imehifadhiwa kikamilifu!'
                : 'Template configuration successfully saved!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentTemplateControllerProvider);
    final notifier = ref.read(documentTemplateControllerProvider.notifier);
    final isSw = Localizations.localeOf(context).languageCode == 'sw';

    if (_footerNotesController.text != state.footerNotes) {
      _footerNotesController.text = state.footerNotes;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSw
              ? 'Mipangilio ya Violezo na Printa'
              : 'Invoice & Delivery Templates',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isSw ? 'Pakia upya' : 'Refresh',
            onPressed: state.isLoading ? null : notifier.load,
          ),
        ],
      ),
      body: WaveBackground(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveLayoutBuilder(
                builder: (context, constraints, category) {
                  switch (category) {
                    case EnterpriseScreenCategory.phone:
                      return _buildPhoneLayout(
                          context, state, notifier, isSw);
                    case EnterpriseScreenCategory.tablet:
                      return _buildTabletLayout(
                          context, state, notifier, isSw, constraints);
                    case EnterpriseScreenCategory.desktop:
                      return _buildDesktopLayout(
                          context, state, notifier, isSw, constraints);
                  }
                },
              ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. SMALL SCREENS (Phones, < 768px): Single pane with top TabBar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPhoneLayout(
    BuildContext context,
    DocumentTemplateState state,
    DocumentTemplateController notifier,
    bool isSw,
  ) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _phoneTabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                icon: const Icon(Icons.tune_outlined, size: 18),
                text: isSw ? 'Mipangilio' : 'Configuration',
              ),
              Tab(
                icon: const Icon(Icons.preview_outlined, size: 18),
                text: isSw ? 'Hakiki (Live Canvas)' : 'Preview Canvas',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _phoneTabController,
            children: [
              // Pane 1: Configuration Form
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: _buildConfigForm(context, state, notifier, isSw),
              ),
              // Pane 2: Native Preview Canvas
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: _buildPreviewCanvas(context, state, isSw),
              ),
            ],
          ),
        ),
        // Sticky transactional control footer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: UniformCommandBar(
            isPrinting: _isPrinting,
            isSaving: state.isSaving,
            isThermal: state.isThermal,
            saveSuccess: state.saveSuccess,
            isSwahili: isSw,
            onPrint: () => _handlePrintNow(state),
            onSave: () => _handleSaveConfiguration(notifier, isSw),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. MEDIUM SCREENS (Tablets, 768px - 1023px): Stacked with collapsible bottom sheet
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTabletLayout(
    BuildContext context,
    DocumentTemplateState state,
    DocumentTemplateController notifier,
    bool isSw,
    BoxConstraints constraints,
  ) {
    return Stack(
      children: [
        Column(
          children: [
            // Top Section: Compact Configuration Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DocumentSelectorToggle(
                      selectedType: state.selectedDocumentType,
                      onChanged: notifier.switchDocumentType,
                      isSwahili: isSw,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PrintProfileButton(
                    isThermal: state.isThermal,
                    onTap: () {
                      final targetThermal = !state.isThermal;
                      final match = state.currentTypeTemplates.firstWhere(
                        (t) => t.isThermal == targetThermal,
                        orElse: () => state.currentTypeTemplates.first,
                      );
                      notifier.selectTemplate(match.id);
                    },
                  ),
                ],
              ),
            ),

            // Prominent Viewport Locked Preview Canvas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: _buildPreviewCanvas(context, state, isSw),
              ),
            ),
          ],
        ),

        // Persistent collapsible bottom action sheet
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_tabletSheetCollapsed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isSw ? 'Mipangilio ya Hati' : 'Page Parameters',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _tabletSheetCollapsed = true),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        CommercialPalettePicker(
                          primaryHex: state.themePrimaryHex,
                          secondaryHex: state.themeSecondaryHex,
                          onPrimaryChanged: notifier.updatePrimaryHex,
                          onSecondaryChanged: notifier.updateSecondaryHex,
                          isSwahili: isSw,
                        ),
                        const SizedBox(height: 14),
                        CustomOverrideField(
                          initialValue: state.customLiquidOverride,
                          onChanged: notifier.updateCustomLiquid,
                          isSwahili: isSw,
                        ),
                      ],
                    ),
                  ),
                ),

              // Transactional Command Bar with toggle to expand parameters
              Row(
                children: [
                  FloatingActionButton.small(
                    onPressed: () => setState(
                        () => _tabletSheetCollapsed = !_tabletSheetCollapsed),
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.onSurface,
                    elevation: 2,
                    child: Icon(
                      _tabletSheetCollapsed
                          ? Icons.tune_outlined
                          : Icons.keyboard_arrow_down,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UniformCommandBar(
                      isPrinting: _isPrinting,
                      isSaving: state.isSaving,
                      isThermal: state.isThermal,
                      saveSuccess: state.saveSuccess,
                      isSwahili: isSw,
                      onPrint: () => _handlePrintNow(state),
                      onSave: () => _handleSaveConfiguration(notifier, isSw),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. LARGE SCREENS (Desktop/Web, >= 1024px): Dual-pane split canvas layout
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(
    BuildContext context,
    DocumentTemplateState state,
    DocumentTemplateController notifier,
    bool isSw,
    BoxConstraints constraints,
  ) {
    // 35% left column, 65% right column
    final leftWidth = constraints.maxWidth * 0.35;
    final rightWidth = constraints.maxWidth * 0.65;

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Column (35% width, scrollable): Hosts configuration controls
            SizedBox(
              width: leftWidth,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    right: BorderSide(color: AppColors.outlineVariant, width: 1),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: _buildConfigForm(context, state, notifier, isSw),
                ),
              ),
            ),

            // Right Column (65% width, fixed/viewport locked): Displays the layout stream
            SizedBox(
              width: rightWidth,
              child: Container(
                color: AppColors.surfaceDim,
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
                child: _buildPreviewCanvas(context, state, isSw),
              ),
            ),
          ],
        ),

        // Sticky transactional control footer spanning the layout
        Positioned(
          left: leftWidth + 24,
          right: 24,
          bottom: 16,
          child: UniformCommandBar(
            isPrinting: _isPrinting,
            isSaving: state.isSaving,
            isThermal: state.isThermal,
            saveSuccess: state.saveSuccess,
            isSwahili: isSw,
            onPrint: () => _handlePrintNow(state),
            onSave: () => _handleSaveConfiguration(notifier, isSw),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Shared Configuration Form Section
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildConfigForm(
    BuildContext context,
    DocumentTemplateState state,
    DocumentTemplateController notifier,
    bool isSw,
  ) {
    final primaryColor = _parseColor(state.themePrimaryHex);
    final printProfile = state.isThermal
        ? PrintSizeProfile.thermal80mm
        : PrintSizeProfile.a4Standard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Document Selector
        DocumentSelectorToggle(
          selectedType: state.selectedDocumentType,
          onChanged: notifier.switchDocumentType,
          isSwahili: isSw,
        ),
        const SizedBox(height: 20),

        // 2. Print Size Profile Matrix
        PrintProfileSelector(
          selectedProfile: printProfile,
          onChanged: (profile) {
            final isThermal = profile.isThermal;
            final match = state.currentTypeTemplates.firstWhere(
              (t) => t.isThermal == isThermal,
              orElse: () => state.currentTypeTemplates.first,
            );
            notifier.selectTemplate(match.id);
          },
          isSwahili: isSw,
        ),
        const SizedBox(height: 20),

        // 3. Marketplace Templates Grid
        _FormSectionCard(
          title: isSw ? 'Violezo Vilivyopo' : 'Marketplace Layout Designs',
          icon: Icons.dashboard_customize_outlined,
          badge: '${state.currentTypeTemplates.length} layouts',
          child: TemplateMarketplaceGrid(
            templates: state.currentTypeTemplates,
            selectedTemplateId: state.activeTemplateId,
            primaryColor: primaryColor,
            onTemplateSelected: (summary) =>
                notifier.selectTemplate(summary.id),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Commercial Theme Palettes
        _FormSectionCard(
          title: isSw ? 'Rangi za Chapa' : 'Brand Theme Palettes',
          icon: Icons.palette_outlined,
          child: CommercialPalettePicker(
            primaryHex: state.themePrimaryHex,
            secondaryHex: state.themeSecondaryHex,
            onPrimaryChanged: notifier.updatePrimaryHex,
            onSecondaryChanged: notifier.updateSecondaryHex,
            isSwahili: isSw,
          ),
        ),
        const SizedBox(height: 16),

        // 5. Document Content Options
        _FormSectionCard(
          title: isSw ? 'Nembo & Maelezo ya Chini' : 'Branding & Terms',
          icon: Icons.tune_outlined,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: state.showLogo,
                onChanged: notifier.updateShowLogo,
                title: Text(
                  isSw ? 'Onyesha Nembo ya Biashara' : 'Display Organization Logo',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                activeColor: AppColors.primary,
              ),
              const Divider(height: 16),
              TextField(
                controller: _footerNotesController,
                maxLines: 2,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                decoration: InputDecoration(
                  labelText: isSw ? 'Masharti / Footer Notes' : 'Footer Terms & Notes',
                  labelStyle: const TextStyle(fontSize: 12),
                  hintText: isSw
                      ? 'Mfano: Malipo yawe ndani ya siku 14'
                      : 'E.g. Payment due within 14 days',
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
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

        // 6. Custom Override Field (Expansible monospace)
        CustomOverrideField(
          initialValue: state.customLiquidOverride,
          onChanged: notifier.updateCustomLiquid,
          isSwahili: isSw,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Shared Preview Canvas Section
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPreviewCanvas(
    BuildContext context,
    DocumentTemplateState state,
    bool isSw,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live stream status header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.isThermal
                        ? const Color(0xFF0F172A)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        state.isThermal
                            ? Icons.receipt_long
                            : Icons.description_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.isThermal
                            ? '80mm Continuous Roll'
                            : 'ISO A4 Cut-Sheet',
                        style: const TextStyle(
                          fontFamily: 'Inter',
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
                    isSw ? 'Inahuisha...' : 'Streaming render...',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE PREVIEW STREAM',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Isolated live stream container
        Expanded(
          child: documentPreviewFrame.buildFrame(
            context: context,
            htmlContent: state.previewHtml,
            isThermal: state.isThermal,
            isLoading: state.isPreviewLoading,
          ),
        ),
      ],
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.badge,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
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
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PrintProfileButton extends StatelessWidget {
  const _PrintProfileButton({
    required this.isThermal,
    required this.onTap,
  });

  final bool isThermal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isThermal
              ? const Color(0xFF0F172A)
              : AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isThermal ? Icons.receipt_long : Icons.picture_as_pdf_outlined,
              size: 16,
              color: isThermal ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              isThermal ? '80mm Roll' : 'A4 Sheet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isThermal ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

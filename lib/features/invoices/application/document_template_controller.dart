import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/document_template_repository.dart';
import '../data/invoice_providers.dart';
import '../domain/document_template.dart';

class DocumentTemplateState {
  const DocumentTemplateState({
    this.selectedDocumentType = DocumentType.invoice,
    this.templates = const [],
    this.selectedTemplateDetail,
    this.configurations = const {},
    this.activeTemplateId = '',
    this.themePrimaryHex = '#0F172A',
    this.themeSecondaryHex = '#0D9488',
    this.customLiquidOverride = '',
    this.showLogo = true,
    this.footerNotes = '',
    this.previewHtml,
    this.isLoading = false,
    this.isPreviewLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.saveSuccess = false,
  });

  final DocumentType selectedDocumentType;
  final List<DocumentTemplateSummary> templates;
  final DocumentTemplateDetail? selectedTemplateDetail;
  final Map<DocumentType, TenantDocumentConfiguration> configurations;
  final String activeTemplateId;
  final String themePrimaryHex;
  final String themeSecondaryHex;
  final String customLiquidOverride;
  final bool showLogo;
  final String footerNotes;
  final String? previewHtml;
  final bool isLoading;
  final bool isPreviewLoading;
  final bool isSaving;
  final String? errorMessage;
  final bool saveSuccess;

  bool get isThermal =>
      (selectedTemplateDetail?.isThermal ?? false) ||
      templates
          .firstWhere(
            (t) => t.id == activeTemplateId,
            orElse: () => const DocumentTemplateSummary(
              id: '',
              name: '',
              documentType: DocumentType.invoice,
            ),
          )
          .isThermal;

  List<DocumentTemplateSummary> get currentTypeTemplates => templates
      .where((t) => t.documentType == selectedDocumentType)
      .toList(growable: false);

  DocumentTemplateState copyWith({
    DocumentType? selectedDocumentType,
    List<DocumentTemplateSummary>? templates,
    DocumentTemplateDetail? selectedTemplateDetail,
    Map<DocumentType, TenantDocumentConfiguration>? configurations,
    String? activeTemplateId,
    String? themePrimaryHex,
    String? themeSecondaryHex,
    String? customLiquidOverride,
    bool? showLogo,
    String? footerNotes,
    String? previewHtml,
    bool? isLoading,
    bool? isPreviewLoading,
    bool? isSaving,
    String? errorMessage,
    bool? saveSuccess,
    bool clearDetail = false,
  }) {
    return DocumentTemplateState(
      selectedDocumentType:
          selectedDocumentType ?? this.selectedDocumentType,
      templates: templates ?? this.templates,
      selectedTemplateDetail:
          clearDetail ? null : (selectedTemplateDetail ?? this.selectedTemplateDetail),
      configurations: configurations ?? this.configurations,
      activeTemplateId: activeTemplateId ?? this.activeTemplateId,
      themePrimaryHex: themePrimaryHex ?? this.themePrimaryHex,
      themeSecondaryHex: themeSecondaryHex ?? this.themeSecondaryHex,
      customLiquidOverride:
          customLiquidOverride ?? this.customLiquidOverride,
      showLogo: showLogo ?? this.showLogo,
      footerNotes: footerNotes ?? this.footerNotes,
      previewHtml: previewHtml ?? this.previewHtml,
      isLoading: isLoading ?? this.isLoading,
      isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }
}

class DocumentTemplateController extends StateNotifier<DocumentTemplateState> {
  DocumentTemplateController({
    required DocumentTemplateRepository repository,
  })  : _repository = repository,
        super(const DocumentTemplateState());

  final DocumentTemplateRepository _repository;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final templates = await _repository.listTemplates();
      final configs = await _repository.getTenantConfigurations();

      final configMap = <DocumentType, TenantDocumentConfiguration>{};
      for (final cfg in configs) {
        configMap[cfg.documentType] = cfg;
      }

      final activeDocType = state.selectedDocumentType;
      final currentConfig = configMap[activeDocType];

      // Find suitable initial template ID
      String initialTemplateId = currentConfig?.activeTemplateId ?? '';
      if (initialTemplateId.isEmpty) {
        final matches = templates.where((t) => t.documentType == activeDocType);
        final defaultTpl = matches.where((t) => t.isDefault).firstOrNull ??
            matches.firstOrNull;
        if (defaultTpl != null) {
          initialTemplateId = defaultTpl.id;
        }
      }

      state = state.copyWith(
        templates: templates,
        configurations: configMap,
        activeTemplateId: initialTemplateId,
        themePrimaryHex: currentConfig?.themePrimaryHex ?? '#0F172A',
        themeSecondaryHex: currentConfig?.themeSecondaryHex ?? '#0D9488',
        customLiquidOverride: currentConfig?.customLiquidOverride ?? '',
        showLogo: currentConfig?.showLogo ?? true,
        footerNotes: currentConfig?.footerNotes ?? '',
        isLoading: false,
      );

      if (initialTemplateId.isNotEmpty) {
        await _loadTemplateDetailAndPreview(initialTemplateId);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> switchDocumentType(DocumentType docType) async {
    if (state.selectedDocumentType == docType) return;

    final currentConfig = state.configurations[docType];
    final typeTemplates = state.templates.where((t) => t.documentType == docType);

    String targetTemplateId = currentConfig?.activeTemplateId ?? '';
    if (targetTemplateId.isEmpty) {
      final defaultTpl =
          typeTemplates.where((t) => t.isDefault).firstOrNull ??
              typeTemplates.firstOrNull;
      if (defaultTpl != null) {
        targetTemplateId = defaultTpl.id;
      }
    }

    state = state.copyWith(
      selectedDocumentType: docType,
      activeTemplateId: targetTemplateId,
      themePrimaryHex: currentConfig?.themePrimaryHex ?? '#0F172A',
      themeSecondaryHex: currentConfig?.themeSecondaryHex ?? '#0D9488',
      customLiquidOverride: currentConfig?.customLiquidOverride ?? '',
      showLogo: currentConfig?.showLogo ?? true,
      footerNotes: currentConfig?.footerNotes ?? '',
      clearDetail: true,
    );

    if (targetTemplateId.isNotEmpty) {
      await _loadTemplateDetailAndPreview(targetTemplateId);
    }
  }

  Future<void> selectTemplate(String templateId) async {
    if (state.activeTemplateId == templateId && state.selectedTemplateDetail != null) {
      return;
    }

    state = state.copyWith(activeTemplateId: templateId);
    await _loadTemplateDetailAndPreview(templateId);
  }

  void updatePrimaryHex(String hex) {
    state = state.copyWith(themePrimaryHex: hex);
    _schedulePreview();
  }

  void updateSecondaryHex(String hex) {
    state = state.copyWith(themeSecondaryHex: hex);
    _schedulePreview();
  }

  void updateCustomLiquid(String override) {
    state = state.copyWith(customLiquidOverride: override);
    _schedulePreview();
  }

  void updateShowLogo(bool show) {
    state = state.copyWith(showLogo: show);
    _schedulePreview();
  }

  void updateFooterNotes(String notes) {
    state = state.copyWith(footerNotes: notes);
    _schedulePreview();
  }

  void _schedulePreview() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      triggerPreview();
    });
  }

  Future<void> triggerPreview() async {
    final detail = state.selectedTemplateDetail;
    final layout = state.customLiquidOverride.trim().isNotEmpty
        ? state.customLiquidOverride
        : detail?.liquidLayout ?? '';

    if (layout.isEmpty) return;

    state = state.copyWith(isPreviewLoading: true);

    try {
      final html = await _repository.previewTemplate(
        liquidLayout: layout,
        documentType: state.selectedDocumentType,
        themePrimaryHex: state.themePrimaryHex,
        logoUrl: state.showLogo ? null : '',
      );

      state = state.copyWith(
        previewHtml: html,
        isPreviewLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isPreviewLoading: false,
        errorMessage: 'Preview error: $e',
      );
    }
  }

  Future<void> _loadTemplateDetailAndPreview(String templateId) async {
    state = state.copyWith(isPreviewLoading: true);

    try {
      final detail = await _repository.getTemplate(templateId);
      if (detail == null) {
        state = state.copyWith(isPreviewLoading: false);
        return;
      }

      state = state.copyWith(
        selectedTemplateDetail: detail,
      );

      await triggerPreview();
    } catch (e) {
      state = state.copyWith(
        isPreviewLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> saveConfiguration() async {
    state = state.copyWith(isSaving: true, errorMessage: null, saveSuccess: false);

    try {
      final docType = state.selectedDocumentType;
      final existing = state.configurations[docType];

      final updatedConfig = (existing ??
              TenantDocumentConfiguration(
                id: '',
                tenantId: '',
                documentType: docType,
                activeTemplateId: state.activeTemplateId,
              ))
          .copyWith(
        activeTemplateId: state.activeTemplateId,
        customLiquidOverride: state.customLiquidOverride,
        themePrimaryHex: state.themePrimaryHex,
        themeSecondaryHex: state.themeSecondaryHex,
        showLogo: state.showLogo,
        footerNotes: state.footerNotes,
      );

      final saved = await _repository.updateTenantConfiguration(
        documentType: docType,
        configuration: updatedConfig,
      );

      final newConfigs = Map<DocumentType, TenantDocumentConfiguration>.from(
        state.configurations,
      );
      newConfigs[docType] = saved;

      state = state.copyWith(
        configurations: newConfigs,
        isSaving: false,
        saveSuccess: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final documentTemplateControllerProvider =
    StateNotifierProvider<DocumentTemplateController, DocumentTemplateState>(
  (ref) {
    final repository = ref.watch(documentTemplateRepositoryProvider);
    return DocumentTemplateController(repository: repository);
  },
);

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../domain/document_template.dart';

class DocumentTemplateRepository {
  DocumentTemplateRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
  })  : _apiClient = apiClient,
        _cache = cache;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;

  static const _configCacheKey = 'tenant_document_configurations';

  static final List<DocumentTemplateSummary> builtInTemplates = [
    DocumentTemplateSummary(
      id: InvoiceLayoutStyle.modernRibbon.id,
      name: InvoiceLayoutStyle.modernRibbon.titleEn,
      description: InvoiceLayoutStyle.modernRibbon.subtitleEn,
      documentType: DocumentType.invoice,
      isDefault: false,
      displayOrder: 1,
    ),
    DocumentTemplateSummary(
      id: InvoiceLayoutStyle.executiveCorporate.id,
      name: InvoiceLayoutStyle.executiveCorporate.titleEn,
      description: InvoiceLayoutStyle.executiveCorporate.subtitleEn,
      documentType: DocumentType.invoice,
      isDefault: true,
      displayOrder: 2,
    ),
    DocumentTemplateSummary(
      id: InvoiceLayoutStyle.classicGrid.id,
      name: InvoiceLayoutStyle.classicGrid.titleEn,
      description: InvoiceLayoutStyle.classicGrid.subtitleEn,
      documentType: DocumentType.invoice,
      isDefault: false,
      displayOrder: 3,
    ),
    DocumentTemplateSummary(
      id: InvoiceLayoutStyle.customLetterhead.id,
      name: InvoiceLayoutStyle.customLetterhead.titleEn,
      description: InvoiceLayoutStyle.customLetterhead.subtitleEn,
      documentType: DocumentType.invoice,
      isDefault: false,
      displayOrder: 4,
    ),
    const DocumentTemplateSummary(
      id: '11111111-1111-1111-1111-111111111104',
      name: 'Thermal POS Slip (80mm)',
      description: 'Compact 80mm continuous thermal roll slip for POS printers',
      documentType: DocumentType.invoice,
      isDefault: false,
      displayOrder: 5,
    ),
    const DocumentTemplateSummary(
      id: '11111111-1111-1111-1111-111111111103',
      name: 'Standard Logistics Delivery Note',
      description: 'Official A4 dispatch & goods receipt delivery note',
      documentType: DocumentType.deliveryNote,
      isDefault: true,
      displayOrder: 1,
    ),
  ];

  /// Lists available marketplace templates (merges built-in layout archetypes with server templates).
  Future<List<DocumentTemplateSummary>> listTemplates({
    DocumentType? documentType,
  }) async {
    final baseList = documentType == null
        ? builtInTemplates
        : builtInTemplates
            .where((t) => t.documentType == documentType)
            .toList(growable: false);

    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/document-templates'),
        query: <String, dynamic>{
          if (documentType != null) 'documentType': documentType.value,
        },
      );

      if (response.statusCode != 200 || response.data is! List) {
        return baseList;
      }

      final list = response.data as List;
      final serverItems = list
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => DocumentTemplateSummary.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(growable: false);

      // Merge built-in visual archetypes first so all 4 client styles are always selectable
      final merged = <DocumentTemplateSummary>[...baseList];
      for (final srv in serverItems) {
        final alreadyCovered = merged.any(
          (b) =>
              b.id == srv.id ||
              (b.documentType == srv.documentType &&
                  !srv.isThermal &&
                  !b.isThermal &&
                  b.layoutStyle == srv.layoutStyle),
        );
        if (!alreadyCovered) {
          merged.add(srv);
        }
      }
      return merged;
    } catch (_) {
      return baseList;
    }
  }

  /// Gets full template details including LiquidLayout.
  Future<DocumentTemplateDetail?> getTemplate(String id) async {
    final builtIn = builtInTemplates.where((t) => t.id == id).firstOrNull;
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/document-templates/$id'),
      );

      if (response.statusCode == 200 && response.data is Map) {
        return DocumentTemplateDetail.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (_) {}

    if (builtIn != null) {
      return DocumentTemplateDetail(
        id: builtIn.id,
        name: builtIn.name,
        description: builtIn.description,
        documentType: builtIn.documentType,
        liquidLayout: '<div>{{ invoice.number }}</div>',
        engineVersion: 'Native-v3.0',
        isActive: true,
        isDefault: builtIn.isDefault,
        displayOrder: builtIn.displayOrder,
      );
    }
    return null;
  }

  /// Retrieves all document configurations for the current tenant (local-first with server merge).
  Future<List<TenantDocumentConfiguration>> getTenantConfigurations() async {
    final cachedConfigs = await _loadCachedConfigs();
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/tenant-document-configurations'),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        final remoteConfigs = list
            .whereType<Map<dynamic, dynamic>>()
            .map((item) => TenantDocumentConfiguration.fromJson(
                Map<String, dynamic>.from(item)))
            .toList(growable: false);

        if (remoteConfigs.isNotEmpty) {
          final mergedMap = <DocumentType, TenantDocumentConfiguration>{
            for (final c in remoteConfigs) c.documentType: c,
            // Preserve local template choice if it uses a built-in archetype ID not yet on server
            for (final local in cachedConfigs)
              if (local.activeTemplateId.startsWith('tpl-'))
                local.documentType: local,
          };
          final result = mergedMap.values.toList(growable: false);
          await _saveCachedConfigs(result);
          return result;
        }
      }
    } catch (_) {}
    return cachedConfigs;
  }

  /// Updates or creates the tenant's document configuration for a specific DocumentType.
  Future<TenantDocumentConfiguration> updateTenantConfiguration({
    required DocumentType documentType,
    required TenantDocumentConfiguration configuration,
  }) async {
    final matchTpl = builtInTemplates
        .where((t) => t.id == configuration.activeTemplateId)
        .firstOrNull;
    final optimistic = configuration.copyWith(
      documentType: documentType,
      activeTemplateName: matchTpl?.name ?? configuration.activeTemplateName,
    );

    // Always persist locally immediately so offline & on-device PDF/Preview reflect changes right away
    final existing = await _loadCachedConfigs();
    final map = <DocumentType, TenantDocumentConfiguration>{
      for (final c in existing) c.documentType: c,
      documentType: optimistic,
    };
    await _saveCachedConfigs(map.values.toList(growable: false));

    try {
      final response = await _apiClient.put<dynamic>(
        ApiRoutes.v1('/tenant-document-configurations/${documentType.name}'),
        body: optimistic.toUpdateRequestJson(),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final serverCfg = TenantDocumentConfiguration.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final merged = serverCfg.copyWith(
          activeTemplateId: optimistic.activeTemplateId,
          activeTemplateName:
              optimistic.activeTemplateName ?? serverCfg.activeTemplateName,
          themePrimaryHex: optimistic.themePrimaryHex,
          themeSecondaryHex: optimistic.themeSecondaryHex,
          showLogo: optimistic.showLogo,
          footerNotes: optimistic.footerNotes,
        );
        map[documentType] = merged;
        await _saveCachedConfigs(map.values.toList(growable: false));
        return merged;
      }
    } catch (_) {}

    return optimistic;
  }

  Future<List<TenantDocumentConfiguration>> _loadCachedConfigs() async {
    if (_cache == null) return const [];
    try {
      final raw = await _cache.load(_configCacheKey);
      if (raw == null) return const [];
      final items = raw['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map<dynamic, dynamic>>()
          .map((m) =>
              TenantDocumentConfiguration.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCachedConfigs(
      List<TenantDocumentConfiguration> configs) async {
    if (_cache == null) return;
    try {
      await _cache.save(_configCacheKey, {
        'items': configs.map((c) => c.toJson()).toList(growable: false),
      });
    } catch (_) {}
  }

  /// Dispatches preview render request to the server with 50ms target compilation.
  Future<String> previewTemplate({
    required String liquidLayout,
    required DocumentType documentType,
    String? themePrimaryHex,
    String? logoUrl,
  }) async {
    try {
      final response = await _apiClient.raw.post<String>(
        ApiRoutes.v1('/document-templates/preview'),
        data: <String, dynamic>{
          'liquidLayout': liquidLayout,
          'documentType': documentType.value,
          if (themePrimaryHex != null && themePrimaryHex.isNotEmpty)
            'themePrimaryHex': themePrimaryHex,
          if (logoUrl != null && logoUrl.isNotEmpty) 'logoUrl': logoUrl,
        },
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'text/html'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }

      throw ServerException('Hakikisho la kiolezo halikupokelewa vizuri.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Hitilafu ya kukusanya kiolezo cha uhakiki: $e');
    }
  }

  /// Fetches rendered HTML for an invoice.
  Future<String> getInvoiceHtml(String invoiceId) async {
    try {
      final response = await _apiClient.raw.get<String>(
        ApiRoutes.v1('/invoices/$invoiceId/html'),
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'text/html'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }

      throw ServerException('Ankara ya HTML haikuweza kupatikana.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Hitilafu ya kupakua muundo wa ankara: $e');
    }
  }

  /// Fetches rendered HTML for a delivery note.
  Future<String> getDeliveryNoteHtml(String deliveryNoteId) async {
    try {
      final response = await _apiClient.raw.get<String>(
        ApiRoutes.v1('/delivery-notes/$deliveryNoteId/html'),
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'text/html'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }

      throw ServerException('Hati ya delivery haikuweza kupatikana.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Hitilafu ya kupakua muundo wa delivery: $e');
    }
  }

  /// Fetches raw PDF bytes for an invoice from `/api/v1/invoices/{id}/pdf`.
  Future<List<int>> getInvoicePdfBytes(
    String invoiceId, {
    bool isThermal = false,
    String? primaryHex,
  }) async {
    try {
      final response = await _apiClient.raw.get<List<int>>(
        ApiRoutes.v1('/invoices/$invoiceId/pdf'),
        queryParameters: {
          'isThermal': isThermal,
          if (primaryHex != null && primaryHex.isNotEmpty) 'primaryHex': primaryHex,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }

      throw ServerException('Faili la PDF halikupatikana kutoka server.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Hitilafu ya kupakua faili la PDF: $e');
    }
  }

  /// Fetches raw PDF bytes for a delivery note from `/api/v1/delivery-notes/{id}/pdf`.
  Future<List<int>> getDeliveryNotePdfBytes(
    String deliveryNoteId, {
    bool isThermal = false,
    String? primaryHex,
  }) async {
    try {
      final response = await _apiClient.raw.get<List<int>>(
        ApiRoutes.v1('/delivery-notes/$deliveryNoteId/pdf'),
        queryParameters: {
          'isThermal': isThermal,
          if (primaryHex != null && primaryHex.isNotEmpty) 'primaryHex': primaryHex,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }

      throw ServerException('Faili la PDF halikupatikana kutoka server.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Hitilafu ya kupakua faili la PDF: $e');
    }
  }
}


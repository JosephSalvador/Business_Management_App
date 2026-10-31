import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../domain/document_template.dart';

class DocumentTemplateRepository {
  DocumentTemplateRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Lists available marketplace templates.
  Future<List<DocumentTemplateSummary>> listTemplates({
    DocumentType? documentType,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/document-templates'),
        query: <String, dynamic>{
          if (documentType != null) 'documentType': documentType.value,
        },
      );

      if (response.statusCode != 200 || response.data is! List) {
        return const [];
      }

      final list = response.data as List;
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => DocumentTemplateSummary.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Imeshindwa kupakia violezo: $e');
    }
  }

  /// Gets full template details including LiquidLayout.
  Future<DocumentTemplateDetail?> getTemplate(String id) async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/document-templates/$id'),
      );

      if (response.statusCode != 200 || response.data is! Map) {
        return null;
      }

      return DocumentTemplateDetail.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Imeshindwa kupakia muundo wa kiolezo: $e');
    }
  }

  /// Retrieves all document configurations for the current tenant.
  Future<List<TenantDocumentConfiguration>> getTenantConfigurations() async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/tenant-document-configurations'),
      );

      if (response.statusCode != 200 || response.data is! List) {
        return const [];
      }

      final list = response.data as List;
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => TenantDocumentConfiguration.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Imeshindwa kupakia mipangilio ya nyaraka: $e');
    }
  }

  /// Updates or creates the tenant's document configuration for a specific DocumentType.
  Future<TenantDocumentConfiguration> updateTenantConfiguration({
    required DocumentType documentType,
    required TenantDocumentConfiguration configuration,
  }) async {
    try {
      final response = await _apiClient.put<dynamic>(
        ApiRoutes.v1('/tenant-document-configurations/${documentType.name}'),
        body: configuration.toUpdateRequestJson(),
      );

      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Imeshindwa kuhifadhi mpangilio wa nyaraka.');
      }

      return TenantDocumentConfiguration.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Hitilafu wakati wa kuhifadhi mpangilio: $e');
    }
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


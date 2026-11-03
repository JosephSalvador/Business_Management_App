import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../settings/data/organization_repository.dart';
import '../../domain/document_template.dart';
import '../../domain/invoice.dart';
import 'local_pdf_document_generator.dart';

final customerInvoicePdfServiceProvider =
    Provider<CustomerInvoicePdfService>((ref) {
  return CustomerInvoicePdfService();
});

class CustomerInvoicePdfService {
  final LocalPdfDocumentGenerator _generator = LocalPdfDocumentGenerator();

  Future<Uint8List> buildA4Pdf({
    required CustomerInvoice invoice,
    required Organization organization,
    bool isSwahili = false,
    TenantDocumentConfiguration? templateConfig,
  }) async {
    return _generator.generateInvoiceA4(
      invoice: invoice,
      organization: organization,
      isSwahili: isSwahili,
      templateConfig: templateConfig,
    );
  }

  Future<void> shareA4Pdf({
    required CustomerInvoice invoice,
    required Organization organization,
    bool isSwahili = false,
    TenantDocumentConfiguration? templateConfig,
  }) async {
    final bytes = await buildA4Pdf(
      invoice: invoice,
      organization: organization,
      isSwahili: isSwahili,
      templateConfig: templateConfig,
    );
    final safeNumber =
        invoice.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final docPrefix = invoice.documentTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${invoice.documentTitle} ${invoice.invoiceNumber} - ${organization.name}',
        subject: '${invoice.documentTitle} ${invoice.invoiceNumber}',
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: '$docPrefix-$safeNumber.pdf',
          ),
        ],
      ),
    );
  }
}

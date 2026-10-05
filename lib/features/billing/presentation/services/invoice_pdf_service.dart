import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../domain/billing.dart';

final invoicePdfServiceProvider = Provider<InvoicePdfService>((ref) {
  return InvoicePdfService();
});

class InvoicePdfLabels {
  const InvoicePdfLabels({
    required this.title,
    required this.invoiceNumber,
    required this.status,
    required this.statusValue,
    required this.issued,
    required this.period,
    required this.description,
    required this.amountDue,
    required this.reference,
    required this.paid,
  });

  final String title;
  final String invoiceNumber;
  final String status;
  final String statusValue;
  final String issued;
  final String period;
  final String description;
  final String amountDue;
  final String reference;
  final String paid;
}

class InvoicePdfService {
  Future<Uint8List> build(
    BillingInvoice invoice, {
    required InvoicePdfLabels labels,
  }) async {
    final document = pw.Document();
    final dateFormat = DateFormat('d MMM yyyy');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'JOLINX BUSINESS OS',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(labels.title),
          pw.SizedBox(height: 24),
          _row(labels.invoiceNumber, invoice.number),
          _row(labels.status, labels.statusValue),
          _row(
            labels.issued,
            dateFormat.format(invoice.issuedAtUtc.toLocal()),
          ),
          _row(
            labels.period,
            '${dateFormat.format(invoice.periodStartUtc.toLocal())} - '
            '${dateFormat.format(invoice.periodEndUtc.toLocal())}',
          ),
          _row(labels.description, invoice.description),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  labels.amountDue,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${invoice.currency} ${invoice.amount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (invoice.reference != null) ...[
            pw.SizedBox(height: 16),
            _row(labels.reference, invoice.reference!),
          ],
          if (invoice.paidAtUtc != null)
            _row(
              labels.paid,
              dateFormat.format(invoice.paidAtUtc!.toLocal()),
            ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> share(
    BillingInvoice invoice, {
    required InvoicePdfLabels labels,
  }) async {
    final bytes = await build(invoice, labels: labels);
    final safeNumber =
        invoice.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: 'invoice-$safeNumber.pdf',
          ),
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}

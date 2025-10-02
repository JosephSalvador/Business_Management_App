// services/receipt_share_service.dart
import 'package:share_plus/share_plus.dart';
import '../models/sale_models.dart';

class ReceiptShareService {
  
  // Share receipt as text
  static Future<void> shareReceiptAsText(Sale sale) async {
    final receiptText = _generateReceiptText(sale);
    await Share.share(receiptText, subject: 'Receipt: ${sale.receiptNumber}');
  }

  // Generate text receipt for sharing
  static String _generateReceiptText(Sale sale) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== RECEIPT ===');
    buffer.writeln('Receipt No: ${sale.receiptNumber}');
    buffer.writeln('Date: ${sale.date.toString()}');
    buffer.writeln('Customer: ${sale.customerName}');
    if (sale.customerTin.isNotEmpty) {
      buffer.writeln('TIN: ${sale.customerTin}');
    }
    buffer.writeln('Payment Method: ${sale.paymentMethod}');
    if (sale.paymentReference.isNotEmpty) {
      buffer.writeln('Reference: ${sale.paymentReference}');
    }
    buffer.writeln('---');
    
    for (final item in sale.items) {
      buffer.writeln('${item.productName} x${item.quantity}');
      buffer.writeln('  TZS ${_formatCurrency(item.unitPrice * item.quantity)}');
    }
    
    buffer.writeln('---');
    buffer.writeln('Subtotal: TZS ${_formatCurrency(sale.amount)}');
    buffer.writeln('VAT (${sale.vatRate == 'A' ? '18%' : '16%'}): TZS ${_formatCurrency(sale.vatAmount)}');
    buffer.writeln('TOTAL: TZS ${_formatCurrency(sale.totalAmount)}');
    buffer.writeln('---');
    buffer.writeln('VFD Serial: ${sale.vfdSerial}');
    buffer.writeln('Thank you for your business!');
    
    return buffer.toString();
  }

  static String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
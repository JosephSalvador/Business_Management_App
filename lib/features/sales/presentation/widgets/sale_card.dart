// features/sales/presentation/widgets/sale_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/sale_models.dart';
import '../../data/services/vat_calculator.dart';

class SaleCard extends StatelessWidget {
  final Sale sale;

  const SaleCard({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sale.receiptNumber,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(sale.status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    sale.status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Customer Info
            Text(
              sale.customerName,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            if (sale.customerTin.isNotEmpty)
              Text(
                'TIN: ${sale.customerTin}',
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
              ),
            const SizedBox(height: 12),
            
            // Payment Details
            Row(
              children: [
                Icon(
                  sale.paymentMethod == 'Electronic' ? Icons.credit_card : Icons.money,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${sale.paymentMethod} Payment',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getVatRateColor(sale.vatRate).withAlpha(25), // Fixed opacity issue
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    VatCalculator.getVatRateDescription(sale.vatRate),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _getVatRateColor(sale.vatRate),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Amount and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TZS ${_formatCurrency(sale.totalAmount)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  _formatDate(sale.date),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            // Payment Reference (if electronic)
            if (sale.paymentReference.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'PRN: ${sale.paymentReference}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed': return Colors.green;
      case 'Pending': return Colors.orange;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getVatRateColor(String vatRate) {
    switch (vatRate) {
      case 'A': return Colors.blue;
      case 'B': return Colors.green;
      case 'C': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
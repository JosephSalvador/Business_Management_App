import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sale_models.dart';
import 'receipt_share_service.dart';

// Update your sales history list item to include share button
class SalesHistoryItem extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;
  
  const SalesHistoryItem({super.key, 
    required this.sale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(
          sale.paymentMethod == 'Electronic' ? Icons.credit_card : Icons.money,
          color: sale.paymentMethod == 'Electronic' ? Colors.blue : Colors.green,
        ),
        title: Text(
          sale.customerName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TZS ${_formatCurrency(sale.totalAmount)}'),
            Text(
              '${_formatDate(sale.date)} • ${sale.paymentMethod}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              onPressed: () => _shareSale(context),
              tooltip: 'Share Receipt',
            ),
            IconButton(
              icon: const Icon(Icons.receipt, size: 20),
              onPressed: onTap,
              tooltip: 'View Details',
            ),
          ],
        ),
      ),
    );
  }

  void _shareSale(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ReceiptShareService.shareReceiptAsText(sale);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to share receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}



class SalesHistoryService {
  final List<Sale> _salesHistory = [];

  // Get the sales history list
  List<Sale> get salesHistory => List.from(_salesHistory);

  // Add a sale to history
  void addSale(Sale sale) {
    _salesHistory.add(sale);
    // Sort by date (newest first)
    _salesHistory.sort((a, b) => b.date.compareTo(a.date));
  }

  // Get sales by date range
  List<Sale> getSalesByDateRange(DateTime startDate, DateTime endDate) {
    return _salesHistory.where((sale) => 
      sale.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
      sale.date.isBefore(endDate.add(const Duration(days: 1)))
    ).toList();
  }

  // Get today's sales
  List<Sale> getTodaySales() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  // Get sales by payment method
  List<Sale> getSalesByPaymentMethod(String paymentMethod) {
    return _salesHistory.where((sale) => sale.paymentMethod == paymentMethod).toList();
  }

  // Get total revenue for a period
  double getTotalRevenue({DateTime? startDate, DateTime? endDate}) {
    List<Sale> sales = _salesHistory;
    
    if (startDate != null && endDate != null) {
      sales = getSalesByDateRange(startDate, endDate);
    }
    
    return sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  // Get total VAT collected for a period
  double getTotalVatCollected({DateTime? startDate, DateTime? endDate}) {
    List<Sale> sales = _salesHistory;
    
    if (startDate != null && endDate != null) {
      sales = getSalesByDateRange(startDate, endDate);
    }
    
    return sales.fold(0.0, (sum, sale) => sum + sale.vatAmount);
  }

  // Get sales count by status
  Map<String, int> getSalesCountByStatus() {
    final Map<String, int> count = {};
    
    for (final sale in _salesHistory) {
      count[sale.status] = (count[sale.status] ?? 0) + 1;
    }
    
    return count;
  }

  // Search sales by customer name or receipt number
  List<Sale> searchSales(String query) {
    if (query.isEmpty) return _salesHistory;
    
    final lowercaseQuery = query.toLowerCase();
    return _salesHistory.where((sale) =>
      sale.customerName.toLowerCase().contains(lowercaseQuery) ||
      sale.receiptNumber.toLowerCase().contains(lowercaseQuery) ||
      (sale.customerTin.isNotEmpty && sale.customerTin.contains(query)) ||
      (sale.paymentReference.isNotEmpty && sale.paymentReference.toLowerCase().contains(lowercaseQuery))
    ).toList();
  }

  // Clear all sales history (for testing/reset)
  void clearHistory() {
    _salesHistory.clear();
  }

  // Get sales statistics
  Map<String, dynamic> getSalesStatistics() {
    final completedSales = _salesHistory.where((s) => s.status == 'Completed').toList();
    final totalRevenue = completedSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalVat = completedSales.fold(0.0, (sum, sale) => sum + sale.vatAmount);
    final cashSales = completedSales.where((s) => s.paymentMethod == 'Cash').length;
    final electronicSales = completedSales.where((s) => s.paymentMethod == 'Electronic').length;
    final averageSale = completedSales.isNotEmpty ? totalRevenue / completedSales.length : 0;

    return {
      'totalSales': completedSales.length,
      'totalRevenue': totalRevenue,
      'totalVat': totalVat,
      'cashSales': cashSales,
      'electronicSales': electronicSales,
      'averageSale': averageSale,
      'vatRateA': completedSales.where((s) => s.vatRate == 'A').length,
      'vatRateB': completedSales.where((s) => s.vatRate == 'B').length,
    };
  }
}

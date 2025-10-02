// features/sales/presentation/pages/sales_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/user_provider.dart';
import '../widgets/sale_card.dart';
import '../../data/models/sale_models.dart';
import '../../data/services/sales_history_service.dart' as sales_service;

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final sales_service.SalesHistoryService _salesHistoryService = sales_service.SalesHistoryService();
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    setState(() {
      _sales = _salesHistoryService.salesHistory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    // If no sales, show empty state
    if (_sales.isEmpty) {
      return _buildEmptyState(userProvider);
    }

    final completedSales = _sales.where((s) => s.status == 'Completed').toList();
    final totalRevenue = completedSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final electronicSales = completedSales.where((s) => s.paymentMethod == 'Electronic').length;
    final totalVatCollected = completedSales.fold(0.0, (sum, sale) => sum + sale.vatAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (userProvider.hasPrivilege('Create New Sales')) 
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/sales/new'),
            ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => _showSalesAnalytics(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sales Overview Cards
          _buildSalesOverview(totalRevenue, electronicSales, completedSales.length, totalVatCollected),
          // Sales List Header
          _buildSalesListHeader(),
          // Sales List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadSales();
              },
              child: ListView.builder(
                itemCount: _sales.length,
                itemBuilder: (context, index) => SaleCard(sale: _sales[index]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: userProvider.hasPrivilege('Create New Sales')
          ? FloatingActionButton(
              onPressed: () => context.go('/sales/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState(UserProvider userProvider) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (userProvider.hasPrivilege('Create New Sales')) 
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/sales/new'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 120,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 24),
              Text(
                'No Sales Yet',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Start creating sales to see them appear here.\nAll your sales will be automatically saved to history.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (userProvider.hasPrivilege('Create New Sales')) ...[
                ElevatedButton(
                  onPressed: () => context.go('/sales/new'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Create Your First Sale'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _addSampleData(),
                  child: const Text('Add Sample Data for Testing'),
                ),
              ] else ...[
                Text(
                  'Contact your administrator for sales creation privileges',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesOverview(double totalRevenue, int electronicSales, int totalSales, double totalVat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.green.shade50],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SalesMetricCard(
                  title: 'Total Revenue',
                  value: 'TZS ${_formatCurrency(totalRevenue)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SalesMetricCard(
                  title: 'Electronic Sales',
                  value: electronicSales.toString(),
                  icon: Icons.credit_card,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SalesMetricCard(
                  title: 'Total Sales',
                  value: totalSales.toString(),
                  icon: Icons.receipt,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SalesMetricCard(
                  title: 'VAT Collected',
                  value: 'TZS ${_formatCurrency(totalVat)}',
                  icon: Icons.account_balance,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Recent Sales (${_sales.length})',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            'Newest First',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showSalesAnalytics() {
    final completedSales = _sales.where((s) => s.status == 'Completed').toList();
    final totalRevenue = completedSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final cashSales = completedSales.where((s) => s.paymentMethod == 'Cash').length;
    final electronicSales = completedSales.where((s) => s.paymentMethod == 'Electronic').length;
    final double averageSale = completedSales.isNotEmpty ? totalRevenue / completedSales.length : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sales Analytics', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnalyticsRow('Total Sales:', completedSales.length.toString()),
              _AnalyticsRow('Total Revenue:', 'TZS ${_formatCurrency(totalRevenue)}'),
              _AnalyticsRow('Average Sale:', 'TZS ${_formatCurrency(averageSale)}'),
              _AnalyticsRow('Cash Sales:', cashSales.toString()),
              _AnalyticsRow('Electronic Sales:', electronicSales.toString()),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'VAT Summary',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              _AnalyticsRow('18% VAT Sales:', _countVatSales('A').toString()),
              _AnalyticsRow('16% VAT Sales:', _countVatSales('B').toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  int _countVatSales(String vatRate) {
    return _sales.where((sale) => sale.vatRate == vatRate).length;
  }

  void _addSampleData() {
    final sampleSales = [
      Sale(
        id: '1',
        customerName: 'TECH CORP LTD',
        customerTin: '123456789',
        customerMobile: '255712345678',
        date: DateTime(2024, 1, 15, 14, 30),
        amount: 1180000.00,
        vatAmount: 180000.00,
        totalAmount: 1180000.00,
        vatRate: 'A',
        status: 'Completed',
        paymentMethod: 'Cash',
        paymentReference: '',
        paymentChannel: '',
        items: [
          SaleItem(
            id: '1',
            productName: 'Laptop Dell XPS 15',
            productCode: 'LP-DELL-XPS15',
            quantity: 2,
            unitPrice: 500000.00,
            vatRate: 18.0,
            vatAmount: 152542.37,
            totalAmount: 1000000.00,
          ),
        ],
        vfdSerial: 'VFD-001-2024',
        receiptNumber: 'RCT-001-2024',
      ),
      Sale(
        id: '2',
        customerName: 'SMALL BUSINESS TZ',
        customerTin: '987654321',
        customerMobile: '255765432109',
        date: DateTime(2024, 1, 14, 11, 15),
        amount: 2360000.00,
        vatAmount: 320000.00,
        totalAmount: 2320000.00,
        vatRate: 'B',
        status: 'Completed',
        paymentMethod: 'Electronic',
        paymentReference: 'PRN-1234WXYZ',
        paymentChannel: '01601',
        items: [
          SaleItem(
            id: '1',
            productName: 'Office Desk',
            productCode: 'FURN-DESK-OFF',
            quantity: 5,
            unitPrice: 400000.00,
            vatRate: 16.0,
            vatAmount: 271186.44,
            totalAmount: 2000000.00,
          ),
        ],
        vfdSerial: 'VFD-001-2024',
        receiptNumber: 'RCT-002-2024',
      ),
      Sale(
        id: '3',
        customerName: 'WALK-IN CUSTOMER',
        customerTin: '',
        customerMobile: '',
        date: DateTime(2024, 1, 13, 9, 45),
        amount: 354000.00,
        vatAmount: 54000.00,
        totalAmount: 354000.00,
        vatRate: 'A',
        status: 'Completed',
        paymentMethod: 'Cash',
        paymentReference: '',
        paymentChannel: '',
        items: [
          SaleItem(
            id: '1',
            productName: 'Wireless Mouse',
            productCode: 'ACC-MOUSE-WL',
            quantity: 3,
            unitPrice: 118000.00,
            vatRate: 18.0,
            vatAmount: 54000.00,
            totalAmount: 354000.00,
          ),
        ],
        vfdSerial: 'VFD-001-2024',
        receiptNumber: 'RCT-003-2024',
      ),
    ];

    for (final sale in sampleSales) {
      _salesHistoryService.addSale(sale);
    }

    _loadSales();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sample sales data added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class _SalesMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SalesMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
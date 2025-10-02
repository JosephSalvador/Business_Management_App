import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/sale_models.dart';

class TraReceipt extends StatelessWidget {
  final Sale sale;

  const TraReceipt({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Container(
          width: 300, // Receipt width
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // TRA Header
              Text(
                'UNITED REPUBLIC OF TANZANIA',
                style: GoogleFonts.courierPrime(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'TRA - TANZANIA REVENUE AUTHORITY',
                style: GoogleFonts.courierPrime(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'ELECTRONIC FISCAL DEVICE',
                style: GoogleFonts.courierPrime(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'RECEIPT',
                style: GoogleFonts.courierPrime(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Business Information
              const _ReceiptRow('VRN:', '123456789001'),
              const _ReceiptRow('TIN:', '123456789'),
              const _ReceiptRow('Name:', 'YOUR BUSINESS NAME LTD'),
              const _ReceiptRow('Location:', 'DAR ES SALAAM'),
              _ReceiptRow('Serial No:', sale.vfdSerial),
              _ReceiptRow('Receipt No:', sale.receiptNumber),
              _ReceiptRow('Date:', _formatDate(sale.date)),
              _ReceiptRow('Time:', _formatTime(sale.date)),
              
              const SizedBox(height: 8),
              const _Divider(),
              const SizedBox(height: 8),
              
              // Customer Information
              if (sale.customerName.isNotEmpty)
                _ReceiptRow('Customer:', sale.customerName),
              if (sale.customerTin.isNotEmpty)
                _ReceiptRow('TIN:', sale.customerTin),
              if (sale.paymentReference.isNotEmpty)
                _ReceiptRow('PRN:', sale.paymentReference),
              
              const SizedBox(height: 8),
              const _Divider(),
              const SizedBox(height: 8),
              
              // Items Header
              const _ReceiptRow('ITEM', 'AMOUNT', isHeader: true),
              const _Divider(),
              
              // Items List
              for (final item in sale.items)
                Column(
                  children: [
                    _ItemRow(
                      name: item.productName,
                      quantity: item.quantity,
                      price: item.unitPrice,
                      total: item.unitPrice * item.quantity,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              
              const _Divider(),
              const SizedBox(height: 8),
              
              // Totals
              _ReceiptRow('Subtotal:', 'TZS ${_formatCurrency(sale.amount)}'),
              _ReceiptRow('VAT ${sale.vatRate == 'A' ? '18%' : '16%'}:', 'TZS ${_formatCurrency(sale.vatAmount)}'),
              _ReceiptRow('TOTAL:', 'TZS ${_formatCurrency(sale.totalAmount)}', isTotal: true),
              
              const SizedBox(height: 8),
              const _Divider(),
              const SizedBox(height: 8),
              
              // Payment Information
              _ReceiptRow('Payment Mode:', sale.paymentMethod),
              if (sale.paymentMethod == 'Electronic')
                const _ReceiptRow('Channel:', '01601'),
              
              const SizedBox(height: 8),
              const _Divider(),
              const SizedBox(height: 8),
              
              // Footer
              Text(
                'THIS IS AN ELECTRONIC RECEIPT',
                style: GoogleFonts.courierPrime(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'VALID WITHOUT OFFICIAL SEAL',
                style: GoogleFonts.courierPrime(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'THANK YOU FOR YOUR BUSINESS',
                style: GoogleFonts.courierPrime(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                '* SOFTWARE BY: YOUR COMPANY *',
                style: GoogleFonts.courierPrime(
                  fontSize: 7,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _printReceipt(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Print'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _printReceipt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt sent to printer'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String left;
  final String right;
  final bool isHeader;
  final bool isTotal;

  const _ReceiptRow(
    this.left,
    this.right, {
    this.isHeader = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            left,
            style: GoogleFonts.courierPrime(
              fontSize: isHeader ? 10 : 9,
              fontWeight: isHeader || isTotal ? FontWeight.bold : FontWeight.normal,
              height: 1.2,
            ),
          ),
        ),
        Text(
          right,
          style: GoogleFonts.courierPrime(
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader || isTotal ? FontWeight.bold : FontWeight.normal,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String name;
  final int quantity;
  final double price;
  final double total;

  const _ItemRow({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.courierPrime(
                  fontSize: 9,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'TZS ${_formatCurrency(total)}',
              style: GoogleFonts.courierPrime(
                fontSize: 9,
                height: 1.2,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$quantity X TZS ${_formatCurrency(price)}',
              style: GoogleFonts.courierPrime(
                fontSize: 8,
                color: Colors.grey.shade700,
                height: 1.2,
              ),
            ),
            const SizedBox(), // Spacer
          ],
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.black,
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatCurrency(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}
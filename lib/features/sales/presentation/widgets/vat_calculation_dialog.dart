import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/sale_models.dart';
import '../../data/services/vat_calculator.dart';
import '../../data/services/tin_validator.dart';

class VatCalculationDialog extends StatefulWidget {
  const VatCalculationDialog({super.key});

  @override
  State<VatCalculationDialog> createState() => _VatCalculationDialogState();
}

class _VatCalculationDialogState extends State<VatCalculationDialog> {
  final _amountController = TextEditingController();
  final _tinController = TextEditingController();
  final _mobileController = TextEditingController();
  final _customerNameController = TextEditingController();
  
  bool _isElectronicPayment = false;
  bool _isValidatingTin = false;
  TinValidationResult? _tinValidationResult;
  VatCalculationResult? _vatCalculationResult;

  @override
  void dispose() {
    _amountController.dispose();
    _tinController.dispose();
    _mobileController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _validateTin() async {
    if (_tinController.text.isEmpty) {
      setState(() {
        _tinValidationResult = null;
      });
      return;
    }

    setState(() {
      _isValidatingTin = true;
    });

    final result = await TinValidator.validateTin(_tinController.text);
    
    setState(() {
      _tinValidationResult = result;
      _isValidatingTin = false;
    });

    if (result.isValid && result.tradingName.isNotEmpty) {
      _customerNameController.text = result.tradingName;
    }
  }

  void _calculateVat() {
    if (_amountController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount == 0.0) return;

    final result = VatCalculator.calculateDualVat(
      originalAmount: amount,
      customerTin: _tinController.text,
      isElectronicPayment: _isElectronicPayment,
      isVatRegistered: _tinValidationResult?.hasVAT ?? false,
    );

    setState(() {
      _vatCalculationResult = result;
    });
  }

  void _processSale() {
    if (_vatCalculationResult == null) return;

    // Simulate sale processing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sale processed with ${_vatCalculationResult!.appliedVatRate} VAT rate'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Sale - VAT Calculation',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            
            // Amount Input
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Sale Amount (TZS)',
                prefixText: 'TZS ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateVat(),
            ),
            const SizedBox(height: 16),
            
            // Payment Method
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PaymentMethodButton(
                            title: 'Cash',
                            icon: Icons.money,
                            isSelected: !_isElectronicPayment,
                            onTap: () {
                              setState(() {
                                _isElectronicPayment = false;
                                _calculateVat();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PaymentMethodButton(
                            title: 'Electronic',
                            icon: Icons.credit_card,
                            isSelected: _isElectronicPayment,
                            onTap: () {
                              setState(() {
                                _isElectronicPayment = true;
                                _calculateVat();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // TIN Input and Validation
            if (_isElectronicPayment) ...[
              TextFormField(
                controller: _tinController,
                decoration: InputDecoration(
                  labelText: 'Customer TIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isValidatingTin
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.verified_user),
                          onPressed: _validateTin,
                        ),
                ),
                onChanged: (_) => _validateTin(),
              ),
              const SizedBox(height: 8),
              
              // TIN Validation Result
              if (_tinValidationResult != null) 
                _TinValidationResultCard(result: _tinValidationResult!),
              
              const SizedBox(height: 16),
              
              // Mobile Number
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixText: '+255 ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
            ],
            
            // Customer Name
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            
            // VAT Calculation Result
            if (_vatCalculationResult != null)
              _VatCalculationResultCard(result: _vatCalculationResult!),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _vatCalculationResult != null ? _processSale : null,
                    child: const Text('Process Sale'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.blue.shade50 : Colors.white,
      elevation: isSelected ? 2 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinValidationResultCard extends StatelessWidget {
  final TinValidationResult result;

  const _TinValidationResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.isValid ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isValid ? Icons.verified : Icons.error,
                  color: result.isValid ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  result.isValid ? 'Valid TIN' : 'Invalid TIN',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: result.isValid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (result.isValid) ...[
              const SizedBox(height: 8),
              Text(
                'Taxpayer: ${result.tradingName.isNotEmpty ? result.tradingName : '${result.firstName} ${result.lastName}'}',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              Text(
                'VAT Status: ${result.hasVAT ? 'Registered (VRN: ${result.vrn})' : 'Not Registered'}',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VatCalculationResultCard extends StatelessWidget {
  final VatCalculationResult result;

  const _VatCalculationResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VAT Calculation Result',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _VatResultRow('Original Amount:', 'TZS ${_formatCurrency(result.originalAmount)}'),
            _VatResultRow('VAT Exclusive:', 'TZS ${_formatCurrency(result.vatExclusiveAmount)}'),
            _VatResultRow('VAT Amount:', 'TZS ${_formatCurrency(result.newVatAmount)}'),
            _VatResultRow('Total Amount:', 'TZS ${_formatCurrency(result.newTotalAmount)}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getVatRateColor(result.appliedVatRate),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                VatCalculator.getVatRateDescription(result.appliedVatRate),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Color _getVatRateColor(String vatRate) {
    switch (vatRate) {
      case 'A': return Colors.blue;
      case 'B': return Colors.green;
      case 'C': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class _VatResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _VatResultRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14)),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
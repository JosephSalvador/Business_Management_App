import 'package:business_management_system/shared/services/printer_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../widgets/vat_calculation_dialog.dart';
import '../widgets/product_selection_dialog.dart';
import '../widgets/tra_receipt.dart';
import '../widgets/printer_selection_dialog.dart';
import '../../data/models/sale_models.dart';
import '../../data/services/vat_calculator.dart';
import '../../data/services/tin_validator.dart';
import '../../data/services/sales_history_service.dart' as sales_service;
import '../../data/services/receipt_share_service.dart';
import '../../data/services/bluetooth_printer_service.dart';

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key});

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  final _customerNameController = TextEditingController();
  final _tinController = TextEditingController();
  final _mobileController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isElectronicPayment = false;
  bool _isValidatingTin = false;
  TinValidationResult? _tinValidationResult;
  final List<SaleItem> _selectedProducts = [];
  double _totalAmount = 0.0;
  double _vatAmount = 0.0;
  double _finalAmount = 0.0;
  String _appliedVatRate = 'A';
  int _currentStep = 0; // 0: Products, 1: Customer, 2: Review
  String _selectedElectronicMethod = 'creditcard'; // 'creditcard' or 'emoney'

  @override
  void dispose() {
    _customerNameController.dispose();
    _tinController.dispose();
    _mobileController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    final subtotal = _selectedProducts.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
    
    final vatResult = VatCalculator.calculateDualVat(
      originalAmount: subtotal,
      customerTin: _tinController.text,
      isElectronicPayment: _isElectronicPayment,
      isVatRegistered: _tinValidationResult?.hasVAT ?? false,
    );

    setState(() {
      _totalAmount = subtotal;
      _vatAmount = vatResult.newVatAmount;
      _finalAmount = vatResult.newTotalAmount;
      _appliedVatRate = vatResult.appliedVatRate;
    });
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

    if (result.isValid && result.tradingName.isNotEmpty && _customerNameController.text.isEmpty) {
      _customerNameController.text = result.tradingName;
    }

    _calculateTotals();
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => ProductSelectionDialog(
        onProductSelected: (product) {
          setState(() {
            _selectedProducts.add(product);
          });
          _calculateTotals();
        },
      ),
    );
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
    _calculateTotals();
  }

  void _updateProductQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      setState(() {
        _selectedProducts[index] = _selectedProducts[index].copyWith(quantity: newQuantity);
      });
      _calculateTotals();
    }
  }

  Future<void> _processSale() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isElectronicPayment && _tinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TIN is required for electronic payments'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // For electronic payments, show mobile number input first
    if (_isElectronicPayment) {
      final mobileNumber = await _showMobileNumberInput();
      if (mobileNumber == null) return; // User cancelled
      
      // Update mobile number in the form
      _mobileController.text = mobileNumber;
      
      // Show payment processing
      final paymentSuccess = await _showElectronicPaymentProcessing();
      if (!paymentSuccess) return; // Payment failed
    }

    // Create sale object
    final sale = Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: _customerNameController.text.isEmpty ? 'Walk-in Customer' : _customerNameController.text,
      customerTin: _tinController.text,
      customerMobile: _mobileController.text,
      date: DateTime.now(),
      amount: _totalAmount,
      vatAmount: _vatAmount,
      totalAmount: _finalAmount,
      vatRate: _appliedVatRate,
      status: 'Completed',
      paymentMethod: _isElectronicPayment ? 'Electronic' : 'Cash',
      paymentReference: _isElectronicPayment ? 'PRN-${DateTime.now().millisecondsSinceEpoch}' : '',
      paymentChannel: _isElectronicPayment ? 
        (_selectedElectronicMethod == 'creditcard' ? '01601' : '01602') : '',
      items: List.from(_selectedProducts),
      vfdSerial: 'VFD-001-2024',
      receiptNumber: 'RCT-${DateTime.now().millisecondsSinceEpoch}',
    );

    // Add to sales history
    sales_service.SalesHistoryService().addSale(sale);

    // Check if we have a saved printer
    final hasSavedPrinter = await PrinterStorageService.hasDefaultPrinter();

    // Show success dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _SaleSuccessDialog(
          sale: sale,
          onNewSale: () {
            _clearForm();
            Navigator.of(context).pop();
          },
          onDashboard: () {
            Navigator.of(context).pop();
            context.go('/dashboard');
          },
          hasSavedPrinter: hasSavedPrinter,
        ),
      );
    }
  }

  Future<String?> _showMobileNumberInput() {
    final mobileController = TextEditingController(text: _mobileController.text);
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MobileNumberInputDialog(
        mobileController: mobileController,
        amount: _finalAmount,
        paymentMethod: _selectedElectronicMethod == 'creditcard' ? 'Credit Card' : 'E-Money',
      ),
    );
  }

  Future<bool> _showElectronicPaymentProcessing() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ElectronicPaymentProcessingDialog(
        amount: _finalAmount,
        mobileNumber: _mobileController.text,
        paymentMethod: _selectedElectronicMethod == 'creditcard' ? 'Credit Card' : 'E-Money',
      ),
    ) ?? false;
  }

  void _clearForm() {
    setState(() {
      _customerNameController.clear();
      _tinController.clear();
      _mobileController.clear();
      _notesController.clear();
      _selectedProducts.clear();
      _isElectronicPayment = false;
      _tinValidationResult = null;
      _totalAmount = 0.0;
      _vatAmount = 0.0;
      _finalAmount = 0.0;
      _appliedVatRate = 'A';
      _currentStep = 0;
      _selectedElectronicMethod = 'creditcard';
    });
  }

  void _showVatBreakdown() {
    showDialog(
      context: context,
      builder: (context) => const VatCalculationDialog(),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Sale',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (_currentStep == 1)
            IconButton(
              icon: const Icon(Icons.calculate),
              onPressed: _showVatBreakdown,
              tooltip: 'VAT Calculation',
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress Stepper
          _buildStepper(),
          
          // Content
          Expanded(
            child: _buildStepContent(),
          ),
          
          // Bottom Navigation
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _StepperCircle(number: 1, label: 'Products', isActive: _currentStep >= 0),
          _StepperLine(isActive: _currentStep >= 1),
          _StepperCircle(number: 2, label: 'Customer', isActive: _currentStep >= 1),
          _StepperLine(isActive: _currentStep >= 2),
          _StepperCircle(number: 3, label: 'Review', isActive: _currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildProductsStep();
      case 1:
        return _buildCustomerStep();
      case 2:
        return _buildReviewStep();
      default:
        return _buildProductsStep();
    }
  }

  Widget _buildProductsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Products',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products to create a sale',
            style: GoogleFonts.inter(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          
          if (_selectedProducts.isEmpty)
            _EmptyProductsState(onAddProduct: _addProduct)
          else
            Column(
              children: [
                ..._selectedProducts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  return _ProductItemCard(
                    product: product,
                    onRemove: () => _removeProduct(index),
                    onQuantityChanged: (newQuantity) => _updateProductQuantity(index, newQuantity),
                  );
                }),
                const SizedBox(height: 16),
                _ProductsSummary(
                  itemCount: _selectedProducts.length,
                  totalAmount: _totalAmount,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Information',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter customer details and payment method',
            style: GoogleFonts.inter(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Payment Method Toggle
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentMethodChip(
                          title: 'Cash',
                          icon: Icons.money,
                          isSelected: !_isElectronicPayment,
                          onTap: () {
                            setState(() {
                              _isElectronicPayment = false;
                            });
                            _calculateTotals();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PaymentMethodChip(
                          title: 'Electronic',
                          icon: Icons.credit_card,
                          isSelected: _isElectronicPayment,
                          onTap: () {
                            setState(() {
                              _isElectronicPayment = true;
                            });
                            _calculateTotals();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Electronic Payment Method Selection
                  if (_isElectronicPayment) ...[
                    Text(
                      'Select Electronic Payment Method',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ElectronicMethodChip(
                            title: 'Credit Card',
                            icon: Icons.credit_card,
                            isSelected: _selectedElectronicMethod == 'creditcard',
                            onTap: () {
                              setState(() {
                                _selectedElectronicMethod = 'creditcard';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ElectronicMethodChip(
                            title: 'E-Money',
                            icon: Icons.phone_android,
                            isSelected: _selectedElectronicMethod == 'emoney',
                            onTap: () {
                              setState(() {
                                _selectedElectronicMethod = 'emoney';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Customer Name (appears for both cash and electronic)
                  TextFormField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // TIN Input (optional for electronic payments)
                  if (_isElectronicPayment) ...[
                    TextFormField(
                      controller: _tinController,
                      decoration: InputDecoration(
                        labelText: 'Customer TIN (Optional)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.badge),
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
                      _TinValidationStatus(result: _tinValidationResult!),
                    
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Notes Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Additional Notes (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Add any additional notes about this sale...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Sale',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review the sale details before processing',
            style: GoogleFonts.inter(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          
          // Sale Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sale Summary',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer Info
                  if (_customerNameController.text.isNotEmpty)
                    _ReviewRow('Customer:', _customerNameController.text),
                  if (_tinController.text.isNotEmpty)
                    _ReviewRow('TIN:', _tinController.text),
                  _ReviewRow('Payment Method:', 
                    _isElectronicPayment 
                      ? (_selectedElectronicMethod == 'creditcard' ? 'Credit Card' : 'E-Money')
                      : 'Cash'
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Products List
                  Text(
                    'Products (${_selectedProducts.length})',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  for (final product in _selectedProducts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${product.productName} × ${product.quantity}',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          ),
                          Text(
                            'TZS ${_formatCurrency(product.unitPrice * product.quantity)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Totals
                  _ReviewRow('Subtotal:', 'TZS ${_formatCurrency(_totalAmount)}'),
                  _ReviewRow('VAT ${_appliedVatRate == 'A' ? '18%' : '16%'}:', 'TZS ${_formatCurrency(_vatAmount)}'),
                  const SizedBox(height: 8),
                  _ReviewRow(
                    'Total Amount:',
                    'TZS ${_formatCurrency(_finalAmount)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _getNextButtonAction(),
              child: Text(_getNextButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _getNextButtonAction() {
    switch (_currentStep) {
      case 0:
        return _selectedProducts.isNotEmpty ? _nextStep : null;
      case 1:
        return _nextStep;
      case 2:
        return _processSale;
      default:
        return null;
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Continue to Customer';
      case 1:
        return 'Review Sale';
      case 2:
        return _isElectronicPayment ? 'Process Payment' : 'Complete Sale';
      default:
        return 'Next';
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

// Success Dialog with Printer Persistence
class _SaleSuccessDialog extends StatelessWidget {
  final Sale sale;
  final VoidCallback onNewSale;
  final VoidCallback onDashboard;
  final bool hasSavedPrinter;

  const _SaleSuccessDialog({
    required this.sale,
    required this.onNewSale,
    required this.onDashboard,
    this.hasSavedPrinter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Successful!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sale completed successfully',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'TZS ${_formatCurrency(sale.totalAmount)}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receipt: ${sale.receiptNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Quick Print button if saved printer exists
            if (hasSavedPrinter) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Quick Print to Saved Printer'),
                onPressed: () => _quickPrint(context),
              ),
            ],

            const SizedBox(height: 16),

            // Share + Print buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    onPressed: () => _shareReceipt(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print'),
                    onPressed: () => _printReceipt(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => TraReceipt(sale: sale),
                      );
                    },
                    child: const Text('View Receipt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onNewSale,
                    child: const Text('New Sale'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDashboard,
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  // QUICK PRINT to saved printer
  void _quickPrint(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Connecting to saved printer...'),
            ],
          ),
        ),
      );

      // Try connecting to saved printer
      final device = await BluetoothPrinterService.connectToSavedPrinter();

      if (device != null && context.mounted) {
        Navigator.pop(context); // close loading
        await BluetoothPrinterService.printToDevice(device, sale, savePrinter: false);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printed to saved printer successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          Navigator.pop(context); // close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not connect to saved printer. Please select a printer.'),
              backgroundColor: Colors.orange,
            ),
          );
          _printReceipt(context); // fallback
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quick print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _printReceipt(context); // fallback
      }
    }
  }

  void _shareReceipt(BuildContext context) async {
    try {
      await ReceiptShareService.shareReceiptAsText(sale);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _printReceipt(BuildContext context) async {
    try {
      final success = await showDialog<bool>(
        context: context,
        builder: (context) => PrinterSelectionDialog(sale: sale),
      );

      if (success != true) return;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

// Mobile Number Input Dialog
class _MobileNumberInputDialog extends StatefulWidget {
  final TextEditingController mobileController;
  final double amount;
  final String paymentMethod;

  const _MobileNumberInputDialog({
    required this.mobileController,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<_MobileNumberInputDialog> createState() => _MobileNumberInputDialogState();
}

class _MobileNumberInputDialogState extends State<_MobileNumberInputDialog> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.paymentMethod == 'Credit Card' ? Icons.credit_card : Icons.phone_android,
              size: 48,
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.paymentMethod} Payment',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.paymentMethod == 'Credit Card' 
                ? 'Enter customer mobile number for payment'
                : 'Enter customer mobile number for E-Money payment',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Amount: TZS ${_formatCurrency(widget.amount)}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: widget.mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixText: '+255 ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '712345678',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter mobile number';
                  }
                  if (value.length < 9) {
                    return 'Enter valid mobile number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
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
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.pop(context, widget.mobileController.text);
                      }
                    },
                    child: const Text('Proceed to Pay'),
                  ),
                ),
              ],
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
}

// Electronic Payment Processing Dialog
class _ElectronicPaymentProcessingDialog extends StatefulWidget {
  final double amount;
  final String mobileNumber;
  final String paymentMethod;

  const _ElectronicPaymentProcessingDialog({
    required this.amount,
    required this.mobileNumber,
    required this.paymentMethod,
  });

  @override
  State<_ElectronicPaymentProcessingDialog> createState() => _ElectronicPaymentProcessingDialogState();
}

class _ElectronicPaymentProcessingDialogState extends State<_ElectronicPaymentProcessingDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _status = 'Initiating Payment...';
  int _currentStep = 0;
  double _progressValue = 0.0;
  late List<String> _processingSteps;
  late MobileProviderInfo _providerInfo;

  @override
  void initState() {
    super.initState();
    
    // Identify the mobile provider
    _providerInfo = MobileProviderService.identifyProvider(widget.mobileNumber);
    
    // Initialize processing steps after widget is available
    _processingSteps = [
      'Initiating Payment...',
      'Sending Request to +255 ${_getMaskedMobileNumber()}',
      'Waiting for Customer Confirmation...',
      'Processing Transaction...',
      'Verifying Payment...',
      'Payment Successful!'
    ];
    
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _startPaymentProcess();
  }

  String _getMaskedMobileNumber() {
    if (widget.mobileNumber.length <= 4) return widget.mobileNumber;
    final visiblePart = widget.mobileNumber.substring(widget.mobileNumber.length - 4);
    return 'XXX $visiblePart';
  }

  void _startPaymentProcess() async {
    _controller.forward();

    // Simulate payment processing steps with realistic timing
    for (int i = 1; i < _processingSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _status = _processingSteps[i];
          _currentStep = i;
          _progressValue = i / (_processingSteps.length - 1);
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getProgressColor() {
    if (_currentStep < 2) return Colors.blue;
    if (_currentStep < 4) return Colors.orange;
    return Colors.green;
  }

  IconData _getStatusIcon() {
    if (_currentStep < _processingSteps.length - 1) {
      return widget.paymentMethod == 'Credit Card' ? Icons.credit_card : Icons.phone_android;
    }
    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Progress Circle
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _progressValue,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                Icon(
                  _getStatusIcon(),
                  size: 40,
                  color: _getProgressColor(),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Status Text
            Text(
              _status,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _getProgressColor(),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Amount and Mobile Info with Provider
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'TZS ${_formatCurrency(widget.amount)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Mobile number with provider info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _providerInfo.providerIcon,
                        color: _providerInfo.providerColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mobile: +255 ${_getMaskedMobileNumber()}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Provider name
                  if (_providerInfo.provider != MobileProvider.unknown)
                    Text(
                      'Provider: ${_providerInfo.providerName}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _providerInfo.providerColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  Text(
                    'Method: ${widget.paymentMethod}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Linear Progress Bar
            LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            
            const SizedBox(height: 12),
            
            // Step Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${_currentStep + 1} of ${_processingSteps.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${(_progressValue * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getProgressColor(),
                  ),
                ),
              ],
            ),
            
            if (_currentStep == _processingSteps.length - 1) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment completed successfully',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
}

// Mobile Provider Service (simplified version)
class MobileProviderService {
  static MobileProviderInfo identifyProvider(String phoneNumber) {
    // Simplified implementation - you can expand this with actual prefix logic
    return MobileProviderInfo(
      provider: MobileProvider.unknown,
      confidence: 0.0,
      formattedNumber: phoneNumber,
    );
  }
}

class MobileProviderInfo {
  final MobileProvider provider;
  final double confidence;
  final String formattedNumber;
  final String? prefix;

  const MobileProviderInfo({
    required this.provider,
    required this.confidence,
    required this.formattedNumber,
    this.prefix,
  });

  String get providerName => 'Unknown';
  IconData get providerIcon => Icons.help_outline;
  Color get providerColor => Colors.grey;
}

enum MobileProvider {
  vodacom,
  airtel,
  tigo,
  halotel,
  unknown,
}

// Supporting Widget Classes
class _StepperCircle extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;

  const _StepperCircle({
    required this.number,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: GoogleFonts.inter(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isActive ? Colors.blue : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _StepperLine extends StatelessWidget {
  final bool isActive;

  const _StepperLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isActive ? Colors.blue : Colors.grey.shade300,
      ),
    );
  }
}

class _ProductsSummary extends StatelessWidget {
  final int itemCount;
  final double totalAmount;

  const _ProductsSummary({
    required this.itemCount,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  'TZS ${_formatCurrency(totalAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.shopping_cart_checkout,
              color: Colors.blue.shade700,
              size: 40,
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
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _ReviewRow(this.label, this.value, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 20),
              const SizedBox(width: 8),
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

class _ElectronicMethodChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ElectronicMethodChip({
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.grey.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinValidationStatus extends StatelessWidget {
  final TinValidationResult result;

  const _TinValidationStatus({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.isValid ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.isValid ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.isValid ? Icons.verified : Icons.error,
            color: result.isValid ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isValid ? 'Valid TIN' : 'Invalid TIN',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: result.isValid ? Colors.green : Colors.red,
                  ),
                ),
                if (result.isValid) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Taxpayer: ${result.tradingName.isNotEmpty ? result.tradingName : '${result.firstName} ${result.lastName}'}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  Text(
                    'VAT Status: ${result.hasVAT ? 'Registered' : 'Not Registered'}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  final VoidCallback onAddProduct;

  const _EmptyProductsState({required this.onAddProduct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Products Added',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products to create a sale',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAddProduct,
            child: const Text('Add First Product'),
          ),
        ],
      ),
    );
  }
}

class _ProductItemCard extends StatelessWidget {
  final SaleItem product;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;

  const _ProductItemCard({
    required this.product,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    product.productCode,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TZS ${_formatCurrency(product.unitPrice)} × ${product.quantity} = TZS ${_formatCurrency(product.unitPrice * product.quantity)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            // Quantity Controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => onQuantityChanged(product.quantity - 1),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    product.quantity.toString(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => onQuantityChanged(product.quantity + 1),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
            
            // Remove Button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0);
  }
}

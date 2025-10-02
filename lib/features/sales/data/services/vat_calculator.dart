import 'package:business_management_system/features/sales/data/models/sale_models.dart';

class VatCalculator {
  static VatCalculationResult calculateDualVat({
    required double originalAmount,
    required String customerTin,
    required bool isElectronicPayment,
    required bool isVatRegistered,
  }) {
    if (!isElectronicPayment) {
      // Cash payment - always 18% VAT
      final vatAmount = (originalAmount * 18) / 118;
      final vatExclusiveAmount = originalAmount - vatAmount;
      
      return VatCalculationResult(
        originalAmount: originalAmount,
        vatExclusiveAmount: vatExclusiveAmount,
        newVatAmount: vatAmount,
        newTotalAmount: originalAmount,
        appliedVatRate: 'A', // 18% VAT rate code
      );
    }

    if (customerTin.isEmpty) {
      // Electronic payment without TIN - 16% VAT
      return _calculateVatAtRate(originalAmount, 16.0, 'B');
    }

    // Electronic payment with TIN
    if (isVatRegistered) {
      // VAT registered - 18% VAT
      return _calculateVatAtRate(originalAmount, 18.0, 'A');
    } else {
      // Non-VAT registered - 16% VAT
      return _calculateVatAtRate(originalAmount, 16.0, 'B');
    }
  }

  static VatCalculationResult _calculateVatAtRate(
    double originalAmount,
    double vatRate,
    String vatRateCode,
  ) {
    // Step 1: Calculate VAT amount at original 18% rate
    final originalVatAmount = (originalAmount * 18) / 118;
    
    // Step 2: Calculate VAT exclusive amount
    final vatExclusiveAmount = originalAmount - originalVatAmount;
    
    // Step 3: Calculate new VAT amount at specified rate
    final newVatAmount = vatExclusiveAmount * (vatRate / 100);
    
    // Step 4: Calculate new total amount
    final newTotalAmount = vatExclusiveAmount + newVatAmount;

    return VatCalculationResult(
      originalAmount: originalAmount,
      vatExclusiveAmount: vatExclusiveAmount,
      newVatAmount: newVatAmount,
      newTotalAmount: newTotalAmount,
      appliedVatRate: vatRateCode,
    );
  }

  static String getVatRateDescription(String vatRateCode) {
    switch (vatRateCode) {
      case 'A':
        return '18% VAT (Standard Rate)';
      case 'B':
        return '16% VAT (Electronic Payment Rate)';
      case 'C':
        return '0% VAT (Exempt)';
      default:
        return 'Unknown VAT Rate';
    }
  }
}
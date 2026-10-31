import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

class UniformCommandBar extends StatelessWidget {
  const UniformCommandBar({
    super.key,
    required this.onPrint,
    required this.onSave,
    this.isPrinting = false,
    this.isSaving = false,
    this.isThermal = false,
    this.saveSuccess = false,
    this.isSwahili = false,
  });

  final VoidCallback? onPrint;
  final VoidCallback? onSave;
  final bool isPrinting;
  final bool isSaving;
  final bool isThermal;
  final bool saveSuccess;
  final bool isSwahili;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Status and Profile Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isThermal
                    ? const Color(0xFF0F172A)
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isThermal ? Icons.receipt_long : Icons.description_outlined,
                    size: 14,
                    color: isThermal ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isThermal ? '80mm POS' : 'A4 Standard',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isThermal ? Colors.white : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            if (saveSuccess) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      isSwahili ? 'Imehifadhiwa' : 'Saved',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSuccessContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // 'Print Now' Spool Handler
            OutlinedButton.icon(
              onPressed: isPrinting ? null : onPrint,
              icon: isPrinting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isThermal ? Icons.receipt_long : Icons.print_outlined,
                      size: 16,
                    ),
              label: Text(
                isPrinting
                    ? (isSwahili ? 'Inachapa...' : 'Printing...')
                    : (isSwahili ? 'Chapisha Sasa' : 'Print Now'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.outline),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 'Save Configuration' Handler
            FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(
                isSaving
                    ? (isSwahili ? 'Inahifadhi...' : 'Saving...')
                    : (isSwahili ? 'Hifadhi Mipangilio' : 'Save Configuration'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

enum PrintSizeProfile {
  a4Standard,
  thermal80mm;

  bool get isThermal => this == PrintSizeProfile.thermal80mm;
}

class PrintProfileSelector extends StatelessWidget {
  const PrintProfileSelector({
    super.key,
    required this.selectedProfile,
    required this.onChanged,
    this.isSwahili = false,
  });

  final PrintSizeProfile selectedProfile;
  final ValueChanged<PrintSizeProfile> onChanged;
  final bool isSwahili;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isSwahili ? 'Umbizo la Printa' : 'Print Size Profile Matrix',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.resolveTextPrimary(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.resolveSurfaceSecondary(context),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                selectedProfile.isThermal ? '80MM ESC/POS' : 'ISO 216 A4',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.resolveTextSecondary(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ProfileCard(
                icon: Icons.picture_as_pdf_outlined,
                title: isSwahili ? 'A4 Standard' : 'A4 Standard (Laser)',
                description: isSwahili
                    ? 'Karatasi ya kawaida A4 kwa ofisi'
                    : 'Standard corporate cut-sheet',
                badgeText: '210 x 297 mm',
                isSelected: selectedProfile == PrintSizeProfile.a4Standard,
                onTap: () => onChanged(PrintSizeProfile.a4Standard),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileCard(
                icon: Icons.receipt_long,
                title: isSwahili
                    ? 'Risiti ya POS (80mm)'
                    : '80mm Continuous Roll',
                description: isSwahili
                    ? 'Printa ya risiti ya dukani (Thermal)'
                    : 'Thermal POS hardware spool',
                badgeText: '80mm Tape',
                isSelected: selectedProfile == PrintSizeProfile.thermal80mm,
                onTap: () => onChanged(PrintSizeProfile.thermal80mm),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badgeText,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String badgeText;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.resolveCardBackground(context))
                : AppColors.resolveSurfaceSecondary(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.resolveBorder(context),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.primaryContainer)
                          : (isDark
                              ? const Color(0xFF334155)
                              : AppColors.surfaceContainer),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.resolveTextSecondary(context),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.resolveSurfaceSecondary(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.resolveTextPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppColors.tertiary,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';
import '../../domain/document_template.dart';

class DocumentSelectorToggle extends StatelessWidget {
  const DocumentSelectorToggle({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.isSwahili = false,
  });

  final DocumentType selectedType;
  final ValueChanged<DocumentType> onChanged;
  final bool isSwahili;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleItem(
              icon: Icons.receipt_long_outlined,
              label: isSwahili ? 'Ankara (Invoice)' : 'Customer Invoice',
              subtitle: isSwahili ? 'Madai & Malipo' : 'Billing & Payment',
              isSelected: selectedType == DocumentType.invoice,
              onTap: () => onChanged(DocumentType.invoice),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ToggleItem(
              icon: Icons.local_shipping_outlined,
              label: isSwahili ? 'Delivery Note' : 'Delivery Note',
              subtitle: isSwahili ? 'Kukabidhi Mzigo' : 'Logistics & Dispatch',
              isSelected: selectedType == DocumentType.deliveryNote,
              onTap: () => onChanged(DocumentType.deliveryNote),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: isSelected
                ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.tertiary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

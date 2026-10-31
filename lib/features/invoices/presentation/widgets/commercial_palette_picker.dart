import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';
import 'color_hex_picker.dart';

class CommercialPalettePreset {
  const CommercialPalettePreset({
    required this.name,
    required this.nameSw,
    required this.primaryHex,
    required this.secondaryHex,
  });

  final String name;
  final String nameSw;
  final String primaryHex;
  final String secondaryHex;
}

class CommercialPalettePicker extends StatelessWidget {
  const CommercialPalettePicker({
    super.key,
    required this.primaryHex,
    required this.secondaryHex,
    required this.onPrimaryChanged,
    required this.onSecondaryChanged,
    this.isSwahili = false,
  });

  final String primaryHex;
  final String secondaryHex;
  final ValueChanged<String> onPrimaryChanged;
  final ValueChanged<String> onSecondaryChanged;
  final bool isSwahili;

  static const List<CommercialPalettePreset> presets = [
    CommercialPalettePreset(
      name: 'Enterprise Classic',
      nameSw: 'Ya Kawaida ya Biashara',
      primaryHex: '#0F172A',
      secondaryHex: '#0D9488',
    ),
    CommercialPalettePreset(
      name: 'Corporate Cobalt',
      nameSw: 'Bluu ya Kiofisi',
      primaryHex: '#1D4ED8',
      secondaryHex: '#475569',
    ),
    CommercialPalettePreset(
      name: 'Sustainable Forest',
      nameSw: 'Kijani ya Mazingira',
      primaryHex: '#15803D',
      secondaryHex: '#059669',
    ),
    CommercialPalettePreset(
      name: 'Retail Crimson',
      nameSw: 'Nyekundu ya Maduka',
      primaryHex: '#B91C1C',
      secondaryHex: '#334155',
    ),
    CommercialPalettePreset(
      name: 'Modern Indigo',
      nameSw: 'Zambarau ya Kisasa',
      primaryHex: '#4338CA',
      secondaryHex: '#D97706',
    ),
  ];

  Color _parseColor(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF0F172A);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isSwahili ? 'Paleti za Biashara' : 'Commercial Theme Palettes',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        // Pre-configured accessible commercial palettes grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isMatch =
                preset.primaryHex.toUpperCase() == primaryHex.toUpperCase() &&
                preset.secondaryHex.toUpperCase() == secondaryHex.toUpperCase();

            final pCol = _parseColor(preset.primaryHex);
            final sCol = _parseColor(preset.secondaryHex);

            return InkWell(
              onTap: () {
                onPrimaryChanged(preset.primaryHex);
                onSecondaryChanged(preset.secondaryHex);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isMatch ? AppColors.surface : AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isMatch ? AppColors.primary : AppColors.outlineVariant,
                    width: isMatch ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: pCol,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: sCol,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSwahili ? preset.nameSw : preset.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: isMatch ? FontWeight.w700 : FontWeight.w500,
                        color: isMatch ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Custom Color Pickers
        ColorHexPicker(
          label: isSwahili ? 'Rangi Kuu (Primary)' : 'Primary Accent Color',
          subtitle: isSwahili
              ? 'Inatumika kwenye vichwa vya nguzo na mistari'
              : 'Used for headers, borders, and main stamps',
          selectedHex: primaryHex,
          onColorChanged: onPrimaryChanged,
        ),
        const SizedBox(height: 14),
        ColorHexPicker(
          label: isSwahili ? 'Rangi ya Pili (Secondary)' : 'Secondary Accent Color',
          subtitle: isSwahili
              ? 'Inatumika kwenye vivuli na viashiria'
              : 'Used for subheadings and highlight tags',
          selectedHex: secondaryHex,
          onColorChanged: onSecondaryChanged,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

class ColorHexPicker extends StatefulWidget {
  const ColorHexPicker({
    super.key,
    required this.label,
    required this.selectedHex,
    required this.onColorChanged,
    this.subtitle,
  });

  final String label;
  final String selectedHex;
  final ValueChanged<String> onColorChanged;
  final String? subtitle;

  @override
  State<ColorHexPicker> createState() => _ColorHexPickerState();
}

class _ColorHexPickerState extends State<ColorHexPicker> {
  late TextEditingController _textController;

  static const List<String> _presets = [
    '#0F172A', // Slate Navy (Default Primary)
    '#0D9488', // Emerald Teal (Default Secondary)
    '#2563EB', // Sapphire Blue
    '#4F46E5', // Royal Indigo
    '#16A34A', // Forest Green
    '#D97706', // Warm Amber
    '#DC2626', // Crimson Red
    '#374151', // Charcoal Gray
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.selectedHex);
  }

  @override
  void didUpdateWidget(covariant ColorHexPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedHex != widget.selectedHex &&
        _textController.text.toUpperCase() != widget.selectedHex.toUpperCase()) {
      _textController.text = widget.selectedHex;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF0F172A);
  }

  void _onPresetTap(String hex) {
    _textController.text = hex;
    widget.onColorChanged(hex);
  }

  void _onTextChange(String value) {
    var clean = value.trim();
    if (!clean.startsWith('#')) {
      clean = '#$clean';
    }
    if (RegExp(r'^#([A-Fa-f0-9]{6})$').hasMatch(clean)) {
      widget.onColorChanged(clean.toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _parseColor(widget.selectedHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.resolveTextPrimary(context),
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
            // Live color indicator chip
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: currentColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Preset color swatches
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((hex) {
            final color = _parseColor(hex);
            final isSelected =
                widget.selectedHex.toUpperCase() == hex.toUpperCase();

            return InkWell(
              onTap: () => _onPresetTap(hex),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : Colors.transparent,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        // Custom HEX text input
        SizedBox(
          height: 38,
          child: TextField(
            controller: _textController,
            onChanged: _onTextChange,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: AppColors.resolveTextPrimary(context),
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'HEX',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.resolveTextSecondary(context),
                  ),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: '#0F172A',
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppColors.resolveTextTertiary(context),
              ),
              filled: true,
              fillColor: AppColors.resolveSurfaceSecondary(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.resolveBorder(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.resolveBorder(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

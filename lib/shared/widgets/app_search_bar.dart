import 'package:flutter/material.dart';

/// Clean search bar with clear button.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.controller,
    this.autofocus = false,
  });

  final String? hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText ?? 'Tafuta...',
        hintStyle: TextStyle(
          fontSize: 14,
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: colors.onSurfaceVariant,
          size: 20,
        ),
        filled: true,
        fillColor: isDark ? colors.surfaceContainerHigh : colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? colors.outline : colors.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? colors.outline : colors.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText ?? 'Tafuta...',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: colors.onSurfaceVariant,
          size: 20,
        ),
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
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

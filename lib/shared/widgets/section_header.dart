import 'package:flutter/material.dart';

/// Section header with title and optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.trailingIcon,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          if (trailing != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailing!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 2),
                      Icon(
                        trailingIcon,
                        size: 16,
                        color: colors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

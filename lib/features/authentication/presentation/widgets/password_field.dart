import 'package:flutter/material.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_semantic_colors.dart';

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.labelText,
    super.key,
    this.validator,
    this.onFieldSubmitted,
    this.helperText,
    this.errorText,
    this.autofillHints,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final String? helperText;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        errorText: widget.errorText,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
          tooltip:
              _visible ? context.loc.hidePassword : context.loc.showPassword,
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
      obscureText: !_visible,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
    );
  }
}

/// Represents the individual policy checks for a password matching the backend.
class PasswordRequirements {
  const PasswordRequirements({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecial,
  });

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecial;

  bool get isMet =>
      hasMinLength && hasUppercase && hasLowercase && hasDigit && hasSpecial;

  factory PasswordRequirements.check(String password) {
    return PasswordRequirements(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasDigit: password.contains(RegExp(r'[0-9]')),
      hasSpecial: password.contains(RegExp(r'[^A-Za-z0-9]')),
    );
  }
}

/// Standard validator that enforces the system-wide password policy.
String? validatePasswordPolicy(BuildContext context, String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return context.loc.passwordRequired;
  }
  final req = PasswordRequirements.check(password);
  if (!req.hasMinLength) {
    return context.loc.passwordTooShort;
  }
  if (!req.hasUppercase) {
    return context.loc.passwordRequiresUppercase;
  }
  if (!req.hasLowercase) {
    return context.loc.passwordRequiresLowercase;
  }
  if (!req.hasDigit) {
    return context.loc.passwordRequiresDigit;
  }
  if (!req.hasSpecial) {
    return context.loc.passwordRequiresSpecial;
  }
  return null;
}

/// Visual live checklist showing status of each password requirement.
class PasswordRequirementsView extends StatelessWidget {
  const PasswordRequirementsView({
    required this.password,
    super.key,
  });

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final loc = context.loc;
    final req = PasswordRequirements.check(password);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>();
    final successColor = semantic?.success ?? const Color(0xFF2E7D32);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: req.isMet
                ? successColor.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RequirementItem(
              isMet: req.hasMinLength,
              label: loc.passwordRuleLength,
            ),
            const SizedBox(height: 4),
            _RequirementItem(
              isMet: req.hasUppercase,
              label: loc.passwordRuleUppercase,
            ),
            const SizedBox(height: 4),
            _RequirementItem(
              isMet: req.hasLowercase,
              label: loc.passwordRuleLowercase,
            ),
            const SizedBox(height: 4),
            _RequirementItem(
              isMet: req.hasDigit,
              label: loc.passwordRuleDigit,
            ),
            const SizedBox(height: 4),
            _RequirementItem(
              isMet: req.hasSpecial,
              label: loc.passwordRuleSpecial,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({
    required this.isMet,
    required this.label,
  });

  final bool isMet;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final successColor = semantic?.success ?? const Color(0xFF2E7D32);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: isMet ? successColor : colors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? colors.onSurface : colors.onSurfaceVariant,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}


/// Heuristic password strength — live feedback only.
enum PasswordStrength { empty, weak, fair, good, strong }

PasswordStrength scorePassword(String password) {
  if (password.isEmpty) {
    return PasswordStrength.empty;
  }
  var score = 0;
  if (password.length >= 8) {
    score++;
  }
  if (password.length >= 12) {
    score++;
  }
  if (password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[a-z]'))) {
    score++;
  }
  if (password.contains(RegExp(r'[0-9]'))) {
    score++;
  }
  if (password.contains(RegExp(r'[^A-Za-z0-9]'))) {
    score++;
  }
  return switch (score) {
    <= 1 => PasswordStrength.weak,
    2 => PasswordStrength.fair,
    <= 4 => PasswordStrength.good,
    _ => PasswordStrength.strong,
  };
}

/// Four-segment strength bar with localized label.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final strength = scorePassword(password);
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final strengthColor = switch (strength) {
      PasswordStrength.empty => colors.onSurfaceVariant,
      PasswordStrength.weak => colors.error,
      PasswordStrength.fair => semantic.warning,
      PasswordStrength.good => colors.secondary,
      PasswordStrength.strong => semantic.success,
    };
    final filledIndex = strength.index;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i <= filledIndex
                      ? strengthColor
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            switch (strength) {
              PasswordStrength.empty => '',
              PasswordStrength.weak => loc.strengthWeak,
              PasswordStrength.fair => loc.strengthFair,
              PasswordStrength.good => loc.strengthGood,
              PasswordStrength.strong => loc.strengthStrong,
            },
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: strengthColor,
            ),
          ),
        ],
      ),
    );
  }
}

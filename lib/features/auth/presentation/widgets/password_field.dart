import 'package:flutter/material.dart';

import '../../../../l10n/loc.dart';

/// Password input with a show/hide toggle. Keeps [obscureText] local so pages
/// never track visibility themselves.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.labelText,
    super.key,
    this.validator,
    this.onFieldSubmitted,
    this.helperText,
    this.autofillHints,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final String? helperText;
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
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_visible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          tooltip: _visible ? context.loc.hidePassword : context.loc.showPassword,
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

/// Heuristic password strength used only for live feedback — the backend
/// remains the authority on the actual policy.
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

const _strengthColors = {
  PasswordStrength.empty: Colors.grey,
  PasswordStrength.weak: Colors.red,
  PasswordStrength.fair: Colors.orange,
  PasswordStrength.good: Colors.lightGreen,
  PasswordStrength.strong: Colors.green,
};

/// Four-segment strength bar with a localized label, shown while typing.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final strength = scorePassword(password);
    if (strength == PasswordStrength.empty) {
      return const SizedBox.shrink();
    }
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
                      ? _strengthColors[strength]
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
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
              color: _strengthColors[strength],
            ),
          ),
        ],
      ),
    );
  }
}

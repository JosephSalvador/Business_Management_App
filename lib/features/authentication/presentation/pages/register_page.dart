import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_brand_mark.dart';
import '../widgets/auth_error_mapper.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/language_switcher.dart';
import '../widgets/password_field.dart';

/// Registration page with Owner/Staff toggle.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isStaff = false;
  bool _acceptedTerms = false;
  bool _busy = false;
  AuthFieldErrors? _errors;

  @override
  void dispose() {
    for (final controller in [
      _fullNameController,
      _emailController,
      _phoneController,
      _inviteCodeController,
      _passwordController,
      _confirmController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    if (!_acceptedTerms) {
      setState(() =>
          _errors = AuthFieldErrors(banner: context.loc.acceptTermsRequired));
      return;
    }
    setState(() {
      _busy = true;
      _errors = null;
    });

    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (_isStaff) {
        await controller.registerStaff(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          phone: _phoneController.text,
          invitationCode: _inviteCodeController.text,
        );
      } else {
        await controller.register(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          phone: _phoneController.text,
        );
      }
    } on AppException catch (error) {
      setState(() => _errors = mapAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final errors = _errors ?? AuthFieldErrors();

    return AuthBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: AuthFormCard(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [LanguageSwitcher()],
                  ),
                  const SizedBox(height: 8),
                  const AuthBrandMark(),
                  const SizedBox(height: 16),
                  Text(
                    loc.registerHeading,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.resolveTextPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Owner / Staff toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: loc.registerTabOwner,
                            selected: !_isStaff,
                            onTap: () => setState(() => _isStaff = false),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: loc.registerTabStaff,
                            selected: _isStaff,
                            onTap: () => setState(() => _isStaff = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: loc.fullNameLabel,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      errorText: errorForField(errors, const ['FullName']),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? loc.fullNameRequired
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: loc.emailLabel,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      errorText: errorForField(errors, const ['Email']),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return loc.emailRequired;
                      if (!email.contains('@')) return loc.emailInvalid;
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: loc.phoneLabel,
                      helperText: loc.phoneHelper,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      errorText: errorForField(errors, const ['Phone']),
                    ),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final phone =
                          (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
                      if (phone.isEmpty) return loc.phoneRequired;
                      final digits =
                          phone.startsWith('+') ? phone.substring(1) : phone;
                      final valid = RegExp(r'^\d{9,15}$').hasMatch(digits);
                      if (!valid) return loc.phoneInvalid;
                      return null;
                    },
                  ),
                  if (_isStaff) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _inviteCodeController,
                      decoration: InputDecoration(
                        labelText: loc.inviteCodeLabel,
                        helperText: loc.inviteCodeHelper,
                        prefixIcon:
                            const Icon(Icons.vpn_key_outlined, size: 20),
                        errorText:
                            errorForField(errors, const ['InvitationCode']),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final code = (value ?? '').trim();
                        if (code.isEmpty) return loc.inviteCodeRequired;
                        if (code.length != 8) return loc.inviteCodeShort;
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _passwordController,
                    labelText: loc.passwordLabel,
                    helperText: loc.passwordHelper,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value ?? '').length < 8 ? loc.passwordTooShort : null,
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _passwordController,
                    builder: (_, value, __) =>
                        PasswordStrengthMeter(password: value.text),
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _confirmController,
                    labelText: loc.confirmPasswordLabel,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) => value == _passwordController.text
                        ? null
                        : context.loc.passwordsDiffer,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Checkbox(
                          value: _acceptedTerms,
                          onChanged: (value) =>
                              setState(() => _acceptedTerms = value ?? false),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push(Routes.terms),
                          child: Text.rich(
                            TextSpan(
                              text: loc.acceptTermsPrefix,
                              children: [
                                TextSpan(
                                  text: loc.acceptTermsLink,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(text: loc.acceptTermsSuffix),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.resolveTextSecondary(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (errors.banner != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        errors.banner!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : Text(loc.createAccount),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text(loc.haveAccount),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? colors.primary.withValues(alpha: 0.25) : colors.surface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected && isDark
              ? Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (isDark ? Colors.white : AppColors.primary)
                : AppColors.resolveTextSecondary(context),
          ),
        ),
      ),
    );
  }
}

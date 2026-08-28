import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../l10n/loc.dart';
import '../widgets/auth_error_mapper.dart';
import '../widgets/language_switcher.dart';
import '../widgets/password_field.dart';

/// Registration has two paths.
///
/// Owner: creates the business owner account; the business itself (tenant + HQ
/// branch + owner role) is provisioned by the backend and its name is set in
/// the onboarding wizard afterwards — the register form only collects identity.
///
/// Staff: redeems an owner-issued invitation code and is attached to the
/// owner's company with the Staff role — no new business is created.
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
    if (!_formKey.currentState!.validate() || _busy) {
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _errors =
          AuthFieldErrors(banner: context.loc.acceptTermsRequired));
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
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final errors = _errors ?? AuthFieldErrors();
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.registerTitle),
        actions: const [LanguageSwitcher()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loc.registerHeading,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(loc.registerTabOwner),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(loc.registerTabStaff),
                        ),
                      ],
                      selected: {_isStaff},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          setState(() => _isStaff = selection.first),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: loc.fullNameLabel,
                        border: const OutlineInputBorder(),
                        errorText: errorForField(errors, const ['FullName']),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? loc.fullNameRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: loc.emailLabel,
                        border: const OutlineInputBorder(),
                        errorText: errorForField(errors, const ['Email']),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return loc.emailRequired;
                        }
                        if (!email.contains('@')) {
                          return loc.emailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: loc.phoneLabel,
                        helperText: loc.phoneHelper,
                        border: const OutlineInputBorder(),
                        errorText: errorForField(errors, const ['Phone']),
                      ),
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final phone =
                            (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
                        if (phone.isEmpty) {
                          return loc.phoneRequired;
                        }
                        final digits = phone.startsWith('+')
                            ? phone.substring(1)
                            : phone;
                        final valid = RegExp(r'^\d{9,15}$').hasMatch(digits);
                        if (!valid) {
                          return loc.phoneInvalid;
                        }
                        return null;
                      },
                    ),
                    if (_isStaff) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _inviteCodeController,
                        decoration: InputDecoration(
                          labelText: loc.inviteCodeLabel,
                          helperText: loc.inviteCodeHelper,
                          border: const OutlineInputBorder(),
                          errorText:
                              errorForField(errors, const ['InvitationCode']),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final code = (value ?? '').trim();
                          if (code.isEmpty) {
                            return loc.inviteCodeRequired;
                          }
                          if (code.length != 8) {
                            return loc.inviteCodeShort;
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _passwordController,
                      labelText: loc.passwordLabel,
                      helperText: loc.passwordHelper,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value ?? '').length < 8
                          ? loc.passwordTooShort
                          : null,
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _passwordController,
                      builder: (_, value, __) =>
                          PasswordStrengthMeter(password: value.text),
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _confirmController,
                      labelText: loc.confirmPasswordLabel,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => value == _passwordController.text
                          ? null
                          : context.loc.passwordsDiffer,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (value) =>
                              setState(() => _acceptedTerms = value ?? false),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push(Routes.terms),
                            child: Text.rich(
                              TextSpan(
                                text: loc.acceptTermsPrefix,
                                children: [
                                  TextSpan(
                                    text: loc.acceptTermsLink,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(text: loc.acceptTermsSuffix),
                                ],
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(loc.createAccount),
                    ),
                    const SizedBox(height: 12),
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
      ),
    );
  }
}

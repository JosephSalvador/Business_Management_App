import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../l10n/loc.dart';
import '../widgets/auth_brand_mark.dart';
import '../widgets/auth_error_mapper.dart';
import '../widgets/language_switcher.dart';
import '../widgets/password_field.dart';

/// Swahili-first login screen. One identifier field accepts either the email
/// address or the phone number. Errors are shown from typed [AppException]s —
/// never raw stack traces or response bodies.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  AuthFieldErrors? _errors;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errors = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).login(
            identifier: _identifierController.text,
            password: _passwordController.text,
          );
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
    final identifierError =
        errorForField(_errors ?? AuthFieldErrors(), const ['Email', 'Phone']);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [LanguageSwitcher()],
                    ),
                    const Center(child: AuthBrandMark()),
                    const SizedBox(height: 8),
                    Text(
                      loc.loginSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _identifierController,
                      decoration: InputDecoration(
                        labelText: loc.identifierLabel,
                        border: const OutlineInputBorder(),
                        errorText: identifierError,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? loc.identifierRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _passwordController,
                      labelText: loc.passwordLabel,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) =>
                          (value ?? '').isEmpty ? loc.passwordRequired : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(Routes.forgotPassword),
                        child: Text(loc.forgotPassword),
                      ),
                    ),
                    if (_errors?.banner != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errors!.banner!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 8),
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
                          : Text(loc.signIn),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go(Routes.register),
                      child: Text(loc.noAccount),
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

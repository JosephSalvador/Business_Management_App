import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';
import '../../application/auth_controller.dart';
import '../../data/auth_providers.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/code_input_field.dart';

/// The second step of sign-in: the password was correct but a second factor is
/// required before any token exists.
///
/// Accepts either an authenticator code or a printed recovery code, because a
/// cheap handset with a cracked screen can show a code the user cannot easily
/// type into another app. The two are deliberately separate choices rather than
/// one field that guesses, so a recovery code is never silently submitted as a
/// TOTP attempt (or the reverse).
///
/// The pending challenge is read from [AuthNeedsTwoFactor] rather than passed
/// in, so this screen cannot be reached without a live challenge having been
/// issued to that account. A wrong code stays on this screen: the challenge is
/// still alive server-side and only an expired one sends the user back.
class TwoFactorPage extends ConsumerStatefulWidget {
  const TwoFactorPage({super.key});

  @override
  ConsumerState<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends ConsumerState<TwoFactorPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _useRecoveryCode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    final expected = _useRecoveryCode ? 10 : 6;
    if (code.length != expected || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyTwoFactor(
            code: code,
            useRecoveryCode: _useRecoveryCode,
          );
      // Success and expiry both change the auth state, which the router turns
      // into navigation; there is nothing left to do here.
    } on AppException catch (error) {
      if (!mounted) return;
      // Only a rejected code lands here. A consumed challenge throws
      // UnauthorizedException and the controller has already moved to
      // AuthUnauthenticated, so this screen is on its way out.
      setState(() {
        _busy = false;
        _error = error.message;
      });
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  void _toggleMode() {
    setState(() {
      _useRecoveryCode = !_useRecoveryCode;
      _error = null;
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final auth = ref.watch(authControllerProvider);

    return AuthBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: AuthFormCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.phonelink_lock_outlined,
                  size: 40,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  loc.mfaTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  auth is AuthNeedsTwoFactor && auth.email.isNotEmpty
                      ? loc.mfaCodeForAccount(auth.email)
                      : loc.mfaCodePrompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CodeInputField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_busy,
                  digitCount: _useRecoveryCode ? 10 : 6,
                  allowLetters: _useRecoveryCode,
                  label: _useRecoveryCode
                      ? loc.mfaRecoveryCodeLabel
                      : loc.mfaCodeLabel,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Text(
                  _useRecoveryCode ? loc.mfaRecoveryCodeHint : loc.mfaTotpHint,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.commonNext),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _toggleMode,
                  child: Text(
                    _useRecoveryCode
                        ? loc.mfaUseAuthenticator
                        : loc.mfaUseRecoveryCode,
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .cancelTwoFactor(),
                  child: Text(loc.mfaBackToLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

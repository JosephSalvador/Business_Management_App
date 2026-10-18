import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_brand_mark.dart';
import '../widgets/auth_error_mapper.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/fast_unlock_panel.dart';
import '../widgets/language_switcher.dart';
import '../../../../core/platform/ios_install_prompt_banner.dart';
import '../widgets/password_field.dart';
import '../widgets/quick_pin_setup_sheet.dart';

/// M-Pesa-style auth screen: a trusted device opens straight into the security
/// prompt (fingerprint and/or inline PIN pad). The username/password form is
/// only one tap away.
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

  bool _fastMode = false;
  bool _trusted = false;
  bool _hasPin = false;
  bool _biometricAvailable = false;
  String? _firstName;
  String? _unlockError;

  bool get _hasFastFactor => _biometricAvailable || _hasPin;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      if (auth is AuthUnauthenticated && auth.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.message!),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _checkAvailability();
    });
  }

  Future<void> _checkAvailability() async {
    final offlineStore = ref.read(offlineCredentialStoreProvider);
    final biometricGate = ref.read(biometricAuthGateProvider);

    final trusted = await offlineStore.hasValidQuickUnlock();
    final hasPin = await offlineStore.hasUnlockPin();
    final isQuickPinEnabled = await offlineStore.isQuickPinEnabled();
    final isBiometricOptedIn = await offlineStore.isBiometricEnabled();
    final biometricHardwareAvailable = await biometricGate.isAvailable();
    final fullName = await offlineStore.getCachedFullName();

    final biometricReady = biometricHardwareAvailable && isBiometricOptedIn;
    final canFastLogin = trusted && (isQuickPinEnabled || biometricReady);

    if (!mounted) return;
    setState(() {
      _trusted = trusted;
      _hasPin = hasPin && isQuickPinEnabled;
      _biometricAvailable = biometricReady;
      _firstName = _firstToken(fullName);
      _fastMode = canFastLogin;
    });

    if (canFastLogin && biometricReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fastMode) _fingerprint();
      });
    }
  }

  String? _firstToken(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Runs a fast-unlock action, surfacing failures as the inline panel error.
  Future<void> _runFastAction(Future<void> Function() action) async {
    if (_busy) return;
    final before = ref.read(authControllerProvider);
    final beforeMessage = before is AuthUnauthenticated ? before.message : null;
    setState(() {
      _busy = true;
      _unlockError = null;
    });
    String? thrown;
    try {
      await action();
    } on AppException catch (error) {
      thrown = error.message;
    } finally {
      if (mounted) {
        final after = ref.read(authControllerProvider);
        String? message = thrown;
        if (message == null &&
            after is AuthUnauthenticated &&
            after.message != null &&
            after.message != beforeMessage) {
          message = after.message;
        }
        setState(() {
          _busy = false;
          if (message != null) _unlockError = message;
        });
      }
    }
  }

  Future<void> _fingerprint() => _runFastAction(
      () => ref.read(authControllerProvider.notifier).loginWithBiometric());

  Future<void> _pin(String pin) => _runFastAction(
      () => ref.read(authControllerProvider.notifier).loginWithPin(pin: pin));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _errors = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).login(
            identifier: _identifierController.text,
            password: _passwordController.text,
          );
      final auth = ref.read(authControllerProvider);
      if (auth is AuthAuthenticated && mounted) {
        final offlineStore = ref.read(offlineCredentialStoreProvider);
        final hasPin = await offlineStore.hasUnlockPin();
        if (!hasPin && mounted) {
          final biometricGate = ref.read(biometricAuthGateProvider);
          final biometricHardware = await biometricGate.isAvailable();
          final biometricLabel = await biometricGate.biometricLabel();
          if (!mounted) return;

          final wantSetup = await showQuickPinPromptDialog(
            context,
            biometricLabel: biometricLabel,
            biometricSupported: biometricHardware,
          );

          if (wantSetup == true && mounted) {
            await showQuickPinSetupSheet(
              context,
              biometricSupported: biometricHardware,
              biometricLabel: biometricLabel,
              onSave: ({required pin, required enableBiometric}) async {
                await ref.read(authControllerProvider.notifier).enableQuickPin(
                      pin: pin,
                      enableBiometric: enableBiometric,
                    );
              },
            );
          }
        }
      }
    } on AppException catch (error) {
      setState(() => _errors = mapAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IosInstallPromptBanner(),
              AuthFormCard(
                child: _fastMode && _hasFastFactor
                    ? _buildFastUnlock(context)
                    : _buildAccountForm(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFastUnlock(BuildContext context) {
    final theme = Theme.of(context);
    final greeting =
        _firstName != null ? 'Habari, $_firstName!' : 'Karibu tena';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [LanguageSwitcher()],
        ),
        const SizedBox(height: 16),
        const AuthBrandMark(),
        const SizedBox(height: 20),
        Text(
          greeting,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Thibitisha utambulisho wako ili kuingia',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.resolveTextSecondary(context),
          ),
        ),
        const SizedBox(height: 20),
        FastUnlockPanel(
          biometricAvailable: _biometricAvailable,
          showPinPad: true,
          busy: _busy,
          errorMessage: _unlockError,
          label: 'Ingiza PIN ya tarakimu 4',
          onFingerprint: _fingerprint,
          onPin: _pin,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _fastMode = false;
                    _unlockError = null;
                  }),
          child: const Text('Ingia kwa nenosiri'),
        ),
      ],
    );
  }

  Widget _buildAccountForm(BuildContext context) {
    final loc = context.loc;
    final identifierError =
        errorForField(_errors ?? AuthFieldErrors(), const ['Email', 'Phone']);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [LanguageSwitcher()],
          ),
          const SizedBox(height: 16),
          const AuthBrandMark(),
          const SizedBox(height: 8),
          Text(
            loc.loginSubtitle,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.resolveTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          if (_trusted && _hasFastFactor) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _fastMode = true;
                        _unlockError = null;
                      }),
              child: const Text('Tumia Kidole au PIN'),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _identifierController,
            decoration: InputDecoration(
              labelText: loc.identifierLabel,
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              errorText: identifierError,
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? loc.identifierRequired : null,
          ),
          const SizedBox(height: 14),
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
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => context.push(Routes.forgotPassword),
                child: Text(loc.forgotPassword),
              ),
            ),
          ),
          if (_errors?.banner != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errors!.banner!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
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
                : Text(
                    loc.signIn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go(Routes.register),
            child: Text(
              loc.noAccount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push(Routes.download),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C48C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00C48C).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.install_mobile_rounded, size: 16, color: Color(0xFF00C48C)),
                    SizedBox(width: 6),
                    Text(
                      'Pakua App ya Simu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C48C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

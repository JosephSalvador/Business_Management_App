import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_brand_mark.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/fast_unlock_panel.dart';

/// Fast-factor unlock screen shown when the app is idle/background-locked.
///
/// The session is already trusted: unlock with the 4-digit PIN or native biometric match.
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  bool _busy = false;
  bool _biometricAvailable = false;
  bool _hasUnlockPin = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeFactors());
  }

  Future<void> _probeFactors() async {
    final biometricGate = ref.read(biometricAuthGateProvider);
    final store = ref.read(offlineCredentialStoreProvider);
    final biometricHardware = await biometricGate.isAvailable();
    final biometricOptedIn = await store.isBiometricEnabled();
    final isBiometric = biometricHardware && biometricOptedIn;
    final hasUnlockPin = await store.hasUnlockPin();
    if (mounted) {
      setState(() {
        _biometricAvailable = isBiometric;
        _hasUnlockPin = hasUnlockPin;
      });
      // Auto-trigger native biometric prompt if user enabled biometric!
      if (isBiometric) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _unlockWithBiometric();
        });
      }
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    await ref.read(authControllerProvider.notifier).unlock();
    if (mounted) {
      setState(() => _busy = false);
      final auth = ref.read(authControllerProvider);
      if (auth is AuthLocked) {
        setState(
            () => _message = 'Uthibitisho wa kidole haukufanikiwa. Ingiza PIN.');
      }
    }
  }

  Future<void> _unlockWithPin(String pin) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).unlockWithPin(pin: pin);
    } on AppException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logoutToLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final title = isSw ? 'Kipindi Kimesitishwa' : 'Session Paused';
    final subtitle = isSw
        ? 'Thibitisha utambulisho wako ili kuendelea na kazi yako'
        : 'Confirm your identity to resume your work';

    return AuthBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: AuthFormCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBrandMark(),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.resolveTextPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.resolveTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_hasFastFactor) ...[
                  FastUnlockPanel(
                    biometricAvailable: _biometricAvailable,
                    showPinPad: _hasUnlockPin,
                    label: isSw
                        ? 'Ingiza PIN yako ya tarakimu 4'
                        : 'Enter your 4-digit PIN',
                    busy: _busy,
                    errorMessage: _message,
                    onFingerprint: _unlockWithBiometric,
                    onPin: _unlockWithPin,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _logoutToLogin,
                    child: const Text('Ingia kwa nenosiri'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _busy ? null : _logoutToLogin,
                    icon: const Icon(Icons.login, size: 18),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    label: const Text('Endelea Kuingia'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasFastFactor => _biometricAvailable || _hasUnlockPin;
}

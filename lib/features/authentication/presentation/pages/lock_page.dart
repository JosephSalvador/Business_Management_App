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
/// The session is already trusted, so neither a password nor a quick-unlock
/// token is required — just a fresh biometric match or the local unlock PIN.
/// Nothing about connectivity or "offline mode" is ever shown here.
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
    final biometricAvailable = await biometricGate.isAvailable();
    final hasUnlockPin = await store.hasUnlockPin();
    if (mounted) {
      setState(() {
        _biometricAvailable = biometricAvailable;
        _hasUnlockPin = hasUnlockPin;
      });
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
      // Unlock failure leaves AuthUnauthenticated → router sends to /login.
      final auth = ref.read(authControllerProvider);
      if (auth is AuthLocked) {
        setState(
            () => _message = 'Hakuna uwezo wa kufungua. Jaribu neno siri.');
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
                  'App imefungwa kwa usalama',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.resolveTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Thibitisha utambulisho wako ili kuendelea',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.resolveTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_hasFastFactor)
                  FastUnlockPanel(
                    biometricAvailable: _biometricAvailable,
                    showPinPad: _hasUnlockPin,
                    busy: _busy,
                    errorMessage: _message,
                    onFingerprint: _unlockWithBiometric,
                    onPin: _unlockWithPin,
                  )
                else
                  OutlinedButton(
                    onPressed: _busy ? null : _logoutToLogin,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Ingia kwa nenosiri'),
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

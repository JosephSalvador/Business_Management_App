import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../auth/application/auth_controller.dart';

/// Confirms a fresh registration with the 6-digit code emailed to the owner.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  Timer? _resendTicker;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _resendTicker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCountdown = 60);
    _resendTicker?.cancel();
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown -= 1;
        if (_resendCountdown <= 0) {
          _resendCountdown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate() || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(
            code: _codeController.text.trim(),
          );
      // State change routes back to /login with a success message.
    } on AppException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0 || _busy) {
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(authControllerProvider.notifier).resendVerificationCode();
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Namba mpya imetumwa kwenye barua pepe yako.')),
        );
      }
    } on RateLimitException {
      _startCooldown();
      setState(
        () => _error = 'Tafadhali subiri kabla ya kuomba namba nyingine.',
      );
    } on AppException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final email =
        auth is AuthNeedsVerification ? auth.email : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Thibitisha barua pepe')),
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
                      'Tumetuma namba ya uthibitisho kwenye:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Namba ya uthibitisho',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      validator: (value) =>
                          (value ?? '').trim().length == 6
                              ? null
                              : 'Weka namba zenye tarakimu 6',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: Text(_busy ? 'Inathibitisha…' : 'Thibitisha'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resendCountdown > 0 || _busy ? null : _resend,
                      child: Text(
                        _resendCountdown > 0
                            ? 'Omba namba nyingine (${_resendCountdown}s)'
                            : 'Omba namba nyingine',
                      ),
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

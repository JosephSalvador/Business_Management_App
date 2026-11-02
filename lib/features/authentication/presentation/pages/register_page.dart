import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_brand_mark.dart';
import '../widgets/auth_error_mapper.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/language_switcher.dart';
import '../widgets/password_field.dart';

/// Multi-step registration wizard with Owner/Staff toggle and live verification.
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

  int _currentStep = 0; // 0: Identity & Contact, 1: Security & Terms
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

  void _dismissError() {
    setState(() => _errors = null);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _showErrorCard({
    required String message,
    bool isConflict = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        closeIconColor: Colors.white,
        duration: const Duration(seconds: 8),
        action: isConflict
            ? SnackBarAction(
                label: context.loc.haveAccount,
                textColor: Colors.white,
                onPressed: () => context.go(Routes.login),
              )
            : null,
      ),
    );
  }

  Future<void> _nextStep() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _errors = null;
    });

    try {
      final controller = ref.read(authControllerProvider.notifier);
      final availability = await controller.checkAvailability(
        email: _emailController.text,
        phone: _phoneController.text,
      );

      if (!availability.emailAvailable) {
        setState(() {
          _errors = AuthFieldErrors(
            fieldErrors: {'Email': context.loc.emailAlreadyTaken},
            banner: context.loc.emailAlreadyTaken,
          );
        });
        if (mounted) {
          _showErrorCard(
            message: context.loc.emailAlreadyTaken,
            isConflict: true,
          );
        }
        return;
      }
      if (!availability.phoneAvailable) {
        setState(() {
          _errors = AuthFieldErrors(
            fieldErrors: {'Phone': context.loc.phoneAlreadyTaken},
            banner: context.loc.phoneAlreadyTaken,
          );
        });
        if (mounted) {
          _showErrorCard(
            message: context.loc.phoneAlreadyTaken,
            isConflict: true,
          );
        }
        return;
      }

      setState(() {
        _currentStep = 1;
        _errors = null;
      });
    } catch (_) {
      // Non-fatal pre-check fallback: allow user to continue to step 2
      setState(() {
        _currentStep = 1;
        _errors = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      final mapped = mapAuthError(error);
      final isConflict = error is ConflictException ||
          mapped.fieldErrors.containsKey('Email') ||
          mapped.fieldErrors.containsKey('Phone');
      setState(() {
        _errors = mapped;
        // If the conflict was on an identity field, route back to Step 0 immediately
        if (mapped.fieldErrors.containsKey('Email') ||
            mapped.fieldErrors.containsKey('Phone') ||
            mapped.fieldErrors.containsKey('FullName') ||
            mapped.fieldErrors.containsKey('InvitationCode') ||
            isConflict) {
          _currentStep = 0;
        }
      });
      if (mounted) {
        final message = mapped.fieldErrors.isNotEmpty
            ? mapped.fieldErrors.values.first
            : (mapped.banner ?? error.message);
        _showErrorCard(
          message: message,
          isConflict: isConflict,
        );
      }
    } catch (error) {
      final message = error.toString();
      setState(() => _errors = AuthFieldErrors(banner: message));
      if (mounted) {
        _showErrorCard(message: message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final errors = _errors ?? AuthFieldErrors();

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0 && !_busy) {
          setState(() {
            _currentStep = 0;
            _errors = null;
          });
        }
      },
      child: AuthBackground(
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
                    const SizedBox(height: 18),

                    // Multi-Step Progress Indicator (Microsoft-style)
                    _buildStepIndicator(context),

                    // Step View (Step 0: Identity / Step 1: Security)
                    if (_currentStep == 0)
                      _buildIdentityStep(loc, errors)
                    else
                      _buildSecurityStep(loc, errors),

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
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final loc = context.loc;
    final primary = AppColors.primary;
    final divider = Theme.of(context).dividerColor.withValues(alpha: 0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: _StepBadge(
              stepIndex: 0,
              currentStep: _currentStep,
              title: loc.registerStepIdentity,
              onTap: _currentStep > 0 && !_busy
                  ? () => setState(() {
                        _currentStep = 0;
                        _errors = null;
                      })
                  : null,
            ),
          ),
          Container(
            width: 24,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: _currentStep > 0 ? primary : divider,
          ),
          Expanded(
            child: _StepBadge(
              stepIndex: 1,
              currentStep: _currentStep,
              title: loc.registerStepSecurity,
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityStep(AppLocalizations loc, AuthFieldErrors errors) {
    final conflictMsg = errors.banner ??
        errors.fieldErrors['Email'] ??
        errors.fieldErrors['Phone'];
    final isConflict = errors.fieldErrors.containsKey('Email') ||
        errors.fieldErrors.containsKey('Phone') ||
        (errors.banner?.toLowerCase().contains('tayari') ?? false) ||
        (errors.banner?.toLowerCase().contains('registered') ?? false) ||
        (errors.banner?.toLowerCase().contains('already') ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 18),
        TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: loc.fullNameLabel,
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            errorText: errorForField(errors, const ['FullName']),
          ),
          textInputAction: TextInputAction.next,
          validator: (value) =>
              (value ?? '').trim().isEmpty ? loc.fullNameRequired : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailController,
          onChanged: (_) {
            if (_errors != null) _dismissError();
          },
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
          onChanged: (_) {
            if (_errors != null) _dismissError();
          },
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
            final phone = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
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
              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
              errorText: errorForField(errors, const ['InvitationCode']),
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
        if (conflictMsg != null)
          _DismissibleAlertCard(
            message: conflictMsg,
            actionLabel: isConflict ? loc.haveAccount : null,
            onAction: () => context.go(Routes.login),
            onDismiss: _dismissError,
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _nextStep,
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(loc.nextStep),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSecurityStep(AppLocalizations loc, AuthFieldErrors errors) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card showing email with quick "Edit" action
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullNameController.text.trim(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _emailController.text.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: loc.previousStep,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _currentStep = 0;
                          _errors = null;
                        }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PasswordField(
          controller: _passwordController,
          labelText: loc.passwordLabel,
          helperText: loc.passwordHelper,
          errorText: errorForField(errors, const ['Password', 'NewPassword']),
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          validator: (value) => validatePasswordPolicy(context, value),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _passwordController,
          builder: (_, value, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordStrengthMeter(password: value.text),
              PasswordRequirementsView(password: value.text),
            ],
          ),
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
          _DismissibleAlertCard(
            message: errors.banner!,
            onDismiss: _dismissError,
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _currentStep = 0;
                        _errors = null;
                      }),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(80, 52),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, size: 18),
                  const SizedBox(width: 4),
                  Text(loc.previousStep),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
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
            ),
          ],
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.stepIndex,
    required this.currentStep,
    required this.title,
    this.onTap,
  });

  final int stepIndex;
  final int currentStep;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = currentStep == stepIndex;
    final isDone = currentStep > stepIndex;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primary = AppColors.primary;
    final muted = AppColors.resolveTextSecondary(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? primary
                    : (isActive
                        ? (isDark
                            ? primary.withValues(alpha: 0.3)
                            : primary.withValues(alpha: 0.15))
                        : theme.colorScheme.surfaceContainerHighest),
                border: Border.all(
                  color: isDone || isActive ? primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? primary : muted,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? AppColors.resolveTextPrimary(context)
                      : muted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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

class _DismissibleAlertCard extends StatelessWidget {
  const _DismissibleAlertCard({
    required this.message,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    return Container(
      key: const Key('dismissible_alert_card'),
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.error.withValues(alpha: 0.18)
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.red.shade200 : AppColors.error,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('dismiss_alert_button'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.resolveTextSecondary(context),
            ),
            tooltip: loc.dismiss,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}


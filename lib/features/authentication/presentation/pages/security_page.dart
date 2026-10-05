import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../application/security_controller.dart';
import '../../data/auth_providers.dart';
import '../../data/security_repository.dart';
import '../widgets/code_input_field.dart';

/// Own-account security: second-factor enrolment and the device list.
///
/// Both live on one screen because they answer the same question — "is anyone
/// else in my account?" — and a compromised device can both be listed and
/// (indirectly) have bypassed the factor, so the two are reviewed together.
class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(title: Text(loc.securityTitle)),
      body: SafeArea(child: _body(context, ref)),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final controller = ref.read(securityControllerProvider.notifier);
    final onRefresh = controller.load;

    return switch (ref.watch(securityControllerProvider)) {
      SecurityLoading() => const Center(child: CircularProgressIndicator()),
      SecurityFailure(:final message) =>
        _Failure(message: message, onRetry: onRefresh),
      final SecurityRecoveryCodes codes => _RecoveryCodesView(state: codes),
      final SecurityEnrolling enrolling => _EnrollView(state: enrolling),
      final SecurityEnrollFailure failed => _EnrollView(state: failed),
      final SecurityLoaded loaded =>
        _LoadedView(loaded: loaded, onRefresh: onRefresh),
    };
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: context.loc.commonError,
      message: message,
      actionLabel: context.loc.commonRetry,
      onAction: onRetry,
    );
  }
}

class _LoadedView extends ConsumerWidget {
  const _LoadedView({required this.loaded, required this.onRefresh});

  final SecurityLoaded loaded;

  /// Async rather than [VoidCallback]: RefreshIndicator keeps the spinner up
  /// until the returned future completes, so a synchronous signature here would
  /// make pull-to-refresh appear to finish instantly while still loading.
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final controller = ref.read(securityControllerProvider.notifier);

    return RefreshIndicator(
      onRefresh: () => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(loc.securityTwoFactorSection),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.shield_outlined,
                      color: loaded.mfa.enabled
                          ? AppColors.success
                          : AppColors.resolveTextSecondary(context)),
                  title: Text(loaded.mfa.enabled
                      ? loc.securityTwoFactorOn
                      : loc.securityTwoFactorOff),
                  subtitle: Text(
                    loaded.mfa.enabled && loaded.mfa.enabledAt != null
                        ? loc.securityTwoFactorSince(
                            DateFormat.yMMMd()
                                .format(loaded.mfa.enabledAt!.toLocal()),
                          )
                        : loaded.mfa.requiredForThisUser
                            ? loc.securityTwoFactorRecommended
                            : loc.mfaCodePrompt,
                  ),
                ),
                if (loaded.mfa.enabled)
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text(loc.securityTwoFactorTurnOn),
                    // Re-enrolment is the same flow as first-time setup, so the
                    // existing factor stays valid until the new secret is
                    // confirmed. Labelled as "turn on" because from the user's
                    // side that is what replacing a lost phone means.
                    onTap: controller.beginSetup,
                  ),
                ListTile(
                  leading: const Icon(Icons.lock_open_outlined),
                  title: Text(loc.securityTwoFactorTurnOff),
                  enabled: loaded.mfa.enabled,
                  onTap: loaded.mfa.enabled
                      ? () => _promptForCode(
                            context,
                            title: loc.securityTwoFactorTurnOff,
                            helper: loc.securityDisableConfirm,
                            onSubmit: controller.disable,
                          )
                      : null,
                ),
                if (loaded.mfa.enabled)
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined),
                    title: Text(loc.securityRecoveryCodesTitle),
                    subtitle: Text(
                      loc.securityRecoveryCodesLeft(
                          loaded.mfa.recoveryCodesRemaining),
                    ),
                    onTap: () => _confirmRegenerate(context, controller),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(loc.securitySessionsSection),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      loc.securitySessionsIntro,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ),
                ),
                if (loaded.sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(loc.securitySessionsEmpty),
                    ),
                  )
                else
                  for (final device in loaded.sessions)
                    ListTile(
                      leading: Icon(
                        device.isCurrent
                            ? Icons.smartphone
                            : Icons.devices_other,
                        color: device.isCurrent
                            ? AppColors.primary
                            : AppColors.resolveTextSecondary(context),
                      ),
                      title: Text(device.device),
                      subtitle: Text(
                        [
                          if (device.isCurrent) loc.securitySessionCurrent,
                          if (device.ipAddress != null) device.ipAddress!,
                          DateFormat.yMMMd().format(device.startedAt.toLocal()),
                        ].join(' · '),
                      ),
                      // No sign-out for the device in use: revoking it ends this
                      // session, which the client handles by signing out, so the
                      // button is redundant and its absence avoids a dead tap.
                      trailing: device.isCurrent
                          ? null
                          : TextButton(
                              onPressed: () =>
                                  controller.revokeSession(device.familyId),
                              child: Text(loc.securitySessionSignOut),
                            ),
                    ),
                if (loaded.sessions.length > 1)
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(loc.securitySessionSignOutAll),
                    onTap: () => controller.revokeAllSessions(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegenerate(
      BuildContext context, SecurityController controller) async {
    final loc = context.loc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.securityRecoveryCodesTitle),
        content: Text(loc.securityRecoveryCodesIntro),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.commonSave),
          ),
        ],
      ),
    );

    // Generating replaces the whole batch, so the previous codes stop working the
    // moment this succeeds. It is only offered behind a confirmation for that
    // reason.
    if (confirmed == true) {
      await controller.regenerateRecoveryCodes();
    }
  }
}

class _EnrollView extends ConsumerStatefulWidget {
  const _EnrollView({required this.state});

  final SecurityState state;

  @override
  ConsumerState<_EnrollView> createState() => _EnrollViewState();
}

class _EnrollViewState extends ConsumerState<_EnrollView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _busy = false;
  bool _copied = false;

  TwoFactorEnrollment get _enrollment => switch (widget.state) {
        SecurityEnrolling(:final enrollment) => enrollment,
        SecurityEnrollFailure(:final enrollment) => enrollment,
        _ => throw StateError('Enrolment state expected'),
      };

  String? get _error => switch (widget.state) {
        SecurityEnrollFailure(:final message) => message,
        _ => null,
      };

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6 || _busy) return;

    setState(() => _busy = true);
    await ref.read(securityControllerProvider.notifier).confirmSetup(code);
    if (!mounted) return;
    // Both outcomes clear the field: either the app moved on to the recovery
    // codes, or the code was rejected and needs replacing.
    setState(() => _busy = false);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(loc.securityTwoFactorSetupTitle,
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    loc.securityTwoFactorScanTitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: _enrollment.provisioningUri,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          loc.securityTwoFactorManualKey,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.resolveTextSecondary(context),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          _formatManualKey(_enrollment.secret),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          // Manual entry is the fallback for a device that cannot scan, so the
          // key must be copyable without selecting it character by character.
          onPressed: () async {
            await Clipboard.setData(
                ClipboardData(text: _enrollment.secret.trim()));
            if (!mounted) return;
            setState(() => _copied = true);
          },
          icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
          label: Text(_copied ? loc.commonSuccess : loc.commonSave),
        ),
        const SizedBox(height: 16),
        Text(
          loc.securityTwoFactorThenConfirm,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.resolveTextSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        CodeInputField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !_busy,
          digitCount: 6,
          label: loc.mfaCodeLabel,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc.commonSave),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () =>
                  ref.read(securityControllerProvider.notifier).cancelSetup(),
          child: Text(loc.commonCancel),
        ),
      ],
    );
  }
}

/// Groups a base32 secret into blocks of four so it can be read aloud or typed
/// from a printout without losing one's place.
String _formatManualKey(String secret) {
  final trimmed = secret.trim().toUpperCase();
  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(trimmed[i]);
  }
  return buffer.toString();
}

class _RecoveryCodesView extends ConsumerWidget {
  const _RecoveryCodesView({required this.state});

  final SecurityRecoveryCodes state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);

    // The codes exist only in this response; leaving without acknowledging
    // would discard the user's last chance to record them. `canPop: false` plus
    // an explicit leave call keeps the back button from silently dropping them.
    return PopScope(
      canPop: state.acknowledged,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.acknowledged) _confirmDiscard(context, ref);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.check_circle_outline, size: 40, color: AppColors.success),
          const SizedBox(height: 12),
          Text(
            loc.securityTwoFactorEnabled,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(loc.securityRecoveryCodesTitle,
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            loc.securityRecoveryCodesIntro,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.resolveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                state.codes.codes.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 17,
                  height: 1.8,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.acknowledged
                ? null
                : () => ref
                    .read(securityControllerProvider.notifier)
                    .acknowledgeRecoveryCodes(),
            child: Text(state.acknowledged
                ? loc.commonDone
                : loc.securityRecoveryCodesSaved),
          ),
          if (state.acknowledged) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                ref.read(securityControllerProvider.notifier).load();
              },
              child: Text(loc.commonBack),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final loc = context.loc;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.securityRecoveryCodesTitle),
        content: Text(loc.securityRecoveryCodesIntro),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.commonDone),
          ),
        ],
      ),
    );

    if (leave == true) {
      ref.read(securityControllerProvider.notifier).acknowledgeRecoveryCodes();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.resolveTextSecondary(context),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Collects a current 6-digit code for a security-sensitive action. Reusing the
/// same control as sign-in keeps the keypad and length rules identical, so a
/// user does not have to learn two ways of entering a TOTP code.
Future<void> _promptForCode(
  BuildContext context, {
  required String title,
  required String helper,
  required Future<void> Function(String code) onSubmit,
}) async {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              helper,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.resolveTextSecondary(dialogContext),
              ),
            ),
            const SizedBox(height: 12),
            CodeInputField(
              controller: controller,
              focusNode: focusNode,
              digitCount: 6,
              label: dialogContext.loc.mfaCodeLabel,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onSubmit(controller.text.trim());
            },
            child: Text(dialogContext.loc.commonDone),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
    focusNode.dispose();
  }
}

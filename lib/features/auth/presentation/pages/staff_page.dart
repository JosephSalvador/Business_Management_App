import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';
import '../widgets/auth_error_mapper.dart';

/// Owner-only screen that issues a one-time staff invitation code. The owner
/// shares the code; a staff member redeems it at registration and joins this
/// business with the Staff role.
class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});

  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
  bool _busy = false;
  String? _code;
  DateTime? _expiresAtUtc;
  String? _error;
  bool _copied = false;

  Future<void> _generate() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _copied = false;
    });
    try {
      final invitation =
          await ref.read(authRepositoryProvider).issueInvitation();
      if (!mounted) {
        return;
      }
      setState(() {
        _code = invitation.code;
        _expiresAtUtc = invitation.expiresAtUtc;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = mapAuthError(error).banner ?? error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copy(String localeName) async {
    final code = _code;
    if (code == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.loc.inviteCodeCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final localeName = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(title: Text(loc.staffTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.staffHeading,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(loc.staffSubtitle),
                  const SizedBox(height: 16),
                  Text(
                    loc.staffNote,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(
                      _busy ? loc.generatingCode : loc.generateCode,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_code != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              loc.yourInviteCode,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              _code!,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    letterSpacing: 6,
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            if (_expiresAtUtc != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${loc.inviteCodeExpires}: '
                                '${DateFormat('dd MMM yyyy HH:mm', localeName.isEmpty ? null : localeName)
                                        .format(_expiresAtUtc!.toLocal())}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: () => _copy(localeName),
                              icon: Icon(
                                _copied
                                    ? Icons.check
                                    : Icons.copy,
                              ),
                              label: Text(loc.copyCode),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

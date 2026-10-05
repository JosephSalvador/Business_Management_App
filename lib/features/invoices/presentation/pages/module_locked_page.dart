import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../../authentication/data/auth_providers.dart';

class ModuleLockedPage extends ConsumerWidget {
  const ModuleLockedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final auth = ref.watch(authControllerProvider);
    final canManageBilling = auth is AuthAuthenticated &&
        auth.session.user.hasPermission('Billing.Manage');

    return Scaffold(
      appBar: AppBar(title: Text(loc.moduleLockedTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.moduleLockedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                loc.moduleLockedMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.resolveTextSecondary(context),
                    ),
              ),
              const SizedBox(height: 24),
              if (canManageBilling)
                FilledButton.icon(
                  onPressed: () => context.go(Routes.billing),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: Text(loc.moduleLockedGoToBilling),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(Routes.home),
                child: Text(loc.moduleLockedBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

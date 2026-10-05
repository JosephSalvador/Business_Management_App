import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../features/authentication/application/auth_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/design_system/responsive.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/billing_controller.dart';
import '../../domain/billing.dart';
import '../services/invoice_pdf_service.dart';

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  late final TextEditingController _voucherController;
  String? _sharingInvoiceId;
  bool _canManagePackages = false;

  @override
  void initState() {
    super.initState();
    _voucherController = TextEditingController();
    Future.microtask(() {
      if (mounted) {
        ref.read(billingControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) {
      _showMessage(context.loc.billingVoucherRequired);
      return;
    }
    await ref.read(billingControllerProvider.notifier).redeemVoucher(code);
    if (!mounted) return;
    final state = ref.read(billingControllerProvider);
    if (state.message == null) {
      _voucherController.clear();
      _showMessage(context.loc.billingVoucherSuccess);
    }
  }

  Future<void> _shareInvoice(BillingInvoice invoice) async {
    if (_sharingInvoiceId != null) return;
    setState(() => _sharingInvoiceId = invoice.id);
    try {
      final loaded = await ref
          .read(billingControllerProvider.notifier)
          .loadInvoice(invoice.id);
      if (loaded == null || !mounted) return;
      await ref.read(invoicePdfServiceProvider).share(
            loaded,
            labels: _invoicePdfLabels(context.loc, loaded),
          );
      if (mounted) _showMessage(context.loc.billingShareSuccess);
    } on Object {
      if (mounted) _showMessage(context.loc.billingShareError);
    } finally {
      if (mounted) setState(() => _sharingInvoiceId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePackage(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    await ref.read(capabilitiesStateProvider.notifier).refresh();
  }

  InvoicePdfLabels _invoicePdfLabels(
    AppLocalizations loc,
    BillingInvoice invoice,
  ) {
    final status = switch (invoice.status) {
      BillingInvoiceStatus.open => loc.billingInvoiceOpen,
      BillingInvoiceStatus.paid => loc.billingInvoicePaid,
      BillingInvoiceStatus.cancelled => loc.billingInvoiceCancelled,
    };
    return InvoicePdfLabels(
      title: loc.billingTitle,
      invoiceNumber: loc.billingInvoiceNumber,
      status: loc.billingStatus,
      statusValue: status,
      issued: loc.billingInvoiceIssued,
      period: loc.billingInvoicePeriod,
      description: loc.billingInvoiceDescription,
      amountDue: loc.billingInvoiceAmountDue,
      reference: loc.billingInvoiceReference,
      paid: loc.billingInvoicePaidAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingControllerProvider);
    final loc = context.loc;
    final auth = ref.watch(authControllerProvider);
    _canManagePackages = auth is AuthAuthenticated &&
        auth.session.user.hasPermission('Billing.Manage');
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.billingTitle),
        actions: [
          IconButton(
            tooltip: loc.commonRetry,
            onPressed: state.isLoading || state.isWorking
                ? null
                : () => ref.read(billingControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: WaveBackground(
        child: _buildBody(context, state, loc),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BillingState typedState,
    AppLocalizations loc,
  ) {
    if (typedState.isLoading && !typedState.hasData) {
      return Center(child: Text(loc.billingLoading));
    }
    if (!typedState.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.billingLoadError),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  ref.read(billingControllerProvider.notifier).load(),
              child: Text(loc.billingRetry),
            ),
          ],
        ),
      );
    }
    final entitlement = typedState.entitlement as SubscriptionEntitlement;
    return RefreshIndicator(
      onRefresh: () => ref.read(billingControllerProvider.notifier).load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.getPagePadding(context),
        children: [
          if (typedState.isLoading) const LinearProgressIndicator(),
          _EntitlementCard(entitlement: entitlement, loc: loc),
          if (entitlement.isInDebt) ...[
            const SizedBox(height: 12),
            _MessageCard(
              icon: Icons.info_outline,
              message: loc.billingBackstopMessage,
            ),
          ],
          if (typedState.message != null) ...[
            const SizedBox(height: 12),
            _MessageCard(
              icon: Icons.error_outline,
              message: typedState.message as String,
              onClose: () =>
                  ref.read(billingControllerProvider.notifier).clearMessage(),
            ),
          ],
          const SizedBox(height: 20),
          _VoucherCard(
            controller: _voucherController,
            isWorking: typedState.isWorking,
            onSubmit: _redeem,
            loc: loc,
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: loc.billingPlans),
          const SizedBox(height: 8),
          ...typedState.plans.where((plan) => !plan.isPackage).map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PlanCard(
                    plan: plan,
                    isCurrent: plan.code == entitlement.planCode,
                    loc: loc,
                  ),
                ),
              ),
          const SizedBox(height: 16),
          _SectionTitle(title: loc.packagesTitle),
          const SizedBox(height: 8),
          _PackagesCard(
            plans: typedState.plans.where((plan) => plan.isPackage).toList(),
            activeCodes:
                entitlement.packages.map((code) => code.toLowerCase()).toSet(),
            isWorking: typedState.isWorking,
            canManage: _canManagePackages,
            onActivate: (code) => _changePackage(
              () => ref
                  .read(billingControllerProvider.notifier)
                  .activatePackage(code),
            ),
            onRemove: (code) => _changePackage(
              () => ref
                  .read(billingControllerProvider.notifier)
                  .removePackage(code),
            ),
            loc: loc,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SectionTitle(title: loc.billingInvoices)),
              TextButton.icon(
                onPressed: typedState.isWorking
                    ? null
                    : () => ref
                        .read(billingControllerProvider.notifier)
                        .evaluateSubscription(),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  typedState.isWorking
                      ? loc.billingChecking
                      : loc.billingEvaluate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (typedState.invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text(loc.billingNoInvoices)),
            )
          else
            ...typedState.invoices.map(
              (invoice) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InvoiceCard(
                  invoice: invoice,
                  isSharing: _sharingInvoiceId == invoice.id,
                  onShare: () => _shareInvoice(invoice),
                  loc: loc,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntitlementCard extends StatelessWidget {
  const _EntitlementCard({required this.entitlement, required this.loc});

  final SubscriptionEntitlement entitlement;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (entitlement.status) {
      SubscriptionStatus.trial => loc.billingStatusTrial,
      SubscriptionStatus.active => loc.billingStatusActive,
      SubscriptionStatus.debt => loc.billingStatusDebt,
    };
    final statusColor =
        entitlement.isInDebt ? AppColors.error : AppColors.success;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.billingCurrentPlan,
              style: TextStyle(color: AppColors.resolveTextSecondary(context)),
            ),
            const SizedBox(height: 4),
            Text(
              entitlement.planCode ?? loc.billingFree,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(label: statusLabel, color: statusColor),
                _StatusPill(
                  label: entitlement.hasFullAccess
                      ? loc.billingFullAccess
                      : loc.billingBackstopAccess,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: loc.billingStatus,
              value: statusLabel,
            ),
            _DetailRow(
              label: loc.billingNextDue,
              value: entitlement.nextDueUtc == null
                  ? loc.billingNoDueDate
                  : DateFormat.yMMMd()
                      .format(entitlement.nextDueUtc!.toLocal()),
            ),
            if (entitlement.maxBranches != null)
              _DetailRow(
                label: loc.permBranches,
                value: '${entitlement.maxBranches}',
              ),
            if (entitlement.maxUsers != null)
              _DetailRow(
                label: loc.permUsers,
                value: '${entitlement.maxUsers}',
              ),
            if (entitlement.maxProducts != null)
              _DetailRow(
                label: loc.permProducts,
                value: '${entitlement.maxProducts}',
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: AppColors.resolveTextSecondary(context)),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.onClose});

  final IconData icon;
  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: AppColors.error),
        title: Text(message),
        trailing: onClose == null
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.controller,
    required this.isWorking,
    required this.onSubmit,
    required this.loc,
  });

  final TextEditingController controller;
  final bool isWorking;
  final Future<void> Function() onSubmit;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.billingVoucherTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              loc.billingVoucherIntro,
              style: TextStyle(color: AppColors.resolveTextSecondary(context)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isWorking,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: loc.billingVoucherLabel,
                      hintText: loc.billingVoucherHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isWorking ? null : onSubmit,
                  child: Text(loc.billingRedeem),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.loc,
  });

  final BillingPlan plan;
  final bool isCurrent;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final quotas = <String>[
      if (plan.maxBranches != null) loc.billingQuotaBranches(plan.maxBranches!),
      if (plan.maxUsers != null) loc.billingQuotaUsers(plan.maxUsers!),
      if (plan.maxProducts != null) loc.billingQuotaProducts(plan.maxProducts!),
    ];
    return Card(
      child: ListTile(
        title: Text(plan.name),
        subtitle: Text(
          quotas.isEmpty ? loc.billingBackstopAccess : quotas.join(' • '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${plan.currency} ${plan.monthlyPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              isCurrent ? loc.billingCurrentPlan : loc.billingPerMonth,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.resolveTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.isSharing,
    required this.onShare,
    required this.loc,
  });

  final BillingInvoice invoice;
  final bool isSharing;
  final VoidCallback onShare;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (invoice.status) {
      BillingInvoiceStatus.open => loc.billingInvoiceOpen,
      BillingInvoiceStatus.paid => loc.billingInvoicePaid,
      BillingInvoiceStatus.cancelled => loc.billingInvoiceCancelled,
    };
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(invoice.number),
        subtitle: Text(
          '${invoice.currency} ${invoice.amount.toStringAsFixed(2)} • $statusLabel',
        ),
        trailing: IconButton(
          tooltip: loc.billingShare,
          onPressed: isSharing ? null : onShare,
          icon: isSharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share_outlined),
        ),
      ),
    );
  }
}

class _PackagesCard extends StatelessWidget {
  const _PackagesCard({
    required this.plans,
    required this.activeCodes,
    required this.isWorking,
    required this.canManage,
    required this.onActivate,
    required this.onRemove,
    required this.loc,
  });

  final List<BillingPlan> plans;
  final Set<String> activeCodes;
  final bool isWorking;
  final bool canManage;
  final ValueChanged<String> onActivate;
  final ValueChanged<String> onRemove;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text(loc.packagesNone)),
      );
    }
    return Column(
      children: [
        for (final plan in plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PackageCard(
              plan: plan,
              isActive: activeCodes.contains(plan.code.toLowerCase()),
              isWorking: isWorking,
              canManage: canManage,
              onActivate: () => onActivate(plan.code),
              onRemove: () => onRemove(plan.code),
              loc: loc,
            ),
          ),
        if (!canManage)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              loc.packagesRequiresBillingManage,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.resolveTextSecondary(context),
              ),
            ),
          ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.plan,
    required this.isActive,
    required this.isWorking,
    required this.canManage,
    required this.onActivate,
    required this.onRemove,
    required this.loc,
  });

  final BillingPlan plan;
  final bool isActive;
  final bool isWorking;
  final bool canManage;
  final VoidCallback onActivate;
  final VoidCallback onRemove;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final isInvoiceManager = plan.code.toLowerCase() == 'invoice-manager';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isInvoiceManager
                        ? loc.packagesInvoiceManagerName
                        : plan.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (isActive)
                  Icon(Icons.check_circle, size: 20, color: AppColors.success),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isInvoiceManager
                  ? loc.packagesInvoiceManagerDescription
                  : plan.featureKeys.join(', '),
              style: TextStyle(
                color: AppColors.resolveTextSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${plan.currency} ${plan.monthlyPrice.toStringAsFixed(0)}'
                  ' • ${loc.billingPerMonth}',
                  style: TextStyle(
                    color: AppColors.resolveTextSecondary(context),
                  ),
                ),
                const Spacer(),
                if (isActive)
                  TextButton(
                    onPressed: !canManage || isWorking ? null : onRemove,
                    child: Text(loc.packagesRemove),
                  )
                else
                  FilledButton.tonal(
                    onPressed: !canManage || isWorking ? null : onActivate,
                    child: Text(loc.packagesActivate),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/design_system/responsive.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../capabilities/domain/capabilities.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../onboarding/application/workspace_controller.dart';
import '../../application/auth_controller.dart';
import '../../../../core/platform/ios_install_prompt_banner.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../billing/presentation/widgets/module_upgrade_sheet.dart';
import '../widgets/quick_pin_setup_sheet.dart';

/// The authenticated Business OS shell.
///
/// Mobile: bottom navigation bar
/// Tablet/Desktop: compact side NavigationRail
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late int _tab = widget.initialTab.clamp(0, 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQuickPinPrompt();
      _checkForAppUpdate();
    });
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final update = await AppUpdateService.instance.checkForUpdate();
      if (update != null && mounted) {
        await AppUpdateService.promptUpdateDialog(context, update);
      }
    } catch (_) {}
  }

  Future<void> _checkQuickPinPrompt() async {
    final offlineStore = ref.read(offlineCredentialStoreProvider);
    final hasPin = await offlineStore.hasUnlockPin();
    if (hasPin || !mounted) return;

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

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _tab = widget.initialTab.clamp(0, 4));
    }
  }

  static const _dashboardDest = _NavDest(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    labelKey: 'navDashboard',
  );
  static const _productsDest = _NavDest(
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    labelKey: 'navProducts',
    module: WorkspaceModule.inventory,
  );
  static const _posDest = _NavDest(
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
    labelKey: 'navPOS',
    module: WorkspaceModule.pos,
  );
  static const _reportsDest = _NavDest(
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    labelKey: 'navReports',
    module: WorkspaceModule.reports,
  );
  static const _moreDest = _NavDest(
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
    labelKey: 'navMore',
  );

  static const _destinations = [
    _dashboardDest,
    _productsDest,
    _posDest,
    _reportsDest,
    _moreDest,
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final session = auth is AuthAuthenticated ? auth.session : null;
    final workspace = ref.watch(workspaceControllerProvider);
    final business =
        workspace is WorkspaceReady ? workspace.selected?.name : null;
    final isDesktop = Responsive.isDesktop(context);
    final entitlement = ref.watch(subscriptionEntitlementControllerProvider);
    final enabledModules = ref.watch(enabledModulesProvider);
    final capabilities = ref.watch(capabilitiesStateProvider);
    final canManageBilling =
        session?.user.hasPermission('Billing.Manage') ?? false;

    final pages = [
      const DashboardPage(),
      _isDestEnabled(_productsDest, enabledModules)
          ? const ProductsPage()
          : const _LockedModulePlaceholder(),
      _isDestEnabled(_posDest, enabledModules)
          ? const PosPage()
          : const _LockedModulePlaceholder(),
      _isDestEnabled(_reportsDest, enabledModules)
          ? const ReportsPage()
          : const _LockedModulePlaceholder(),
      _MoreTab(
        businessName: business,
        email: session?.user.email,
        isOwner: session?.user.hasPermission('Users.Create') ?? false,
        canViewBilling: session?.user.hasPermission('Billing.View') ?? false,
        canManageBilling: canManageBilling,
        enabledModules: enabledModules,
        capabilitiesAreStale: capabilities.isStale,
        isInDebt: entitlement?.isInDebt ?? false,
        onNavigateToTab: (i) => setState(() => _tab = i),
      ),
    ];

    if (isDesktop) {
      return WaveBackground(
        child: _DesktopShell(
          tab: _tab,
          onTabChanged: (i) => setState(() => _tab = i),
          onLockedDest: (d) => _onLockedModule(context, d, canManageBilling),
          isEnabled: (d) => _isDestEnabled(d, enabledModules),
          destinations: _destinations,
          pages: pages,
        ),
      );
    }

    return WaveBackground(
      child: _MobileShell(
        tab: _tab,
        onTabChanged: (i) => setState(() => _tab = i),
        onLockedDest: (d) => _onLockedModule(context, d, canManageBilling),
        isEnabled: (d) => _isDestEnabled(d, enabledModules),
        destinations: _destinations,
        pages: pages,
      ),
    );
  }

  static bool _isDestEnabled(_NavDest dest, Set<WorkspaceModule> enabled) {
    final module = dest.module;
    return module == null || enabled.contains(module);
  }

  static void _onLockedModule(
    BuildContext context,
    _NavDest dest,
    bool canManageBilling,
  ) {
    final module = dest.module;
    if (module == null) return;
    if (canManageBilling) {
      ModuleUpgradeSheet.show(context, module: module);
    } else {
      context.push(Routes.moduleLocked);
    }
  }
}

// ── Mobile Shell ──────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.tab,
    required this.onTabChanged,
    required this.onLockedDest,
    required this.isEnabled,
    required this.destinations,
    required this.pages,
  });

  final int tab;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<_NavDest> onLockedDest;
  final bool Function(_NavDest dest) isEnabled;
  final List<_NavDest> destinations;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          const IosInstallPromptBanner(),
          Expanded(child: IndexedStack(index: tab, children: pages)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2124) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(destinations.length, (i) {
                final dest = destinations[i];
                final isSelected = tab == i;
                final locked = !isEnabled(dest);
                final isCenter = i == 2; // POS / Sell action

                if (isCenter) {
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!locked) {
                          onTabChanged(i);
                        } else {
                          onLockedDest(dest);
                        }
                      },
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1976D2),
                                Color(0xFF0D47A1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D47A1)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            dest.selectedIcon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      if (!locked) {
                        onTabChanged(i);
                      } else {
                        onLockedDest(dest);
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _NavIcon(
                          dest: dest,
                          selected: isSelected,
                          locked: locked,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _label(loc, dest.labelKey),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF0D47A1)
                                : AppColors.resolveTextTertiary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Desktop Shell ─────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.tab,
    required this.onTabChanged,
    required this.onLockedDest,
    required this.isEnabled,
    required this.destinations,
    required this.pages,
  });

  final int tab;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<_NavDest> onLockedDest;
  final bool Function(_NavDest dest) isEnabled;
  final List<_NavDest> destinations;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      body: Row(
        children: [
          // Side rail
          NavigationRail(
            selectedIndex: tab,
            onDestinationSelected: (i) {
              final dest = destinations[i];
              if (isEnabled(dest)) {
                onTabChanged(i);
              } else {
                onLockedDest(dest);
              }
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/jolinx_logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'JO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            trailing: const Spacer(),
            destinations: destinations
                .map((d) => NavigationRailDestination(
                      icon: _NavIcon(
                          dest: d, selected: false, locked: !isEnabled(d)),
                      selectedIcon: _NavIcon(
                          dest: d, selected: true, locked: !isEnabled(d)),
                      label: Text(_label(loc, d.labelKey)),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          // Content area
          Expanded(
            child: IndexedStack(index: tab, children: pages),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────

String _label(AppLocalizations loc, String key) {
  return switch (key) {
    'navDashboard' => loc.navDashboard,
    'navProducts' => loc.navProducts,
    'navPOS' => loc.navPOS,
    'navReports' => loc.navReports,
    'navMore' => loc.navMore,
    _ => key,
  };
}

class _NavDest {
  const _NavDest({
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    this.module,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  final WorkspaceModule? module;
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.dest,
    required this.selected,
    required this.locked,
  });

  final _NavDest dest;
  final bool selected;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? dest.selectedIcon : dest.icon,
      color: locked ? AppColors.resolveTextTertiary(context) : null,
    );
    if (!locked) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -4,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.lock,
              size: 8,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedModulePlaceholder extends StatelessWidget {
  const _LockedModulePlaceholder();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              loc.moduleLockedTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              loc.moduleLockedMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.resolveTextSecondary(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── More Tab ──────────────────────────────────────────────────────

class _MoreTab extends ConsumerWidget {
  const _MoreTab({
    required this.businessName,
    required this.email,
    required this.isOwner,
    required this.canViewBilling,
    required this.canManageBilling,
    required this.enabledModules,
    required this.capabilitiesAreStale,
    required this.isInDebt,
    required this.onNavigateToTab,
  });

  final String? businessName;
  final String? email;
  final bool isOwner;
  final bool canViewBilling;
  final bool canManageBilling;
  final Set<WorkspaceModule> enabledModules;
  final bool capabilitiesAreStale;
  final bool isInDebt;
  final ValueChanged<int> onNavigateToTab;

  bool _isEnabled(WorkspaceModule module) => enabledModules.contains(module);

  void _openModule(BuildContext context, WorkspaceModule module, String route) {
    if (_isEnabled(module)) {
      context.push(route);
      return;
    }
    if (canManageBilling) {
      ModuleUpgradeSheet.show(context, module: module);
      return;
    }
    context.push(Routes.moduleLocked);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final loc = context.loc;
    final pendingCount =
        await ref.read(localSalesServiceProvider).pendingSaleCount();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.moreLogoutConfirm),
        content: pendingCount > 0
            ? Text(loc.moreLogoutPendingSales)
            : Text(loc.moreLogoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.moreLogoutStay),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.moreLogout),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final pendingCount = ref.watch(
      syncStatusProvider.select((state) => state.pendingCount),
    );
    return Scaffold(
      appBar: AppBar(title: Text(loc.moreTitle)),
      body: ListView(
        padding: Responsive.getPagePadding(context),
        children: [
          // Business card
          if (businessName != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.storefront,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.resolveTextPrimary(context),
                            ),
                          ),
                          if (email != null)
                            Text(
                              email!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.resolveTextSecondary(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          if (capabilitiesAreStale)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoBanner(
                icon: Icons.cloud_off_outlined,
                message: loc.capabilitiesOffline,
              ),
            ),

          if (isInDebt)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoBanner(
                icon: Icons.info_outline,
                message: loc.billingBackstopMessage,
              ),
            ),

          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoBanner(
                icon: Icons.sync_problem_outlined,
                message: '${loc.posSyncPending} ($pendingCount)',
              ),
            ),

          // Quick access
          _sectionTitle(context, loc.moreQuickAccess),
          const SizedBox(height: 8),
          _menuTile(
            context: context,
            icon: Icons.dashboard_outlined,
            title: loc.navDashboard,
            onTap: () => onNavigateToTab(0),
          ),
          if (_isEnabled(WorkspaceModule.pos) || canManageBilling)
            _menuTile(
              context: context,
              icon: Icons.point_of_sale_outlined,
              title: loc.navPOS,
              locked: !_isEnabled(WorkspaceModule.pos),
              onTap: () => _openModule(context, WorkspaceModule.pos, Routes.pos),
            ),
          if (_isEnabled(WorkspaceModule.crm) || canManageBilling)
            _menuTile(
              context: context,
              icon: Icons.people_outline,
              title: loc.navCustomers,
              locked: !_isEnabled(WorkspaceModule.crm),
              onTap: () =>
                  _openModule(context, WorkspaceModule.crm, Routes.customers),
            ),
          if (_isEnabled(WorkspaceModule.invoicing) || canManageBilling)
            _menuTile(
              context: context,
              icon: Icons.receipt_long_outlined,
              title: loc.navInvoices,
              locked: !_isEnabled(WorkspaceModule.invoicing),
              onTap: () => _openModule(
                  context, WorkspaceModule.invoicing, Routes.invoices),
            ),
          if (_isEnabled(WorkspaceModule.purchasing) || canManageBilling) ...[
            _menuTile(
              context: context,
              icon: Icons.local_shipping_outlined,
              title: loc.navSuppliers,
              locked: !_isEnabled(WorkspaceModule.purchasing),
              onTap: () => _openModule(
                  context, WorkspaceModule.purchasing, Routes.suppliers),
            ),
            _menuTile(
              context: context,
              icon: Icons.shopping_cart_outlined,
              title: loc.navPurchases,
              locked: !_isEnabled(WorkspaceModule.purchasing),
              onTap: () => _openModule(
                context,
                WorkspaceModule.purchasing,
                Routes.purchases,
              ),
            ),
          ],
          if (_isEnabled(WorkspaceModule.finance) || canManageBilling)
            _menuTile(
              context: context,
              icon: Icons.account_balance_wallet_outlined,
              title: loc.navExpenses,
              locked: !_isEnabled(WorkspaceModule.finance),
              onTap: () =>
                  _openModule(context, WorkspaceModule.finance, Routes.expenses),
            ),
          if (_isEnabled(WorkspaceModule.reports) || canManageBilling)
            _menuTile(
              context: context,
              icon: Icons.bar_chart_outlined,
              title: loc.navReports,
              locked: !_isEnabled(WorkspaceModule.reports),
              onTap: () =>
                  _openModule(context, WorkspaceModule.reports, Routes.reports),
            ),

          const SizedBox(height: 20),
          _sectionTitle(context, loc.moreManagement),
          const SizedBox(height: 8),

          if (canViewBilling)
            _menuTile(
              context: context,
              icon: Icons.workspace_premium_outlined,
              title: loc.navBilling,
              onTap: () => context.push(Routes.billing),
            ),
          if (isOwner) ...[
            _menuTile(
              context: context,
              icon: Icons.group_outlined,
              title: loc.navUsers,
              onTap: () => context.push(Routes.users),
            ),
            _menuTile(
              context: context,
              icon: Icons.security_outlined,
              title: loc.navRoles,
              onTap: () => context.push(Routes.roles),
            ),
            _menuTile(
              context: context,
              icon: Icons.settings_outlined,
              title: loc.navSettings,
              onTap: () => context.push(Routes.settings),
            ),
          ],

          _menuTile(
            context: context,
            icon: Icons.person_outline,
            title: loc.navProfile,
            onTap: () => context.push(Routes.profile),
          ),

          if (isOwner) ...[
            const SizedBox(height: 20),
            _sectionTitle(context, loc.moreTeam),
            const SizedBox(height: 8),
            _menuTile(
              context: context,
              icon: Icons.group,
              title: loc.staffTitle,
              onTap: () => context.push(Routes.staff),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(loc.moreLogout),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  loc.moreCopyright,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.resolveTextTertiary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.moreTagline,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.resolveTextTertiary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
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

  Widget _menuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: locked
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C48C), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF061028),
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : Icon(
                Icons.chevron_right,
                color: AppColors.resolveTextTertiary(context),
                size: 20,
              ),
        onTap: onTap,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.onWarningContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

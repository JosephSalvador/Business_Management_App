import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/application/auth_controller.dart';
import '../features/onboarding/application/workspace_controller.dart';
import '../features/authentication/presentation/pages/forgot_password_page.dart';
import '../features/authentication/presentation/pages/home_page.dart';
import '../features/authentication/presentation/pages/lock_page.dart';
import '../features/authentication/presentation/pages/login_page.dart';
import '../features/authentication/presentation/pages/register_page.dart';
import '../features/authentication/presentation/pages/reset_password_page.dart';
import '../features/authentication/presentation/pages/security_page.dart';
import '../features/authentication/presentation/pages/staff_page.dart';
import '../features/authentication/presentation/pages/terms_page.dart';
import '../features/authentication/presentation/pages/two_factor_page.dart';
import '../features/billing/domain/billing.dart';
import '../features/billing/presentation/pages/billing_page.dart';
import '../features/customers/presentation/pages/customer_detail_page.dart';
import '../features/customers/presentation/pages/customer_form_page.dart';
import '../features/customers/presentation/pages/customers_page.dart';
import '../features/customers/presentation/pages/outstanding_credit_page.dart';
import '../features/finance/presentation/pages/cash_session_page.dart';
import '../features/finance/presentation/pages/create_account_page.dart';
import '../features/finance/presentation/pages/expense_form_page.dart';
import '../features/finance/presentation/pages/expenses_page.dart';
import '../features/finance/presentation/pages/money_account_detail_page.dart';
import '../features/finance/presentation/pages/money_accounts_page.dart';
import '../features/finance/presentation/pages/record_account_expense_page.dart';
import '../features/finance/presentation/pages/record_income_page.dart';
import '../features/finance/presentation/pages/transfer_money_page.dart';
import '../features/products/presentation/pages/product_detail_page.dart';
import '../features/products/presentation/pages/product_form_page.dart';
import '../features/invoices/presentation/pages/create_invoice_page.dart';
import '../features/invoices/presentation/pages/invoice_detail_page.dart';
import '../features/invoices/presentation/pages/invoices_page.dart';
import '../features/invoices/presentation/pages/module_locked_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/purchases/presentation/pages/purchase_detail_page.dart';
import '../features/purchases/presentation/pages/purchase_form_page.dart';
import '../features/purchases/presentation/pages/purchases_page.dart';
import '../features/reports/application/reports_controller.dart';
import '../features/reports/presentation/pages/reports_page.dart';
import '../features/reports/presentation/pages/top_products_page.dart';
import '../features/reports/presentation/pages/business_overview_page.dart';
import '../features/reports/presentation/pages/sales_report_page.dart';
import '../features/reports/presentation/pages/stock_report_page.dart';
import '../features/reports/presentation/pages/money_report_page.dart';
import '../features/reports/presentation/pages/purchases_report_page.dart';
import '../features/reports/presentation/pages/expenses_report_page.dart';
import '../features/sales/domain/sale.dart';
import '../features/sales/presentation/pages/pos_page.dart';
import '../features/sales/presentation/pages/receipt_preview_page.dart';
import '../features/sales/presentation/pages/sale_detail_page.dart';
import '../features/sales/presentation/pages/sale_success_page.dart';
import '../features/sales/presentation/pages/sales_history_page.dart';
import '../features/settings/presentation/pages/receipt_settings_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/suppliers/presentation/pages/supplier_form_page.dart';
import '../features/suppliers/presentation/pages/suppliers_page.dart';
import '../features/users/presentation/pages/role_form_page.dart';
import '../features/users/presentation/pages/roles_page.dart';
import '../features/users/presentation/pages/user_form_page.dart';
import '../features/users/presentation/pages/users_page.dart';
import '../features/onboarding/presentation/pages/app_download_page.dart';
import '../features/onboarding/presentation/pages/business_setup_page.dart';
import '../features/onboarding/presentation/pages/create_business_page.dart';
import '../features/onboarding/presentation/pages/pick_package_page.dart';
import '../features/onboarding/presentation/pages/splash_page.dart';
import '../features/onboarding/presentation/pages/verify_email_page.dart';
import '../features/onboarding/presentation/pages/workspace_picker_page.dart';
import '../features/onboarding/presentation/pages/zero_workspace_page.dart';
import '../shared/widgets/not_found_page.dart';
import 'providers.dart';

/// Route paths kept in one place; screens never hardcode paths.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const lock = '/lock';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const terms = '/terms';
  static const download = '/download';
  static const verifyEmail = '/verify-email';
  static const twoFactor = '/two-factor';
  static const zeroWorkspace = '/zero-workspace';
  static const createBusiness = '/create-business';
  static const pickPackage = '/pick-package';
  static const setup = '/setup';
  static const picker = '/workspaces';
  static const home = '/home';
  static const pos = '/pos';
  static const posSuccess = '/pos/success';
  static const salesHistory = '/sales';
  static const staff = '/staff';
  static const dashboard = '/dashboard';
  static const customers = '/customers';
  static const invoices = '/invoices';
  static const invoiceNew = '/invoices/new';
  static const moduleLocked = '/module-locked';
  static const outstandingCredit = '/credit/outstanding';
  static const suppliers = '/suppliers';
  static const purchases = '/purchases';
  static const expenses = '/expenses';
  static const financeAccounts = '/finance/accounts';
  static const cashSession = '/finance/cash-session';
  static const reports = '/reports';
  static const reportsTopProducts = '/reports/top-products';
  static const reportsOverview = '/reports/overview';
  static const reportsSales = '/reports/sales';
  static const reportsStock = '/reports/stock';
  static const reportsMoney = '/reports/money';
  static const reportsPurchases = '/reports/purchases';
  static const reportsExpenses = '/reports/expenses';
  static const users = '/users';
  static const roles = '/roles';
  static const settings = '/settings';
  static const receiptSettings = '/settings/receipt';
  static const security = '/settings/security';
  static const billing = '/billing';
  static const profile = '/profile';

  static String receipt(String saleId) => '/pos/receipt/$saleId';
  static String saleDetail(String saleId) => '/sales/$saleId';
  static String productDetail(String productId) => '/products/$productId';
  static String customerDetail(String customerId) => '/customers/$customerId';
  static String invoiceDetail(String invoiceId) => '/invoices/$invoiceId';
  static String customerEdit(String customerId) =>
      '/customers/$customerId/edit';
  static String supplierEdit(String supplierId) =>
      '/suppliers/$supplierId/edit';
  static String purchaseDetail(String purchaseId) => '/purchases/$purchaseId';
  static String userEdit(String userId) => '/users/$userId/edit';
  static String roleEdit(String roleId) => '/roles/$roleId/edit';
}

/// The deterministic journey state machine.
///
/// Given the auth state, the workspace state and the requested path it returns
/// the path to redirect to, or null when the request may proceed. Pure —
/// unit-testable without widgets or providers.
String? journeyRedirect({
  required AuthState auth,
  required WorkspaceState workspace,
  required String path,
}) {
  // 1. Bootstrap: nothing decided yet — everything waits on the splash screen.
  if (auth is AuthUnknown) {
    return path == Routes.splash ? null : Routes.splash;
  }

  // 2. No session (or a fresh unverified registration) never reaches the app.
  //    NOTE: splash is NOT allowed here — once the auth state is known the
  //    journey must leave the splash immediately, otherwise an
  //    unauthenticated user parks on the splash spinner forever (the splash
  //    page never navigates on its own by design).
  if (auth is AuthUnauthenticated) {
    return _isPublicScreen(path) ? null : Routes.login;
  }
  if (auth is AuthNeedsVerification) {
    return path == Routes.verifyEmail ? null : Routes.verifyEmail;
  }
  // A pending second factor blocks every authenticated screen: no token has
  // been issued yet, so nothing behind this point can load.
  if (auth is AuthNeedsTwoFactor) {
    return path == Routes.twoFactor ? null : Routes.twoFactor;
  }
  // Locked session (idle/background auto-lock): the user must pass the fast
  // factor before any screen is reachable.
  if (auth is AuthLocked) {
    return path == Routes.lock ? null : Routes.lock;
  }

  // 3. Authenticated: the workspace journey decides which app screen shows.
  switch (workspace) {
    case WorkspaceLoading():
      return path == Routes.splash ? null : Routes.splash;
    case WorkspaceFailure():
      // The splash screen renders the failure with a retry action.
      return path == Routes.splash ? null : Routes.splash;
    case WorkspaceEmpty():
      final allowed =
          path == Routes.zeroWorkspace || path == Routes.createBusiness;
      return allowed ? null : Routes.zeroWorkspace;
    case WorkspaceReady(:final selected):
      if (path == Routes.picker) {
        return null;
      }
      if (selected == null) {
        // Workspaces exist but none chosen yet.
        return Routes.picker;
      }
      if (!selected.onboardingComplete) {
        final allowed = path == Routes.createBusiness ||
            path == Routes.pickPackage ||
            path == Routes.setup;
        return allowed ? null : Routes.createBusiness;
      }
      if (_isJourneyScreen(path)) {
        return Routes.home;
      }
      return null;
  }
}

bool _isJourneyScreen(String path) =>
    path == Routes.login ||
    path == Routes.lock ||
    path == Routes.register ||
    path == Routes.verifyEmail ||
    path == Routes.twoFactor ||
    path == Routes.zeroWorkspace ||
    path == Routes.createBusiness ||
    path == Routes.splash;

/// Pure decision for billing-gated routes: `null` (proceed) when the tenant
/// may use [featureKey], [Routes.billing] when the session may manage billing
/// (debt lock with `Billing.View`), otherwise [Routes.home]. With no loaded
/// entitlement the decision fails open — the backend stays authoritative.
String? premiumRouteRedirect({
  required SubscriptionEntitlement? entitlement,
  required AuthState auth,
  required String featureKey,
}) {
  if (entitlement == null || entitlement.hasFeature(featureKey)) return null;
  if (auth is AuthAuthenticated &&
      auth.session.user.hasPermission('Billing.View')) {
    return Routes.billing;
  }
  return Routes.home;
}

String? _premiumRouteRedirect(Ref ref, String featureKey) =>
    premiumRouteRedirect(
      entitlement: ref.read(subscriptionEntitlementControllerProvider),
      auth: ref.read(authControllerProvider),
      featureKey: featureKey,
    );

String? moduleRouteRedirect({
  required SubscriptionEntitlement? entitlement,
  required AuthState auth,
  required String featureKey,
}) {
  if (entitlement == null || entitlement.hasFeature(featureKey)) return null;
  if (auth is AuthAuthenticated &&
      auth.session.user.hasPermission('Billing.Manage')) {
    return Routes.billing;
  }
  return Routes.moduleLocked;
}

String? _moduleRouteRedirect(Ref ref, String featureKey) => moduleRouteRedirect(
      entitlement: ref.read(subscriptionEntitlementControllerProvider),
      auth: ref.read(authControllerProvider),
      featureKey: featureKey,
    );

bool _isPublicScreen(String path) =>
    path == Routes.login ||
    path == Routes.register ||
    path == Routes.forgotPassword ||
    path == Routes.resetPassword ||
    path == Routes.terms ||
    path == Routes.download;

/// Bridges [AuthState] + [WorkspaceState] changes into go_router's
/// [refreshListenable].
class _JourneyListenable extends ChangeNotifier {
  _JourneyListenable(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
    ref.listen<WorkspaceState>(
      workspaceControllerProvider,
      (_, __) => notifyListeners(),
    );
    ref.listen<SubscriptionEntitlement?>(
      subscriptionEntitlementControllerProvider,
      (_, __) => notifyListeners(),
    );
    // Ensures auth → workspace wiring exists for this session.
    ref.watch(workspaceJourneyBindingProvider);
  }
}

/// Application router. All redirects flow through [journeyRedirect].
final goRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _JourneyListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: listenable,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: Routes.lock, builder: (_, __) => const LockPage()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) => ResetPasswordPage(
          initialEmail: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(path: Routes.terms, builder: (_, __) => const TermsPage()),
      GoRoute(
        path: Routes.download,
        builder: (_, __) => const AppDownloadPage(),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, __) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: Routes.twoFactor,
        builder: (_, __) => const TwoFactorPage(),
      ),
      GoRoute(
        path: Routes.zeroWorkspace,
        builder: (_, __) => const ZeroWorkspacePage(),
      ),
      GoRoute(
        path: Routes.createBusiness,
        builder: (_, __) => const CreateBusinessPage(),
      ),
      GoRoute(
        path: Routes.pickPackage,
        builder: (_, __) => const PickPackagePage(),
      ),
      GoRoute(
        path: Routes.picker,
        builder: (_, __) => const WorkspacePickerPage(),
      ),
      GoRoute(
          path: Routes.setup, builder: (_, __) => const BusinessSetupPage()),
      GoRoute(
        path: Routes.pos,
        redirect: (_, __) => '${Routes.home}?tab=2',
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, state) => HomePage(
          initialTab:
              int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0,
        ),
      ),
      GoRoute(path: Routes.staff, builder: (_, __) => const StaffPage()),
      GoRoute(
        path: '/products/new',
        builder: (_, __) => const ProductFormPage(),
      ),
      GoRoute(
        path: '/products/:id/edit',
        builder: (_, state) =>
            ProductFormPage(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) =>
            ProductDetailPage(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.posSuccess,
        builder: (_, state) {
          final sale = state.extra as SaleDto?;
          if (sale == null) {
            return const PosPage();
          }
          return SaleSuccessPage(sale: sale);
        },
      ),
      GoRoute(
        path: '/pos/receipt/:id',
        builder: (_, state) => ReceiptPreviewPage(
          saleId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.salesHistory,
        builder: (_, __) => const SalesHistoryPage(),
      ),
      GoRoute(
        path: '/sales/:id',
        builder: (_, state) =>
            SaleDetailPage(saleId: state.pathParameters['id']!),
      ),
      // Customers
      GoRoute(
        path: Routes.customers,
        builder: (_, __) => const CustomersPage(),
      ),
      GoRoute(
        path: '/customers/new',
        redirect: (_, __) => _premiumRouteRedirect(ref, BillingFeatureKeys.crm),
        builder: (_, __) => const CustomerFormPage(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (_, state) =>
            CustomerDetailPage(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customers/:id/edit',
        redirect: (_, __) => _premiumRouteRedirect(ref, BillingFeatureKeys.crm),
        builder: (_, state) =>
            CustomerFormPage(customerId: state.pathParameters['id']),
      ),
      // Credit
      GoRoute(
        path: Routes.outstandingCredit,
        builder: (_, __) => const OutstandingCreditPage(),
      ),
      // Invoices
      GoRoute(
        path: Routes.invoices,
        redirect: (_, __) =>
            _moduleRouteRedirect(ref, BillingFeatureKeys.invoicing),
        builder: (_, __) => const InvoicesPage(),
      ),
      GoRoute(
        path: Routes.invoiceNew,
        redirect: (_, __) =>
            _moduleRouteRedirect(ref, BillingFeatureKeys.invoicing),
        builder: (_, __) => const CreateInvoicePage(),
      ),
      GoRoute(
        path: '/invoices/:id',
        redirect: (_, __) =>
            _moduleRouteRedirect(ref, BillingFeatureKeys.invoicing),
        builder: (_, state) =>
            InvoiceDetailPage(invoiceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.moduleLocked,
        builder: (_, __) => const ModuleLockedPage(),
      ),
      // Suppliers
      GoRoute(
        path: Routes.suppliers,
        builder: (_, __) => const SuppliersPage(),
      ),
      GoRoute(
        path: '/suppliers/new',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.purchasing),
        builder: (_, __) => const SupplierFormPage(),
      ),
      GoRoute(
        path: '/suppliers/:id/edit',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.purchasing),
        builder: (_, state) =>
            SupplierFormPage(supplierId: state.pathParameters['id']),
      ),
      // Purchases
      GoRoute(
        path: Routes.purchases,
        builder: (_, __) => const PurchasesPage(),
      ),
      GoRoute(
        path: '/purchases/new',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.purchasing),
        builder: (_, __) => const PurchaseFormPage(),
      ),
      GoRoute(
        path: '/purchases/:id/edit',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.purchasing),
        builder: (_, state) =>
            PurchaseFormPage(purchaseId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/purchases/:id',
        builder: (_, state) =>
            PurchaseDetailPage(purchaseId: state.pathParameters['id']!),
      ),
      // Expenses
      GoRoute(
        path: Routes.expenses,
        builder: (_, __) => const ExpensesPage(),
      ),
      GoRoute(
        path: '/expenses/new',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.finance),
        builder: (_, __) => const ExpenseFormPage(),
      ),
      GoRoute(
        path: '/expenses/:id/edit',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.finance),
        builder: (_, state) =>
            ExpenseFormPage(expenseId: state.pathParameters['id']),
      ),
      // Finance — Money Accounts
      GoRoute(
        path: Routes.financeAccounts,
        builder: (_, __) => const MoneyAccountsPage(),
      ),
      GoRoute(
        path: '/finance/accounts/new',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.finance),
        builder: (_, __) => const CreateAccountPage(),
      ),
      GoRoute(
        path: '/finance/accounts/:id',
        builder: (_, state) =>
            MoneyAccountDetailPage(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/finance/accounts/:id/income',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.finance),
        builder: (_, state) =>
            RecordIncomePage(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/finance/accounts/:id/expense',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.finance),
        builder: (_, state) =>
            RecordAccountExpensePage(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/finance/accounts/:id/transfer',
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.finance),
        builder: (_, state) => TransferMoneyPage(
          fromAccountId: state.pathParameters['id'],
        ),
      ),
      // Finance — Cash Session
      GoRoute(
        path: Routes.cashSession,
        redirect: (_, __) =>
            _premiumRouteRedirect(ref, BillingFeatureKeys.finance),
        builder: (_, state) => CashSessionPage(
          accountId: state.uri.queryParameters['accountId'] ?? '',
        ),
      ),
      // Reports
      GoRoute(
        path: Routes.reports,
        builder: (_, __) => const ReportsPage(),
      ),
      GoRoute(
        path: Routes.reportsTopProducts,
        builder: (_, state) => TopProductsPage(
          period: parseReportPeriod(state.uri.queryParameters['period']),
        ),
      ),
      GoRoute(
        path: Routes.reportsOverview,
        builder: (_, __) => const BusinessOverviewPage(),
      ),
      GoRoute(
        path: Routes.reportsSales,
        builder: (_, __) => const SalesReportPage(),
      ),
      GoRoute(
        path: Routes.reportsStock,
        builder: (_, __) => const StockReportPage(),
      ),
      GoRoute(
        path: Routes.reportsMoney,
        builder: (_, __) => const MoneyReportPage(),
      ),
      GoRoute(
        path: Routes.reportsPurchases,
        builder: (_, __) => const PurchasesReportPage(),
      ),
      GoRoute(
        path: Routes.reportsExpenses,
        builder: (_, __) => const ExpensesReportPage(),
      ),
      // Users
      GoRoute(
        path: Routes.users,
        builder: (_, __) => const UsersPage(),
      ),
      GoRoute(
        path: '/users/new',
        builder: (_, __) => const UserFormPage(),
      ),
      GoRoute(
        path: '/users/:id/edit',
        builder: (_, state) => UserFormPage(userId: state.pathParameters['id']),
      ),
      // Roles
      GoRoute(
        path: Routes.roles,
        builder: (_, __) => const RolesPage(),
      ),
      GoRoute(
        path: '/roles/new',
        builder: (_, __) => const RoleFormPage(),
      ),
      GoRoute(
        path: '/roles/:id/edit',
        builder: (_, state) => RoleFormPage(roleId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.billing,
        redirect: (_, __) {
          final auth = ref.read(authControllerProvider);
          final session = auth is AuthAuthenticated ? auth.session : null;
          return session?.user.hasPermission('Billing.View') == true
              ? null
              : Routes.home;
        },
        builder: (_, __) => const BillingPage(),
      ),
      // Settings
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: Routes.receiptSettings,
        builder: (_, __) => const ReceiptSettingsPage(),
      ),
      // Own-account security: second-factor enrolment and device list. Nested
      // under settings so it is reached the same way as password and profile
      // management rather than as a top-level journey screen.
      GoRoute(
        path: Routes.security,
        builder: (_, __) => const SecurityPage(),
      ),
      // Profile
      GoRoute(
        path: Routes.profile,
        builder: (_, __) => const ProfilePage(),
      ),
    ],
    redirect: (context, state) => journeyRedirect(
      auth: ref.read(authControllerProvider),
      workspace: ref.read(workspaceControllerProvider),
      path: state.uri.path,
    ),
    errorBuilder: (_, __) => const NotFoundPage(),
  );
});

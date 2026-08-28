import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/workspace/application/workspace_controller.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/staff_page.dart';
import '../../features/auth/presentation/pages/terms_page.dart';
import '../../features/products/presentation/pages/product_form_page.dart';
import '../../features/sales/domain/sale.dart';
import '../../features/sales/presentation/pages/pos_page.dart';
import '../../features/sales/presentation/pages/receipt_preview_page.dart';
import '../../features/sales/presentation/pages/sale_detail_page.dart';
import '../../features/sales/presentation/pages/sale_success_page.dart';
import '../../features/sales/presentation/pages/sales_history_page.dart';
import '../../features/workspace/presentation/pages/business_setup_page.dart';
import '../../features/workspace/presentation/pages/create_business_page.dart';
import '../../features/workspace/presentation/pages/splash_page.dart';
import '../../features/workspace/presentation/pages/verify_email_page.dart';
import '../../features/workspace/presentation/pages/workspace_picker_page.dart';
import '../../features/workspace/presentation/pages/zero_workspace_page.dart';
import '../../shared/widgets/not_found_page.dart';
import '../di/providers.dart';

/// Route paths kept in one place; screens never hardcode paths.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const terms = '/terms';
  static const verifyEmail = '/verify-email';
  static const zeroWorkspace = '/zero-workspace';
  static const createBusiness = '/create-business';
  static const setup = '/setup';
  static const picker = '/workspaces';
  static const home = '/home';
  static const pos = '/pos';
  static const posSuccess = '/pos/success';
  static const salesHistory = '/sales';
  static const staff = '/staff';

  static String receipt(String saleId) => '/pos/receipt/$saleId';
  static String saleDetail(String saleId) => '/sales/$saleId';
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
      if (_isJourneyScreen(path)) {
        return Routes.home;
      }
      return null;
  }
}

bool _isJourneyScreen(String path) =>
    path == Routes.login ||
    path == Routes.register ||
    path == Routes.verifyEmail ||
    path == Routes.zeroWorkspace ||
    path == Routes.createBusiness ||
    path == Routes.splash;

bool _isPublicScreen(String path) =>
    path == Routes.login ||
    path == Routes.register ||
    path == Routes.forgotPassword ||
    path == Routes.resetPassword ||
    path == Routes.terms;

/// Bridges [AuthState] + [WorkspaceState] changes into go_router's
/// [refreshListenable].
class _JourneyListenable extends ChangeNotifier {
  _JourneyListenable(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
    ref.listen<WorkspaceState>(
      workspaceControllerProvider,
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
        path: Routes.verifyEmail,
        builder: (_, __) => const VerifyEmailPage(),
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
        path: Routes.picker,
        builder: (_, __) => const WorkspacePickerPage(),
      ),
      GoRoute(path: Routes.setup, builder: (_, __) => const BusinessSetupPage()),
      GoRoute(
        path: Routes.home,
        builder: (_, state) => HomePage(
          initialTab: state.uri.queryParameters['tab'] == 'bidhaa' ? 1 : 0,
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
    ],
    redirect: (context, state) => journeyRedirect(
      auth: ref.read(authControllerProvider),
      workspace: ref.read(workspaceControllerProvider),
      path: state.uri.path,
    ),
    errorBuilder: (_, __) => const NotFoundPage(),
  );
});

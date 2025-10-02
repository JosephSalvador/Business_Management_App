import 'package:go_router/go_router.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/sales/presentation/pages/new_sale_page.dart';
import 'features/user_management/presentation/pages/user_management_page.dart';
import 'features/sales/presentation/pages/sales_page.dart';
import 'shared/providers/user_provider.dart';

class AppRouter {
  static GoRouter router(UserProvider userProvider) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: userProvider,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UserManagementPage(),
        ),
        // Add these routes to your existing router
GoRoute(
  path: '/sales',
  builder: (context, state) => const SalesPage(),
),
GoRoute(
     path: '/sales/new',
   builder: (context, state) => const NewSalePage(), // You can create this later
 ),
GoRoute(
  path: '/sales/history',
  builder: (context, state) => const SalesPage(), // Same as main sales page
),
      ],
      redirect: (context, state) {
        final isLoggedIn = userProvider.isLoggedIn;
        final isGoingToAuth = state.uri.path == '/login' ||
            state.uri.path == '/register' ||
            state.uri.path == '/forgot-password';

        if (!isLoggedIn && !isGoingToAuth) return '/login';
        if (isLoggedIn && isGoingToAuth) return '/dashboard';
        return null;
      },
      errorBuilder: (context, state) {
        return const DashboardPage();
      },
    );
  }
}

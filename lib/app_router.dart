import 'package:go_router/go_router.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/sales/presentation/pages/new_sale_page.dart';
import 'features/user_management/presentation/pages/user_management_page.dart';
import 'features/sales/presentation/pages/sales_page.dart';
import 'shared/providers/user_provider.dart';
import 'shared/widgets/not_found_page.dart';

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
        GoRoute(
          path: '/sales',
          builder: (context, state) => const SalesPage(),
        ),
        GoRoute(
          path: '/sales/new',
          builder: (context, state) => const NewSalePage(),
        ),
        GoRoute(
          path: '/sales/history',
          builder: (context, state) => const SalesPage(),
        ),
      ],
      redirect: (context, state) {
        final isLoggedIn = userProvider.isLoggedIn;
        final currentPath = state.uri.path;
        const authPaths = {
          '/login',
          '/register',
          '/forgot-password',
        };
        const validPaths = {
          '/login',
          '/register',
          '/forgot-password',
          '/dashboard',
          '/users',
          '/sales',
          '/sales/new',
          '/sales/history',
        };
        final isKnownRoute = validPaths.contains(currentPath);
        final isGoingToAuth = authPaths.contains(currentPath);

        if (!isKnownRoute) return null;
        if (!isLoggedIn && !isGoingToAuth) return '/login';
        if (isLoggedIn && isGoingToAuth) return '/dashboard';
        return null;
      },
      errorBuilder: (context, state) {
        return const NotFoundPage();
      },
    );
  }
}

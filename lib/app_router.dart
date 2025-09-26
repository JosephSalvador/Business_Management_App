import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'shared/providers/user_provider.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
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
    ],
    redirect: (context, state) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final isLoggedIn = userProvider.isLoggedIn;
      final isGoingToAuth = state.uri.path == '/login' || 
                           state.uri.path == '/register' || 
                           state.uri.path == '/forgot-password';

      if (!isLoggedIn && !isGoingToAuth) {
        return '/login';
      }

      if (isLoggedIn && isGoingToAuth) {
        return '/dashboard';
      }

      return null;
    },
  );
}
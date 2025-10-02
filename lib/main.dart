import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'shared/providers/user_provider.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/local_storage_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final GoRouter router = AppRouter.router(userProvider);

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => AuthBloc(authRepository: AuthRepositoryImpl())
                  ..add(AuthCheckRequested()),
              ),
            ],
            child: MaterialApp.router(
              title: 'Business Management System',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.light,
              routerConfig: router,
            ),
          );
        },
      ),
    );
  }
}

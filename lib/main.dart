import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'shared/services/local_storage_service.dart';
import 'shared/providers/user_provider.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GoRouter _router = AppRouter.router;

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ Add UserProvider here
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),

        // ✅ Provide AuthBloc
        BlocProvider(
          create: (context) => AuthBloc(
            authRepository: AuthRepositoryImpl(),
          )..add(AuthCheckRequested()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Business Management System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }
}

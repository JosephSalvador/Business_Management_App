import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../shared/models/user_model.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
  }

  void _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(event.username, event.password);
      emit(AuthSuccess(user: user));
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  void _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.logout();
      emit(AuthInitial());
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
      emit(AuthInitial());
      return;
    }

    final userJsonString = prefs.getString('userData');
    if (userJsonString == null || userJsonString.isEmpty) {
      emit(AuthInitial());
      return;
    }

    try {
      final userMap = jsonDecode(userJsonString) as Map<String, dynamic>;
      emit(AuthSuccess(user: User.fromJson(userMap)));
    } catch (_) {
      emit(AuthInitial());
    }
  }
}

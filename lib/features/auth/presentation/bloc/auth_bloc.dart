import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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

  void _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) {
    // Check if user is already logged in (from local storage)
    emit(AuthInitial());
  }
}
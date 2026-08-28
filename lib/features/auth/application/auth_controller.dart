import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/session.dart';

/// Authentication lifecycle state.
sealed class AuthState {
  const AuthState();
}

/// Bootstrapping: restoring a previous session from secure storage.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});

  /// Optional user-facing reason (e.g. "session expired").
  final String? message;
}

/// Registration succeeded but the email address is not confirmed yet.
class AuthNeedsVerification extends AuthState {
  const AuthNeedsVerification({required this.email});

  final String email;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final Session session;
}

/// Drives routing decisions and every authenticated screen.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository)
      : super(const AuthUnknown()) {
    // Route session-expiry signals from the API layer into state changes.
    _repository.apiClient.onSessionExpired = markSessionExpired;
  }

  final AuthRepository _repository;

  /// Restores a stored session at app start. Watch-dogged: a hung token read
  /// or network call must never park the journey on the splash screen — the
  /// worst case degrades to the login page.
  Future<void> bootstrap() async {
    try {
      final session = await _repository
          .restore()
          .timeout(const Duration(seconds: 10));
      state = session == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(session);
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final session = await _repository.login(identifier: identifier, password: password);
    state = AuthAuthenticated(session);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? organizationName,
  }) async {
    await _repository.register(
      email: email,
      password: password,
      fullName: fullName,
      organizationName: organizationName,
      phone: phone,
    );
    state = AuthNeedsVerification(email: email.trim().toLowerCase());
  }

  /// Registers a staff member with an owner-issued invitation code. Leads to
  /// the same pending-verification state as [register].
  Future<void> registerStaff({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String invitationCode,
  }) async {
    await _repository.registerStaff(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      invitationCode: invitationCode,
    );
    state = AuthNeedsVerification(email: email.trim().toLowerCase());
  }

  /// Confirms the pending registration with the emailed code. On success the
  /// user returns to the login screen — no session is kept, and no password
  /// is ever retained in memory beyond the submit call.
  Future<void> verifyEmail({required String code}) async {
    final current = state;
    if (current is! AuthNeedsVerification) {
      return;
    }
    await _repository.verifyEmail(email: current.email, code: code);
    state = const AuthUnauthenticated(
      message: 'Barua pepe imethibitika. Tafadhali ingia.',
    );
  }

  /// Queues a fresh verification code for the pending registration.
  Future<void> resendVerificationCode() async {
    final current = state;
    if (current is! AuthNeedsVerification) {
      return;
    }
    await _repository.resendVerificationCode(email: current.email);
  }

  /// Requests a password reset email. Does not change the auth state.
  Future<void> requestPasswordReset({required String email}) async {
    await _repository.requestPasswordReset(email: email);
  }

  /// Sets a new password using an emailed reset code. The user then signs in
  /// again with fresh credentials.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _repository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  /// Fired by the API layer when refresh fails mid-session.
  void markSessionExpired() {
    if (state is! AuthUnauthenticated) {
      state = const AuthUnauthenticated(
        message: 'Kipindi kimeisha. Tafadhali ingia tena.',
      );
    }
  }
}

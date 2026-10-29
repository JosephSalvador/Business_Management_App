import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../../notifications/application/device_registration_service.dart';
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
  const AuthAuthenticated(this.session, {this.isOffline = false});

  final Session session;

  /// Whether this session was established offline (limited functionality).
  final bool isOffline;
}

/// The password was accepted but a second factor must be proven before any
/// token is issued. Nothing has been stored yet: [AuthController.verifyTwoFactor]
/// either completes the sign-in or returns to [AuthUnauthenticated].
class AuthNeedsTwoFactor extends AuthState {
  const AuthNeedsTwoFactor({
    required this.challengeToken,
    required this.email,
  });

  final String challengeToken;

  /// Echoed from the backend so the user knows which account is waiting, even
  /// when they signed in with a phone number.
  final String email;
}

/// The device session is valid but the app is idle/background-locked.
///
/// Distinct from a cold start: the session was already trusted, so the user
/// only needs the fast factor (biometric or unlock PIN) to get back to work —
/// no password, and offline-capable. Nothing (cart, navigator state) is torn
/// down by locking; [unlock] simply restores [AuthAuthenticated].
class AuthLocked extends AuthState {
  const AuthLocked(this.session, {this.isOffline = false});

  final Session session;

  /// Whether the locked session was an offline session.
  final bool isOffline;
}

/// Drives routing decisions and every authenticated screen.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    repository.apiClient.onSessionExpired = markSessionExpired;
    Future.microtask(bootstrap);
    return const AuthUnknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Restores a stored session at app start. Watch-dogged: a hung token read
  /// or network call must never park the journey on the splash screen — the
  /// worst case degrades to the login page.
  ///
  /// Falls back to offline session restore if the backend is unreachable
  /// and a valid offline token exists.
  Future<void> bootstrap() async {
    try {
      final session =
          await _repository.restore().timeout(const Duration(seconds: 10));

      if (session != null) {
        state = AuthAuthenticated(session);
      } else {
        state = const AuthUnauthenticated();
      }
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final outcome =
          await _repository.login(identifier: identifier, password: password);
      switch (outcome) {
        case AuthenticatedLogin(:final session):
          state = AuthAuthenticated(session);
          ref.read(deviceRegistrationServiceProvider).registerDevice();
        case MfaChallenge(:final challengeToken, :final email):
          state = AuthNeedsTwoFactor(
            challengeToken: challengeToken,
            email: email.isNotEmpty ? email : identifier.trim(),
          );
      }
    } on AccountNotVerifiedException catch (error) {
      // The account exists but its email is still unverified. Route the user
      // to the verification screen (the router redirects AuthNeedsVerification
      // to /verify-email) so they can resend and enter the code.
      final email = error.email.isNotEmpty
          ? error.email
          : _emailFromIdentifier(identifier);
      if (email.isEmpty) {
        rethrow;
      }
      state = AuthNeedsVerification(email: email);
    } on NetworkException catch (error) {
      await _silentOfflineFallback(
        identifier: identifier,
        password: password,
        originalError: error,
      );
    } on TimeoutException catch (error) {
      await _silentOfflineFallback(
        identifier: identifier,
        password: password,
        originalError: error,
      );
    } on ServerException catch (error) {
      await _silentOfflineFallback(
        identifier: identifier,
        password: password,
        originalError: error,
      );
    }
  }

  /// Offline-invisible fallback: when the backend is unreachable, verify the
  /// password against the stored hash and start a limited offline session —
  /// the user never knows the network failed. Only engages when the typed
  /// identifier matches the cached account, so a wrong-account attempt cannot
  /// unlock someone else's offline data.
  Future<void> _silentOfflineFallback({
    required String identifier,
    required String password,
    required AppException originalError,
  }) async {
    final cachedEmail =
        await _repository.offlineCredentialStore.getCachedEmail();
    final identifierMatches = cachedEmail != null &&
        cachedEmail.trim().toLowerCase() == identifier.trim().toLowerCase();
    if (!identifierMatches) {
      state = AuthUnauthenticated(message: originalError.message);
      return;
    }
    try {
      final session = await _repository.loginOffline(password: password);
      if (session != null) {
        state = AuthAuthenticated(session, isOffline: true);
        return;
      }
      // No offline capability on this device.
      state = AuthUnauthenticated(message: originalError.message);
    } on ValidationException {
      // Wrong password offline surfaces the same neutral message as online.
      rethrow;
    }
  }

  /// Locks the current session (idle/background auto-lock). Non-destructive:
  /// the stored [Session] is retained so [unlock] can resume without a
  /// password. No-op unless currently authenticated.
  void lock() {
    final current = state;
    if (current is! AuthAuthenticated) return;
    state = AuthLocked(current.session, isOffline: current.isOffline);
  }

  /// Reopens an idle-locked session with a fresh hardware biometric match.
  /// No password and no quick-unlock token are required — the session was
  /// already trusted on this device. Falls back to the login page when no
  /// usable fast factor exists.
  Future<void> unlock() async {
    final current = state;
    if (current is! AuthLocked) return;
    final biometricGate = ref.read(biometricAuthGateProvider);
    final biometricOk = await biometricGate.authenticate(
      reason: 'Thibitisha utambulisho ili kufungua',
    );
    if (!biometricOk) {
      state = AuthUnauthenticated(
        message: 'Uthibitisho umeshindikana. Ingia kwa nenosiri.',
      );
      return;
    }
    state = AuthAuthenticated(current.session, isOffline: current.isOffline);
  }

  /// Completes a pending second-factor sign-in. [useRecoveryCode] selects a
  /// printed recovery code instead of an authenticator code; the two are kept as
  /// separate calls rather than one string because the user must choose
  /// deliberately.
  ///
  /// A wrong code leaves the state as [AuthNeedsTwoFactor] so the user can retry
  /// without retyping the password. An expired challenge, which cannot be retried,
  /// returns to [AuthUnauthenticated] and asks for a fresh sign-in.
  Future<void> verifyTwoFactor({
    required String code,
    bool useRecoveryCode = false,
  }) async {
    final current = state;
    if (current is! AuthNeedsTwoFactor) return;

    try {
      final session = await _repository.completeTwoFactorChallenge(
        challengeToken: current.challengeToken,
        code: code,
        useRecoveryCode: useRecoveryCode,
      );
      state = AuthAuthenticated(session);
    } on UnauthorizedException {
      // The backend answers 401 both for a wrong code and for an expired
      // challenge, and the client cannot tell them apart — so send the user
      // back to a fresh sign-in rather than leaving them retrying a token the
      // server has already dropped.
      state = const AuthUnauthenticated(
        message: 'Msimamizi hajakubali kila hatua. Ingiza tena.',
      );
    }
    // A ValidationException (wrong code, challenge still alive) is left to
    // propagate so the challenge screen can show the message inline without
    // losing the pending state.
  }

  /// Abandons a pending second-factor step and returns to the login screen.
  Future<void> cancelTwoFactor() async {
    if (state is! AuthNeedsTwoFactor) return;
    state = const AuthUnauthenticated();
  }

  /// Reopens an idle-locked session with the local unlock PIN (verified with
  /// lockout). Falls back to the login page on failure.
  Future<void> unlockWithPin({required String pin}) async {
    final current = state;
    if (current is! AuthLocked) return;
    final verified =
        await _repository.offlineCredentialStore.verifyUnlockPin(pin);
    if (!verified) {
      throw ValidationException('PIN si sahihi. Jaribu tena.');
    }
    state = AuthAuthenticated(current.session, isOffline: current.isOffline);
  }

  /// Authenticates offline using stored credentials.
  ///
  /// Requires:
  /// 1. A previous successful online login (to store password hash)
  /// 2. Correct password
  /// 3. Biometric verification (on supported devices)
  ///
  /// On success, the user gets an offline session with limited functionality
  /// (POS sales only, no dashboard, no reports, no customer management).
  Future<void> loginOffline({
    required String password,
  }) async {
    try {
      final biometricGate = ref.read(biometricAuthGateProvider);
      final session = await _repository.loginOffline(
        password: password,
        biometricGate: biometricGate,
      );
      if (session != null) {
        state = AuthAuthenticated(session, isOffline: true);
      } else {
        state = const AuthUnauthenticated(
          message: 'Hakuna nyaraka za kuuza nje ya mtandao. '
              'Ingia kwenye mtandao kwanza.',
        );
      }
    } on ValidationException catch (error) {
      state = AuthUnauthenticated(message: error.message);
    }
  }

  /// Biometric-only quick unlock. No password required — the device is
  /// trusted from a previous password-verified login. Falls back to the
  /// login screen when unavailable on this device.
  Future<void> loginWithBiometric() async {
    try {
      final biometricGate = ref.read(biometricAuthGateProvider);
      final session = await _repository.loginWithBiometric(
        biometricGate: biometricGate,
      );
      if (session != null) {
        state = AuthAuthenticated(session, isOffline: true);
      } else {
        state = const AuthUnauthenticated(
          message: 'Hakuna njia ya kuingia kwa haraka. Ingia kwa nenosiri.',
        );
      }
    } on ValidationException catch (error) {
      state = AuthUnauthenticated(message: error.message);
    }
  }

  /// Fast cold-start unlock with the local PIN (device already trusted — the
  /// PIN release the stored trusted session). No password, no biometric.
  Future<void> loginWithPin({required String pin}) async {
    try {
      final session = await _repository.unlockWithPin(pin: pin);
      if (session != null) {
        state = AuthAuthenticated(session, isOffline: true);
      } else {
        state = const AuthUnauthenticated(
          message: 'Hakuna njia ya kuingia kwa haraka. Ingia kwa nenosiri.',
        );
      }
    } on ValidationException catch (error) {
      state = AuthUnauthenticated(message: error.message);
    }
  }

  /// First-use cold-start unlock on a device without a biometric sensor:
  /// sets the 4–6 digit unlock PIN, then releases the trusted session.
  Future<void> setupPin({required String pin}) async {
    try {
      final session = await _repository.setupPinAndUnlock(pin: pin);
      if (session != null) {
        state = AuthAuthenticated(session, isOffline: true);
      } else {
        state = const AuthUnauthenticated(
          message: 'Hakuna njia ya kuingia kwa haraka. Ingia kwa nenosiri.',
        );
      }
    } on ValidationException catch (error) {
      state = AuthUnauthenticated(message: error.message);
    }
  }

  /// Sets up a Quick PIN and optional biometric unlock for this device.
  Future<void> enableQuickPin({
    required String pin,
    bool enableBiometric = false,
  }) async {
    await _repository.enableQuickPin(
      pin: pin,
      enableBiometric: enableBiometric,
    );
  }

  /// Disables Quick PIN and quick unlock on this device.
  Future<void> disableQuickPin() async {
    await _repository.disableQuickPin();
  }

  /// Updates biometric toggle preference on this device.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _repository.setBiometricEnabled(enabled);
  }

  /// Best-effort fallback when the backend did not return the account email:
  /// reuse the identifier when it looks like an email address.
  static String _emailFromIdentifier(String identifier) {
    final trimmed = identifier.trim().toLowerCase();
    return trimmed.contains('@') ? trimmed : '';
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? organizationName,
  }) async {
    final registered = await _repository.register(
      email: email,
      password: password,
      fullName: fullName,
      organizationName: organizationName,
      phone: phone,
    );
    if (registered.emailVerified) {
      await login(identifier: email, password: password);
    } else {
      state = AuthNeedsVerification(email: email.trim().toLowerCase());
    }
  }

  /// Registers a staff member with an owner-issued invitation code. Leads to
  /// the same pending-verification state as [register] unless already verified.
  Future<void> registerStaff({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String invitationCode,
  }) async {
    final registered = await _repository.registerStaff(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      invitationCode: invitationCode,
    );
    if (registered.emailVerified) {
      await login(identifier: email, password: password);
    } else {
      state = AuthNeedsVerification(email: email.trim().toLowerCase());
    }
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
    try {
      await ref.read(deviceRegistrationServiceProvider).unregisterDevice();
    } catch (_) {}
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/auth_providers.dart';
import '../data/security_repository.dart';
import '../domain/session.dart';

/// State for the own-account security screen: the second-factor status and the
/// user's device list, plus any enrolment flow currently in progress.
///
/// Kept as a single controller because the two lists change together — enabling
/// a factor invalidates nothing, but revoking a session can invalidate the one
/// this device is using, so the screen always reloads as a unit rather than
/// leaving a stale device list next to a fresh status.
sealed class SecurityState {
  const SecurityState();
}

class SecurityLoading extends SecurityState {
  const SecurityLoading();
}

class SecurityLoaded extends SecurityState {
  const SecurityLoaded({required this.mfa, required this.sessions});

  final MfaStatus mfa;
  final List<AuthSessionDevice> sessions;
}

class SecurityFailure extends SecurityState {
  const SecurityFailure(this.message);

  final String message;
}

/// A staged enrolment waiting for a code. Held in state rather than passed
/// between widgets so a rotation or a screen rebuild cannot lose the secret the
/// user is currently transcribing.
class SecurityEnrolling extends SecurityState {
  const SecurityEnrolling({
    required this.base,
    required this.enrollment,
  });

  final SecurityLoaded base;
  final TwoFactorEnrollment enrollment;
}

/// Recovery codes just issued. The server returns them exactly once, so this is
/// the only moment they can be shown; [acknowledged] gates dismissal.
class SecurityRecoveryCodes extends SecurityState {
  const SecurityRecoveryCodes({
    required this.base,
    required this.codes,
    this.acknowledged = false,
  });

  final SecurityLoaded base;
  final RecoveryCodes codes;

  /// Set once the user confirms they have saved them. Dismissal is blocked until
  /// then, because these are unrecoverable afterwards.
  final bool acknowledged;

  SecurityRecoveryCodes copyWith({bool? acknowledged}) => SecurityRecoveryCodes(
        base: base,
        codes: codes,
        acknowledged: acknowledged ?? this.acknowledged,
      );
}

class SecurityController extends Notifier<SecurityState> {
  @override
  SecurityState build() {
    Future.microtask(load);
    return const SecurityLoading();
  }

  SecurityRepository get _repository => ref.read(securityRepositoryProvider);

  Future<void> load() async {
    state = const SecurityLoading();
    try {
      final results = await Future.wait([
        _repository.fetchMfaStatus(),
        _repository.listSessions(),
      ]);
      state = SecurityLoaded(
        mfa: results[0] as MfaStatus,
        sessions: results[1] as List<AuthSessionDevice>,
      );
    } on AppException catch (error) {
      state = SecurityFailure(error.message);
    }
  }

  Future<void> beginSetup() async {
    final base = state;
    if (base is! SecurityLoaded) return;

    try {
      final enrollment = await _repository.beginTwoFactorSetup();
      state = SecurityEnrolling(base: base, enrollment: enrollment);
    } on AppException catch (error) {
      state = SecurityFailure(error.message);
    }
  }

  Future<void> cancelSetup() {
    // The staged secret stays on the server until it is replaced or confirmed.
    // Returning to the previous view is correct: nothing has been activated, and
    // a later setup call simply overwrites it.
    final current = state;
    if (current is SecurityEnrolling) state = current.base;
    return Future.value();
  }

  Future<void> confirmSetup(String code) async {
    final current = state;
    if (current is! SecurityEnrolling) return;

    try {
      final codes = await _repository.confirmTwoFactor(code);

      // The device list is untouched by enrolment, so it is reused. Status *is*
      // refetched rather than patched locally: `enabledAt` and the recovery-code
      // count are server facts, and guessing them here would drift.
      final mfa = await _repository.fetchMfaStatus();
      state = SecurityRecoveryCodes(
        base: SecurityLoaded(mfa: mfa, sessions: current.base.sessions),
        codes: codes,
      );
    } on AppException catch (error) {
      // A wrong code leaves the enrolment in place so it can be retried, and
      // surfaces the message rather than dropping back to the status view.
      state = SecurityEnrollFailure(
        base: current.base,
        enrollment: current.enrollment,
        message: error.message,
      );
    }
  }

  void acknowledgeRecoveryCodes() {
    final current = state;
    if (current is SecurityRecoveryCodes && current.acknowledged == false) {
      state = current.copyWith(acknowledged: true);
    }
  }

  /// Turns the factor off. The backend requires a current code, so it cannot be
  /// called from a button press alone: a hijacked live session must not be able
  /// to downgrade the account's security silently.
  Future<void> disable(String code) async {
    final base = state;
    if (base is! SecurityLoaded) return;

    try {
      await _repository.disableTwoFactor(code);
      await load();
    } on AppException catch (error) {
      state = SecurityFailure(error.message);
    }
  }

  Future<void> regenerateRecoveryCodes() async {
    final base = state;
    if (base is! SecurityLoaded || !base.mfa.enabled) return;

    try {
      final codes = await _repository.regenerateRecoveryCodes();
      state = SecurityRecoveryCodes(base: base, codes: codes);
    } on AppException catch (error) {
      state = SecurityFailure(error.message);
    }
  }

  Future<void> revokeSession(String familyId) async {
    try {
      await _repository.revokeSession(familyId);
      await load();
    } on AppException catch (error) {
      state = SecurityFailure(error.message);
    }
  }

  Future<void> revokeAllSessions() async {
    try {
      await _repository.revokeAllSessions();
      await load();
    } on AppException catch (error) {
      state = SecurityFailure(error.message);
    }
  }
}

/// A failed confirm, kept distinct from [SecurityFailure] so the staged secret
/// stays on screen instead of being lost behind an error page.
class SecurityEnrollFailure extends SecurityState {
  const SecurityEnrollFailure({
    required this.base,
    required this.enrollment,
    required this.message,
  });

  final SecurityLoaded base;
  final TwoFactorEnrollment enrollment;
  final String message;
}

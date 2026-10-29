import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/money_account_repository.dart';

sealed class CashSessionState {
  const CashSessionState();
}

class CashSessionLoading extends CashSessionState {
  const CashSessionLoading();
}

class CashSessionLoaded extends CashSessionState {
  const CashSessionLoaded({this.session});

  final Map<String, dynamic>? session;

  bool get hasOpenSession => session != null && session!['status'] == 0;
}

class CashSessionFailure extends CashSessionState {
  const CashSessionFailure(this.message);

  final String message;
}

class CashSessionController extends Notifier<CashSessionState> {
  @override
  CashSessionState build() => const CashSessionLoading();

  MoneyAccountRepository get _repository =>
      ref.read(moneyAccountRepositoryProvider);

  Future<void> load(String accountId) async {
    state = const CashSessionLoading();
    try {
      final session = await _repository.getCurrentSession(accountId);
      state = CashSessionLoaded(session: session);
    } catch (_) {
      state = const CashSessionLoaded(session: null);
    }
  }

  Future<Map<String, dynamic>> openSession(
    String accountId,
    double openingCash,
  ) async {
    final session = await _repository.openSession({
      'accountId': accountId,
      'openingCash': openingCash,
    });
    state = CashSessionLoaded(session: session);
    return session;
  }

  Future<Map<String, dynamic>> closeSession(
    String sessionId,
    double closingCash,
    String? notes,
    String accountId, {
    double? expectedCash,
  }) async {
    final session = await _repository.closeSession(sessionId, {
      'accountId': accountId,
      'closingCash': closingCash,
      if (expectedCash != null) 'expectedCash': expectedCash,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    state = const CashSessionLoaded(session: null);
    return session;
  }

  void reset() {
    state = const CashSessionLoading();
  }
}

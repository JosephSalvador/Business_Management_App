import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
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
    } on AppException catch (e) {
      state = CashSessionFailure(e.message);
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
    await load(accountId);
    return session;
  }

  Future<Map<String, dynamic>> closeSession(
    String sessionId,
    double closingCash,
    String? notes,
    String accountId,
  ) async {
    final session = await _repository.closeSession(sessionId, {
      'closingCash': closingCash,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    await load(accountId);
    return session;
  }

  void reset() {
    state = const CashSessionLoading();
  }
}

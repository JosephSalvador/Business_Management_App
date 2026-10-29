import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_monitor.dart';
import '../data/customer_repository.dart';

sealed class CustomersState {
  const CustomersState();
}

class CustomersLoading extends CustomersState {
  const CustomersLoading({this.search = ''});

  final String search;
}

class CustomersLoaded extends CustomersState {
  const CustomersLoaded({
    required this.items,
    required this.total,
    this.search = '',
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final String search;

  bool get isEmpty => items.isEmpty;
}

class CustomersFailure extends CustomersState {
  const CustomersFailure(this.message);

  final String message;
}

class CustomersController extends Notifier<CustomersState> {
  String _search = '';

  @override
  CustomersState build() => const CustomersLoading();

  CustomerRepository get _repository => ref.read(customerRepositoryProvider);
  OfflineCustomerDebtService get _offlineDebt =>
      ref.read(offlineCustomerDebtServiceProvider);

  Future<void> load({String? search, bool silent = false}) async {
    if (search != null) {
      _search = search;
    }
    if (!silent || state is! CustomersLoaded) {
      state = CustomersLoading(search: _search);
    }
    try {
      final result = await _repository.list(search: _search);
      state = CustomersLoaded(
        items: result.items,
        total: result.total,
        search: _search,
      );
    } on AppException catch (e) {
      state = CustomersFailure(e.message);
    } catch (e) {
      state = CustomersFailure(e.toString());
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return _repository.getById(id);
  }

  Future<void> create(Map<String, dynamic> body) async {
    try {
      await _repository.create(body);
    } catch (_) {}
    await load(silent: true);
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _repository.update(id, body);
    await load();
  }

  Future<Map<String, dynamic>?> getCredit(String customerId) async {
    final pendingDeduction =
        await _offlineDebt.getPendingDebtDeduction(customerId);
    try {
      final remote = await _repository.getCredit(customerId);
      if (remote == null) return null;
      if (pendingDeduction > 0) {
        final currentBalance =
            (remote['balance'] as num?)?.toDouble() ?? 0.0;
        final adjusted =
            (currentBalance - pendingDeduction).clamp(0.0, double.infinity);
        return {
          ...remote,
          'balance': adjusted,
          'pendingOfflinePayment': pendingDeduction,
        };
      }
      return remote;
    } catch (_) {
      if (pendingDeduction > 0) {
        return {
          'customerId': customerId,
          'balance': 0.0,
          'creditLimit': 0.0,
          'pendingOfflinePayment': pendingDeduction,
        };
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getOutstandingCredit() async {
    return _repository.getOutstandingCredit();
  }

  Future<void> recordPayment(
    String customerId,
    double amount,
    String description, {
    String customerName = 'Mteja',
    String paymentMethod = 'Pesa Taslimu',
  }) async {
    final connection = ref.read(connectionQualityProvider);
    if (connection == ConnectionQuality.offline ||
        connection == ConnectionQuality.unreachable) {
      await _offlineDebt.recordOfflinePayment(
        customerId: customerId,
        customerName: customerName,
        amount: amount,
        description: description,
        paymentMethod: paymentMethod,
      );
      return;
    }

    try {
      await _repository.recordPayment(customerId, amount, description);
    } on AppException catch (e) {
      if (e is NetworkException || e is TimeoutException) {
        await _offlineDebt.recordOfflinePayment(
          customerId: customerId,
          customerName: customerName,
          amount: amount,
          description: description,
          paymentMethod: paymentMethod,
        );
      } else {
        rethrow;
      }
    }
  }

  void reset() {
    _search = '';
    state = const CustomersLoading();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
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
      if (state is! CustomersLoaded) {
        state = CustomersFailure(e.message);
      }
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return _repository.getById(id);
  }

  Future<void> create(Map<String, dynamic> body) async {
    await _repository.create(body);
    await load();
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _repository.update(id, body);
    await load();
  }

  Future<Map<String, dynamic>?> getCredit(String customerId) async {
    return _repository.getCredit(customerId);
  }

  Future<List<Map<String, dynamic>>> getOutstandingCredit() async {
    return _repository.getOutstandingCredit();
  }

  Future<void> recordPayment(
      String customerId, double amount, String description) async {
    await _repository.recordPayment(customerId, amount, description);
  }

  void reset() {
    _search = '';
    state = const CustomersLoading();
  }
}

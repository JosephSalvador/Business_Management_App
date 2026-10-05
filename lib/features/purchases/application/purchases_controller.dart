import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/purchase_repository.dart';

sealed class PurchasesState {
  const PurchasesState();
}

class PurchasesLoading extends PurchasesState {
  const PurchasesLoading({this.search = ''});

  final String search;
}

class PurchasesLoaded extends PurchasesState {
  const PurchasesLoaded({
    required this.items,
    required this.total,
    this.search = '',
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final String search;

  bool get isEmpty => items.isEmpty;
}

class PurchasesFailure extends PurchasesState {
  const PurchasesFailure(this.message);

  final String message;
}

class PurchasesController extends Notifier<PurchasesState> {
  String _search = '';

  @override
  PurchasesState build() => const PurchasesLoading();

  PurchaseRepository get _repository => ref.read(purchaseRepositoryProvider);

  Future<void> load({String? search}) async {
    if (search != null) {
      _search = search;
    }
    state = PurchasesLoading(search: _search);
    try {
      final page = await _repository.list(search: _search);
      state = PurchasesLoaded(
        items: page.items,
        total: page.total,
        search: _search,
      );
    } on AppException catch (error) {
      state = PurchasesFailure(error.message);
    }
  }

  Future<void> create(Map<String, dynamic> body) async {
    await _repository.create(body);
    await load();
  }

  Future<void> submit(String id) async {
    await _repository.submit(id);
    await load();
  }

  Future<void> cancel(String id) async {
    await _repository.cancel(id);
    await load();
  }

  void reset() {
    _search = '';
    state = const PurchasesLoading();
  }
}

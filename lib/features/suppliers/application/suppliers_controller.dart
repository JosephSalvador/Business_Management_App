import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/supplier_repository.dart';

sealed class SuppliersState {
  const SuppliersState();
}

class SuppliersLoading extends SuppliersState {
  const SuppliersLoading({this.search = ''});

  final String search;
}

class SuppliersLoaded extends SuppliersState {
  const SuppliersLoaded({
    required this.items,
    required this.total,
    this.search = '',
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final String search;

  bool get isEmpty => items.isEmpty;
}

class SuppliersFailure extends SuppliersState {
  const SuppliersFailure(this.message);

  final String message;
}

class SuppliersController extends Notifier<SuppliersState> {
  String _search = '';

  @override
  SuppliersState build() => const SuppliersLoading();

  SupplierRepository get _repository => ref.read(supplierRepositoryProvider);

  Future<void> load({String? search}) async {
    if (search != null) {
      _search = search;
    }
    state = SuppliersLoading(search: _search);
    try {
      final page = await _repository.list(search: _search);
      state = SuppliersLoaded(
        items: page.items,
        total: page.total,
        search: _search,
      );
    } on AppException catch (error) {
      state = SuppliersFailure(error.message);
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final supplier = await _repository.create(body);
    await load();
    return supplier;
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final supplier = await _repository.update(id, body);
    await load();
    return supplier;
  }

  void reset() {
    _search = '';
    state = const SuppliersLoading();
  }
}

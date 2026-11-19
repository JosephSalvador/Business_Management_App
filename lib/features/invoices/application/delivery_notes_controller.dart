import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/delivery_note_repository.dart';
import '../data/invoice_providers.dart';
import '../domain/delivery_note.dart';

sealed class DeliveryNotesState {
  const DeliveryNotesState();
}

class DeliveryNotesLoading extends DeliveryNotesState {
  const DeliveryNotesLoading({this.search = '', this.status});

  final String search;
  final DeliveryNoteStatus? status;
}

class DeliveryNotesLoaded extends DeliveryNotesState {
  const DeliveryNotesLoaded({
    required this.items,
    required this.total,
    required this.page,
    this.search = '',
    this.status,
  });

  final List<DeliveryNoteSummary> items;
  final int total;
  final int page;
  final String search;
  final DeliveryNoteStatus? status;

  bool get isEmpty => items.isEmpty;

  bool get hasMore => items.length < total;
}

class DeliveryNotesFailure extends DeliveryNotesState {
  const DeliveryNotesFailure(this.message);

  final String message;
}

class DeliveryNotesController extends Notifier<DeliveryNotesState> {
  String _search = '';
  DeliveryNoteStatus? _status;
  bool _loadingMore = false;
  Future<void>? _inFlight;

  @override
  DeliveryNotesState build() => const DeliveryNotesLoading();

  DeliveryNoteRepository get _repository =>
      ref.read(deliveryNoteRepositoryProvider);

  Future<void> load({
    String? search,
    DeliveryNoteStatus? status,
    bool clearStatus = false,
    bool silent = false,
  }) {
    if (search != null) _search = search;
    if (clearStatus) {
      _status = null;
    } else if (status != null) {
      _status = status;
    }
    return _run(
      () => _repository.list(
        page: 1,
        search: _search,
        status: _status,
      ),
      silent: silent,
    );
  }

  Future<void> refresh() => load();

  Future<void> toggleStatus(DeliveryNoteStatus status) {
    if (_status == status) return load(clearStatus: true);
    return load(status: status);
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! DeliveryNotesLoaded || !current.hasMore || _loadingMore) {
      return;
    }
    _loadingMore = true;
    try {
      final result = await _repository.list(
        page: current.page + 1,
        search: current.search,
        status: current.status,
      );
      state = DeliveryNotesLoaded(
        items: [...current.items, ...result.items],
        total: result.total,
        page: result.page,
        search: current.search,
        status: current.status,
      );
    } on AppException {
      return;
    } finally {
      _loadingMore = false;
    }
  }

  Future<DeliveryNote?> getById(String id) async {
    try {
      return await _repository.getById(id);
    } on AppException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _run(
    Future<DeliveryNotePage> Function() fetch, {
    bool silent = false,
  }) async {
    final request = () async {
      if (!silent || state is! DeliveryNotesLoaded) {
        state = DeliveryNotesLoading(search: _search, status: _status);
      }
      try {
        final result = await fetch();
        state = DeliveryNotesLoaded(
          items: result.items,
          total: result.total,
          page: result.page,
          search: _search,
          status: _status,
        );
      } catch (_) {
        if (state is! DeliveryNotesLoaded) {
          state = DeliveryNotesLoaded(
            items: const [],
            total: 0,
            page: 1,
            search: _search,
            status: _status,
          );
        }
      }
    }();
    _inFlight = request;
    try {
      await request;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  void reset() {
    _search = '';
    _status = null;
    state = const DeliveryNotesLoading();
  }
}

final deliveryNotesControllerProvider =
    NotifierProvider<DeliveryNotesController, DeliveryNotesState>(
  DeliveryNotesController.new,
);

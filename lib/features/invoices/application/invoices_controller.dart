import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/invoice_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice.dart';

sealed class InvoicesState {
  const InvoicesState();
}

class InvoicesLoading extends InvoicesState {
  const InvoicesLoading({this.search = '', this.status});

  final String search;
  final InvoiceStatus? status;
}

class InvoicesLoaded extends InvoicesState {
  const InvoicesLoaded({
    required this.items,
    required this.total,
    required this.page,
    this.search = '',
    this.status,
  });

  final List<CustomerInvoiceSummary> items;
  final int total;
  final int page;
  final String search;
  final InvoiceStatus? status;

  bool get isEmpty => items.isEmpty;

  bool get hasMore => items.length < total;
}

class InvoicesFailure extends InvoicesState {
  const InvoicesFailure(this.message);

  final String message;
}

class InvoicesController extends Notifier<InvoicesState> {
  String _search = '';
  InvoiceStatus? _status;
  bool _loadingMore = false;
  Future<void>? _inFlight;

  @override
  InvoicesState build() => const InvoicesLoading();

  InvoiceRepository get _repository => ref.read(invoiceRepositoryProvider);

  Future<void> load({
    String? search,
    InvoiceStatus? status,
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

  Future<void> toggleStatus(InvoiceStatus status) {
    if (_status == status) return load(clearStatus: true);
    return load(status: status);
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! InvoicesLoaded || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final result = await _repository.list(
        page: current.page + 1,
        search: current.search,
        status: current.status,
      );
      state = InvoicesLoaded(
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

  Future<CustomerInvoice?> getById(String id) async {
    try {
      return await _repository.getById(id);
    } on AppException catch (error) {
      state = InvoicesFailure(error.message);
      return null;
    }
  }

  Future<CustomerInvoice?> create({
    required List<InvoiceDraftLine> lines,
    String? customerId,
    String? customerName,
    String? customerAttention,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerTin,
    String currency = 'TZS',
    String documentTitle = 'INVOICE',
    String? referenceNumber,
    String? paymentTerms,
    DateTime? issueDate,
    DateTime? dueDate,
    double discountAmount = 0,
    double initialAmountPaid = 0,
    String? paymentMethod,
    String? paymentReference,
    String? paymentInstructions,
    String? notes,
    String? authorizedSignatoryName,
    String? authorizedSignatoryTitle,
  }) async {
    try {
      final invoice = await _repository.create(
        lines: lines,
        customerId: customerId,
        customerName: customerName,
        customerAttention: customerAttention,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        customerTin: customerTin,
        currency: currency,
        documentTitle: documentTitle,
        referenceNumber: referenceNumber,
        paymentTerms: paymentTerms,
        issueDate: issueDate,
        dueDate: dueDate,
        discountAmount: discountAmount,
        initialAmountPaid: initialAmountPaid,
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
        paymentInstructions: paymentInstructions,
        notes: notes,
        authorizedSignatoryName: authorizedSignatoryName,
        authorizedSignatoryTitle: authorizedSignatoryTitle,
      );
      await load();
      return invoice;
    } on AppException catch (error) {
      state = InvoicesFailure(error.message);
      return null;
    }
  }

  Future<CustomerInvoice?> recordPayment(
    String id, {
    required double amount,
    String? method,
    String? reference,
  }) async {
    try {
      final invoice = await _repository.recordPayment(
        id,
        amount: amount,
        method: method,
        reference: reference,
      );
      await load();
      return invoice;
    } on AppException catch (error) {
      state = InvoicesFailure(error.message);
      return null;
    }
  }

  Future<CustomerInvoice?> voidInvoice(String id) async {
    try {
      final invoice = await _repository.voidInvoice(id);
      await load();
      return invoice;
    } on AppException catch (error) {
      state = InvoicesFailure(error.message);
      return null;
    }
  }

  Future<void> _run(Future<InvoicePage> Function() fetch,
      {bool silent = false}) async {
    final active = _inFlight;
    if (active != null) {
      await active;
      return;
    }
    final request = () async {
      if (!silent || state is! InvoicesLoaded) {
        state = InvoicesLoading(search: _search, status: _status);
      }
      try {
        final result = await fetch();
        state = InvoicesLoaded(
          items: result.items,
          total: result.total,
          page: result.page,
          search: _search,
          status: _status,
        );
      } catch (_) {
        if (state is! InvoicesLoaded) {
          state = InvoicesLoaded(
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
    state = const InvoicesLoading();
  }
}

final invoicesControllerProvider =
    NotifierProvider<InvoicesController, InvoicesState>(InvoicesController.new);

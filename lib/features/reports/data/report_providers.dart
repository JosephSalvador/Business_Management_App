import 'dart:convert';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/reports_controller.dart';
import '../application/top_products_controller.dart';
import 'report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(apiClient: ref.watch(apiClientProvider)),
);

final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(
  ReportsController.new,
);

final topProductsControllerProvider =
    NotifierProvider<TopProductsController, TopProductsState>(
  TopProductsController.new,
);

/// Encode filter params as a stable, sorted JSON string.
/// String equality guarantees same content = same key.
String encodeFilterKey(Map<String, dynamic> params) {
  final sorted = SplayTreeMap<String, dynamic>.from(params);
  return jsonEncode(sorted);
}

Map<String, dynamic> decodeFilterKey(String key) =>
    Map<String, dynamic>.from(jsonDecode(key) as Map);

(DateTime?, DateTime?) _dates(String key) {
  final p = decodeFilterKey(key);
  return (
    DateTime.tryParse(p['from']?.toString() ?? ''),
    DateTime.tryParse(p['to']?.toString() ?? ''),
  );
}

final businessOverviewProvider =
    FutureProvider.family<BusinessOverview, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.businessOverview(from: from, to: to);
});

final moneyMovementProvider =
    FutureProvider.family<MoneyMovement, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.moneyMovement(from: from, to: to);
});

final purchasesSummaryProvider =
    FutureProvider.family<PurchasesSummary, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.purchasesSummary(from: from, to: to);
});

final salesByPaymentProvider =
    FutureProvider.family<List<SalesByPaymentMethod>, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.salesByPaymentMethod(from: from, to: to);
});

final salesSummaryProvider =
    FutureProvider.family<SalesSummary, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.salesSummary(from: from, to: to);
});

final salesByCategoryProvider =
    FutureProvider.family<List<SalesByCategory>, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.salesByCategory(from: from, to: to);
});

final salesTrendProvider =
    FutureProvider.family<List<SalesTrendPoint>, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final p = decodeFilterKey(key);
  return repo.salesTrend(days: p['days'] as int? ?? 30);
});

final stockSummaryProvider =
    FutureProvider.family<StockSummaryReport, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.stockSummary(from: from, to: to);
});

final stockMovementSummaryProvider =
    FutureProvider.family<StockMovementSummaryReport, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.stockMovementSummary(from: from, to: to);
});

final stockVelocityProvider =
    FutureProvider.family<StockVelocityReport, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.stockVelocity(from: from, to: to);
});

final expenseSummaryProvider =
    FutureProvider.family<ExpenseSummaryReport, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.getExpenseSummary(from: from, to: to);
});

final expenseTrendProvider =
    FutureProvider.family<ExpenseTrendReport, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.expenseTrend(from: from, to: to);
});

final expenseByPaymentProvider =
    FutureProvider.family<List<ExpenseByPaymentMethod>, String>(
        (ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.expenseByPaymentMethod(from: from, to: to);
});

final purchasesBySupplierProvider =
    FutureProvider.family<PurchasesBySupplierReport, String>((ref, key) async {
  final repo = ref.watch(reportRepositoryProvider);
  final (from, to) = _dates(key);
  return repo.purchasesBySupplier(from: from, to: to);
});

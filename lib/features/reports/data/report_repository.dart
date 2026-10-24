import '../../../core/network/api_client.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/local_sales_dao.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../finance/data/offline_expense_service.dart';

class SalesSummary {
  const SalesSummary({
    required this.totalSales,
    required this.totalRevenue,
    required this.averageSale,
  });

  /// Number of sales in the period (backend `totalSales`, an int).
  final int totalSales;

  /// Money earned in the period (backend `totalRevenue`).
  final num totalRevenue;

  /// Average revenue per sale (backend `averageSale`).
  final num averageSale;
}

class TopProduct {
  const TopProduct({
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
    this.totalCost = 0,
    this.totalProfit = 0,
    this.marginPercent = 0,
  });

  final String productName;
  final num totalQuantity;
  final num totalRevenue;
  final num totalCost;
  final num totalProfit;
  final num marginPercent;

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'totalQuantity': totalQuantity,
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'totalProfit': totalProfit,
        'marginPercent': marginPercent,
      };

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        productName: json['productName'] as String? ?? '',
        totalQuantity: json['totalQuantity'] as num? ?? 0,
        totalRevenue: json['totalRevenue'] as num? ?? 0,
        totalCost: json['totalCost'] as num? ?? 0,
        totalProfit: json['totalProfit'] as num? ?? 0,
        marginPercent: json['marginPercent'] as num? ?? 0,
      );
}

class SalesTrendPoint {
  const SalesTrendPoint({
    required this.label,
    required this.revenue,
  });

  /// Day label from the backend, e.g. `2026-09-08`.
  final String label;

  final num revenue;
}

class BusinessOverviewKpi {
  const BusinessOverviewKpi({
    required this.currentValue,
    required this.previousValue,
    required this.changePercent,
    required this.isUp,
  });
  final num currentValue;
  final num previousValue;
  final double changePercent;
  final bool isUp;
}

class BusinessOverview {
  const BusinessOverview({
    required this.sales,
    required this.grossProfit,
    required this.expenses,
    required this.moneyBalance,
    required this.salesTrend,
    required this.topProducts,
  });
  final BusinessOverviewKpi sales;
  final BusinessOverviewKpi grossProfit;
  final BusinessOverviewKpi expenses;
  final BusinessOverviewKpi moneyBalance;
  final List<SalesTrendPoint> salesTrend;
  final List<TopProduct> topProducts;
}

class MoneyMovementLine {
  const MoneyMovementLine({required this.label, required this.amount});
  final String label;
  final num amount;
}

class MoneyMovement {
  const MoneyMovement({
    required this.startingBalance,
    required this.moneyIn,
    required this.moneyOut,
    required this.currentBalance,
  });
  final num startingBalance;
  final List<MoneyMovementLine> moneyIn;
  final List<MoneyMovementLine> moneyOut;
  final num currentBalance;
}

class PurchasesSummary {
  const PurchasesSummary({
    required this.totalPurchased,
    required this.supplierCount,
    required this.itemsReceived,
    this.topSupplierName,
    required this.pendingCount,
    required this.receivedCount,
  });
  final num totalPurchased;
  final int supplierCount;
  final int itemsReceived;
  final String? topSupplierName;
  final int pendingCount;
  final int receivedCount;
}

class SalesByPaymentMethod {
  const SalesByPaymentMethod({
    required this.paymentMethod,
    required this.amount,
    required this.count,
  });
  final String paymentMethod;
  final num amount;
  final int count;
}

class SalesByCategory {
  const SalesByCategory({
    required this.categoryName,
    required this.amount,
    required this.quantity,
  });
  final String categoryName;
  final num amount;
  final num quantity;
}

class StockSummaryRow {
  const StockSummaryRow({
    required this.productName,
    this.sku,
    required this.opening,
    required this.purchased,
    required this.sold,
    required this.adjusted,
    required this.closing,
  });
  final String productName;
  final String? sku;
  final num opening;
  final num purchased;
  final num sold;
  final num adjusted;
  final num closing;
}

class StockSummaryReport {
  const StockSummaryReport({required this.rows});
  final List<StockSummaryRow> rows;
}

class StockMovementSummaryItem {
  const StockMovementSummaryItem({
    required this.movementType,
    required this.count,
    required this.totalQuantity,
  });
  final String movementType;
  final int count;
  final num totalQuantity;
}

class StockMovementSummaryReport {
  const StockMovementSummaryReport({required this.items});
  final List<StockMovementSummaryItem> items;
}

class StockVelocityItem {
  const StockVelocityItem({
    required this.productName,
    this.sku,
    required this.sold,
    required this.onHand,
    required this.velocityPerDay,
  });
  final String productName;
  final String? sku;
  final num sold;
  final num onHand;
  final num velocityPerDay;
}

class StockVelocityReport {
  const StockVelocityReport({required this.items});
  final List<StockVelocityItem> items;
}

class ExpenseTrendPoint {
  const ExpenseTrendPoint({required this.label, required this.amount});
  final String label;
  final num amount;
}

class ExpenseTrendReport {
  const ExpenseTrendReport({required this.dataPoints});
  final List<ExpenseTrendPoint> dataPoints;
}

class ExpenseByPaymentMethod {
  const ExpenseByPaymentMethod(
      {required this.paymentMethod, required this.amount});
  final String paymentMethod;
  final num amount;
}

class PurchasesBySupplierItem {
  const PurchasesBySupplierItem({
    required this.supplierName,
    required this.totalAmount,
    required this.orderCount,
  });
  final String supplierName;
  final num totalAmount;
  final int orderCount;
}

class PurchasesBySupplierReport {
  const PurchasesBySupplierReport({required this.items});
  final List<PurchasesBySupplierItem> items;
}

class ExpenseCategoryTotal {
  const ExpenseCategoryTotal({this.categoryName, required this.amount});
  final String? categoryName;
  final num amount;
}

class ExpenseSummaryReport {
  const ExpenseSummaryReport({required this.total, required this.byCategory});
  final num total;
  final List<ExpenseCategoryTotal> byCategory;
}

class _ProductStat {
  const _ProductStat({required this.name, this.qty = 0, this.revenue = 0});
  final String name;
  final double qty;
  final double revenue;

  _ProductStat add({required double qty, required double revenue}) =>
      _ProductStat(
        name: name,
        qty: this.qty + qty,
        revenue: this.revenue + revenue,
      );
}

class ReportRepository {
  const ReportRepository({
    required ApiClient apiClient,
    LocalSalesDao? salesDao,
    OfflineExpenseService? expenseService,
    OfflineCacheDao? cache,
    CachedCatalogDao? catalogDao,
  })  : _api = apiClient,
        _salesDao = salesDao,
        _expenseService = expenseService,
        _cache = cache,
        _catalogDao = catalogDao;

  final ApiClient _api;
  final LocalSalesDao? _salesDao;
  final OfflineExpenseService? _expenseService;
  final OfflineCacheDao? _cache;
  final CachedCatalogDao? _catalogDao;

  Future<SalesSummary> salesSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_sales_summary_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/sales-summary',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final data = response.data!;
      final summary = SalesSummary(
        totalSales: ((data['totalSales'] ?? 0) as num).toInt(),
        totalRevenue: (data['totalRevenue'] ?? 0) as num,
        averageSale: (data['averageSale'] ?? 0) as num,
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, {
          'totalSales': summary.totalSales,
          'totalRevenue': summary.totalRevenue,
          'averageSale': summary.averageSale,
        });
      }
      return summary;
    } on AppException {
      if (_salesDao != null) {
        final sales = await _salesDao!.listSales(
          from: effectiveFrom,
          to: effectiveTo,
          limit: 10000,
        );
        final totalSales = sales.length;
        final totalRevenue = sales.fold<double>(
          0.0,
          (sum, s) => sum + s.totalAmount,
        );
        final averageSale = totalSales > 0 ? totalRevenue / totalSales : 0.0;
        return SalesSummary(
          totalSales: totalSales,
          totalRevenue: totalRevenue,
          averageSale: averageSale,
        );
      }
      if (_cache != null) {
        final cached = await _cache!.load(cacheKey);
        if (cached != null) {
          return SalesSummary(
            totalSales: (cached['totalSales'] as num?)?.toInt() ?? 0,
            totalRevenue: (cached['totalRevenue'] as num?) ?? 0,
            averageSale: (cached['averageSale'] as num?) ?? 0,
          );
        }
      }
      rethrow;
    }
  }

  Future<List<TopProduct>> topProducts({
    DateTime? from,
    DateTime? to,
    int limit = 5,
  }) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_top_products_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}_$limit';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/top-products',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
          'limit': limit,
        },
      );
      final items = (response.data!['products'] as List<dynamic>?) ??
          (response.data!['items'] as List<dynamic>?) ??
          [];
      final result = items
          .map((e) => TopProduct(
                productName: (e['productName'] ?? '') as String,
                totalQuantity: (e['totalQuantity'] ?? 0) as num,
                totalRevenue: (e['totalRevenue'] ?? 0) as num,
                totalCost: (e['totalCost'] ?? 0) as num,
                totalProfit: (e['totalProfit'] ?? 0) as num,
                marginPercent: (e['marginPercent'] ?? 0) as num,
              ))
          .toList();
      if (_cache != null) {
        await _cache!.save(cacheKey, {
          'items': result.map((p) => p.toJson()).toList(),
        });
      }
      return result;
    } on AppException {
      if (_salesDao != null) {
        final sales = await _salesDao!.listSales(
          from: effectiveFrom,
          to: effectiveTo,
          limit: 10000,
        );
        final Map<String, _ProductStat> stats = {};
        for (final sale in sales) {
          for (final line in sale.lines) {
            final key = line.productName;
            final existing = stats[key] ?? _ProductStat(name: key);
            stats[key] = existing.add(
              qty: line.quantity,
              revenue: line.lineTotal,
            );
          }
        }
        final sorted = stats.values.toList()
          ..sort((a, b) => b.revenue.compareTo(a.revenue));
        return sorted
            .take(limit)
            .map((s) => TopProduct(
                  productName: s.name,
                  totalQuantity: s.qty,
                  totalRevenue: s.revenue,
                  totalCost: 0,
                  totalProfit: s.revenue,
                  marginPercent: 100,
                ))
            .toList();
      }
      if (_cache != null) {
        final cached = await _cache!.load(cacheKey);
        if (cached != null && cached['items'] is List) {
          return (cached['items'] as List)
              .map((e) =>
                  TopProduct.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<List<SalesTrendPoint>> salesTrend({int days = 7}) async {
    final cacheKey = 'rep_sales_trend_$days';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/sales-trend',
        query: {'days': days},
      );
      final dataPoints =
          (response.data!['dataPoints'] as List<dynamic>?) ?? [];
      final result = dataPoints
          .map((e) => SalesTrendPoint(
                label: (e['label'] ?? '') as String,
                revenue: (e['revenue'] ?? 0) as num,
              ))
          .toList();
      if (_cache != null) {
        await _cache!.save(cacheKey, {
          'dataPoints': result
              .map((p) => {'label': p.label, 'revenue': p.revenue})
              .toList(),
        });
      }
      return result;
    } on AppException {
      if (_salesDao != null) {
        final now = DateTime.now();
        final from = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: days - 1))
            .toUtc();
        final sales = await _salesDao!.listSales(from: from, limit: 10000);

        final Map<String, double> dayTotals = {};
        for (var i = 0; i < days; i++) {
          final d = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: days - 1 - i));
          final label =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          dayTotals[label] = 0.0;
        }

        for (final sale in sales) {
          final localDate = sale.saleDate.toLocal();
          final label =
              '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
          if (dayTotals.containsKey(label)) {
            dayTotals[label] = (dayTotals[label] ?? 0.0) + sale.totalAmount;
          }
        }

        return dayTotals.entries
            .map((e) => SalesTrendPoint(label: e.key, revenue: e.value))
            .toList();
      }
      if (_cache != null) {
        final cached = await _cache!.load(cacheKey);
        if (cached != null && cached['dataPoints'] is List) {
          return (cached['dataPoints'] as List)
              .map((e) => SalesTrendPoint(
                    label: e['label'] as String? ?? '',
                    revenue: (e['revenue'] as num?) ?? 0,
                  ))
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<BusinessOverview> businessOverview(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_business_overview_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/business-overview',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final data = response.data!;
      BusinessOverviewKpi parseKpi(Map<String, dynamic> json) =>
          BusinessOverviewKpi(
            currentValue: (json['currentValue'] ?? 0) as num,
            previousValue: (json['previousValue'] ?? 0) as num,
            changePercent: (json['changePercent'] ?? 0).toDouble(),
            isUp: json['isUp'] as bool? ?? true,
          );
      final overview = BusinessOverview(
        sales: parseKpi(data['sales'] as Map<String, dynamic>),
        grossProfit: parseKpi(data['grossProfit'] as Map<String, dynamic>),
        expenses: parseKpi(data['expenses'] as Map<String, dynamic>),
        moneyBalance: parseKpi(data['moneyBalance'] as Map<String, dynamic>),
        salesTrend: (data['salesTrend'] as List<dynamic>? ?? [])
            .map((e) => SalesTrendPoint(
                  label: (e['label'] ?? '') as String,
                  revenue: (e['revenue'] ?? 0) as num,
                ))
            .toList(),
        topProducts: (data['topProducts'] as List<dynamic>? ?? [])
            .map((e) => TopProduct(
                  productName: (e['productName'] ?? '') as String,
                  totalQuantity: (e['totalQuantity'] ?? 0) as num,
                  totalRevenue: (e['totalRevenue'] ?? 0) as num,
                  totalCost: (e['totalCost'] ?? 0) as num,
                  totalProfit: (e['totalProfit'] ?? 0) as num,
                  marginPercent: (e['marginPercent'] ?? 0) as num,
                ))
            .toList(),
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, data);
      }
      return overview;
    } on AppException {
      if (_salesDao != null) {
        final sales = await _salesDao!.listSales(
          from: effectiveFrom,
          to: effectiveTo,
          limit: 10000,
        );
        final totalSales =
            sales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);

        double totalExpenses = 0.0;
        if (_expenseService != null) {
          final expenses = await _expenseService!.getExpenses(limit: 1000);
          for (final exp in expenses) {
            final date = DateTime.tryParse(exp.expenseDate ?? '');
            if (date != null &&
                date.isAfter(effectiveFrom) &&
                date.isBefore(effectiveTo)) {
              totalExpenses += exp.amount;
            }
          }
        }

        final trend = await salesTrend(days: 7);
        final top =
            await topProducts(from: effectiveFrom, to: effectiveTo, limit: 5);

        return BusinessOverview(
          sales: BusinessOverviewKpi(
            currentValue: totalSales,
            previousValue: totalSales * 0.9,
            changePercent: 10.0,
            isUp: true,
          ),
          grossProfit: BusinessOverviewKpi(
            currentValue: totalSales - totalExpenses,
            previousValue: (totalSales - totalExpenses) * 0.9,
            changePercent: 10.0,
            isUp: true,
          ),
          expenses: BusinessOverviewKpi(
            currentValue: totalExpenses,
            previousValue: totalExpenses,
            changePercent: 0.0,
            isUp: false,
          ),
          moneyBalance: BusinessOverviewKpi(
            currentValue: totalSales - totalExpenses,
            previousValue: totalSales - totalExpenses,
            changePercent: 0.0,
            isUp: true,
          ),
          salesTrend: trend,
          topProducts: top,
        );
      }
      rethrow;
    }
  }

  Future<MoneyMovement> moneyMovement({DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_money_movement_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/money-movement',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final data = response.data!;
      MoneyMovementLine parseLine(Map<String, dynamic> json) =>
          MoneyMovementLine(
            label: (json['label'] ?? '') as String,
            amount: (json['amount'] ?? 0) as num,
          );
      final movement = MoneyMovement(
        startingBalance: (data['startingBalance'] ?? 0) as num,
        moneyIn: (data['moneyIn'] as List<dynamic>? ?? [])
            .map((e) => parseLine(e as Map<String, dynamic>))
            .toList(),
        moneyOut: (data['moneyOut'] as List<dynamic>? ?? [])
            .map((e) => parseLine(e as Map<String, dynamic>))
            .toList(),
        currentBalance: (data['currentBalance'] ?? 0) as num,
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, data);
      }
      return movement;
    } on AppException {
      if (_salesDao != null) {
        final sales = await _salesDao!.listSales(
          from: effectiveFrom,
          to: effectiveTo,
          limit: 10000,
        );
        final cashSales =
            sales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
        double expenses = 0.0;
        if (_expenseService != null) {
          final expList = await _expenseService!.getExpenses(limit: 1000);
          expenses = expList.fold<double>(0.0, (sum, e) => sum + e.amount);
        }
        return MoneyMovement(
          startingBalance: 0,
          moneyIn: [
            MoneyMovementLine(label: 'Sales Revenue', amount: cashSales),
          ],
          moneyOut: [
            MoneyMovementLine(label: 'Expenses', amount: expenses),
          ],
          currentBalance: cashSales - expenses,
        );
      }
      rethrow;
    }
  }

  Future<PurchasesSummary> purchasesSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_purchases_summary_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/purchases-summary',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final data = response.data!;
      final summary = PurchasesSummary(
        totalPurchased: (data['totalPurchased'] ?? 0) as num,
        supplierCount: (data['supplierCount'] ?? 0) as int,
        itemsReceived: (data['itemsReceived'] ?? 0) as int,
        topSupplierName: data['topSupplierName'] as String?,
        pendingCount: (data['pendingCount'] ?? 0) as int,
        receivedCount: (data['receivedCount'] ?? 0) as int,
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, data);
      }
      return summary;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('purchases_list_cache');
        final items = (cached?['items'] as List<dynamic>? ?? const []);
        final totalPurchased = items.fold<double>(
          0.0,
          (sum, i) => sum + ((i['totalAmount'] as num?)?.toDouble() ?? 0.0),
        );
        return PurchasesSummary(
          totalPurchased: totalPurchased,
          supplierCount: items.map((i) => i['supplierId']).toSet().length,
          itemsReceived: items.length,
          pendingCount: items.where((i) => i['status'] == 0).length,
          receivedCount: items.where((i) => i['status'] != 0).length,
        );
      }
      rethrow;
    }
  }

  Future<List<SalesByPaymentMethod>> salesByPaymentMethod(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_sales_by_payment_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/sales-by-payment',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final items = (response.data!['items'] as List<dynamic>?) ?? [];
      final result = items
          .map((e) => SalesByPaymentMethod(
                paymentMethod: (e['paymentMethod'] ?? '') as String,
                amount: (e['amount'] ?? 0) as num,
                count: (e['count'] ?? 0) as int,
              ))
          .toList();
      if (_cache != null) {
        await _cache!.save(cacheKey, {
          'items': result
              .map((p) => {
                    'paymentMethod': p.paymentMethod,
                    'amount': p.amount,
                    'count': p.count,
                  })
              .toList(),
        });
      }
      return result;
    } on AppException {
      if (_salesDao != null) {
        final sales = await _salesDao!.listSales(
          from: effectiveFrom,
          to: effectiveTo,
          limit: 10000,
        );
        final Map<String, (double, int)> totals = {
          'Cash': (0.0, 0),
          'Mobile Money': (0.0, 0),
          'Bank': (0.0, 0),
          'Credit': (0.0, 0),
        };

        for (final sale in sales) {
          if (sale.payments.isEmpty) {
            final (amt, cnt) = totals['Cash']!;
            totals['Cash'] = (amt + sale.totalAmount, cnt + 1);
          } else {
            for (final p in sale.payments) {
              final String method;
              if (p.method == 0) {
                method = 'Cash';
              } else if (p.method == 4) {
                method = 'Credit';
              } else if (p.method >= 1 && p.method <= 3) {
                method = 'Mobile Money';
              } else {
                method = 'Bank';
              }
              final (amt, cnt) = totals[method] ?? (0.0, 0);
              totals[method] = (amt + p.amount, cnt + 1);
            }
          }
        }

        return totals.entries
            .where((e) => e.value.$1 > 0 || e.value.$2 > 0)
            .map((e) => SalesByPaymentMethod(
                  paymentMethod: e.key,
                  amount: e.value.$1,
                  count: e.value.$2,
                ))
            .toList();
      }
      if (_cache != null) {
        final cached = await _cache!.load(cacheKey);
        if (cached != null && cached['items'] is List) {
          return (cached['items'] as List)
              .map((e) => SalesByPaymentMethod(
                    paymentMethod: e['paymentMethod'] as String? ?? '',
                    amount: (e['amount'] as num?) ?? 0,
                    count: (e['count'] as num?)?.toInt() ?? 0,
                  ))
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<List<SalesByCategory>> salesByCategory(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_sales_by_category_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/sales-by-category',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final items = (response.data!['items'] as List<dynamic>?) ?? [];
      final result = items
          .map((e) => SalesByCategory(
                categoryName: (e['categoryName'] ?? '') as String,
                amount: (e['amount'] ?? 0) as num,
                quantity: (e['quantity'] ?? 0) as num,
              ))
          .toList();
      if (_cache != null) {
        await _cache!.save(cacheKey, {
          'items': result
              .map((p) => {
                    'categoryName': p.categoryName,
                    'amount': p.amount,
                    'quantity': p.quantity,
                  })
              .toList(),
        });
      }
      return result;
    } on AppException {
      if (_salesDao != null) {
        final sales = await _salesDao!.listSales(
          from: effectiveFrom,
          to: effectiveTo,
          limit: 10000,
        );
        final Map<String, (double, double)> categories = {};
        for (final sale in sales) {
          for (final line in sale.lines) {
            const cat = 'General';
            final (amt, qty) = categories[cat] ?? (0.0, 0.0);
            categories[cat] = (amt + line.lineTotal, qty + line.quantity);
          }
        }
        return categories.entries
            .map((e) => SalesByCategory(
                  categoryName: e.key,
                  amount: e.value.$1,
                  quantity: e.value.$2,
                ))
            .toList();
      }
      if (_cache != null) {
        final cached = await _cache!.load(cacheKey);
        if (cached != null && cached['items'] is List) {
          return (cached['items'] as List)
              .map((e) => SalesByCategory(
                    categoryName: e['categoryName'] as String? ?? '',
                    amount: (e['amount'] as num?) ?? 0,
                    quantity: (e['quantity'] as num?) ?? 0,
                  ))
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<StockSummaryReport> stockSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_stock_summary_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/stock-summary',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final rows = (response.data!['rows'] as List<dynamic>?) ?? [];
      final result = StockSummaryReport(
        rows: rows
            .map((e) => StockSummaryRow(
                  productName: (e['productName'] ?? '') as String,
                  sku: e['sku'] as String?,
                  opening: (e['opening'] ?? 0) as num,
                  purchased: (e['purchased'] ?? 0) as num,
                  sold: (e['sold'] ?? 0) as num,
                  adjusted: (e['adjusted'] ?? 0) as num,
                  closing: (e['closing'] ?? 0) as num,
                ))
            .toList(),
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, {'rows': rows});
      }
      return result;
    } on AppException {
      if (_catalogDao != null) {
        final products = await _catalogDao!.all();
        return StockSummaryReport(
          rows: products
              .map((p) => StockSummaryRow(
                    productName: p.name,
                    sku: p.sku,
                    opening: p.currentStock,
                    purchased: 0,
                    sold: 0,
                    adjusted: 0,
                    closing: p.currentStock,
                  ))
              .toList(),
        );
      }
      rethrow;
    }
  }

  Future<StockMovementSummaryReport> stockMovementSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_stock_movement_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/stock-movements',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final items = (response.data!['items'] as List<dynamic>?) ?? [];
      final result = StockMovementSummaryReport(
        items: items
            .map((e) => StockMovementSummaryItem(
                  movementType: (e['movementType'] ?? '') as String,
                  count: (e['count'] ?? 0) as int,
                  totalQuantity: (e['totalQuantity'] ?? 0) as num,
                ))
            .toList(),
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, {'items': items});
      }
      return result;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load(cacheKey);
        if (cached != null && cached['items'] is List) {
          return StockMovementSummaryReport(
            items: (cached['items'] as List)
                .map((e) => StockMovementSummaryItem(
                      movementType: (e['movementType'] ?? '') as String,
                      count: (e['count'] ?? 0) as int,
                      totalQuantity: (e['totalQuantity'] ?? 0) as num,
                    ))
                .toList(),
          );
        }
      }
      return const StockMovementSummaryReport(items: []);
    }
  }

  Future<StockVelocityReport> stockVelocity(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_stock_velocity_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/stock-velocity',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final items = (response.data!['items'] as List<dynamic>?) ?? [];
      final result = StockVelocityReport(
        items: items
            .map((e) => StockVelocityItem(
                  productName: (e['productName'] ?? '') as String,
                  sku: e['sku'] as String?,
                  sold: (e['sold'] ?? 0) as num,
                  onHand: (e['onHand'] ?? 0) as num,
                  velocityPerDay: (e['velocityPerDay'] ?? 0) as num,
                ))
            .toList(),
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, {'items': items});
      }
      return result;
    } on AppException {
      if (_catalogDao != null) {
        final products = await _catalogDao!.all();
        return StockVelocityReport(
          items: products
              .map((p) => StockVelocityItem(
                    productName: p.name,
                    sku: p.sku,
                    sold: 0,
                    onHand: p.currentStock,
                    velocityPerDay: 0,
                  ))
              .toList(),
        );
      }
      rethrow;
    }
  }

  Future<ExpenseTrendReport> expenseTrend(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_expense_trend_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/expense-trend',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final dataPoints =
          (response.data!['dataPoints'] as List<dynamic>?) ?? [];
      final result = ExpenseTrendReport(
        dataPoints: dataPoints
            .map((e) => ExpenseTrendPoint(
                  label: (e['label'] ?? '') as String,
                  amount: (e['amount'] ?? 0) as num,
                ))
            .toList(),
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, {'dataPoints': dataPoints});
      }
      return result;
    } on AppException {
      if (_expenseService != null) {
        final expenses = await _expenseService!.getExpenses(limit: 1000);
        final Map<String, double> days = {};
        for (final exp in expenses) {
          final d = DateTime.tryParse(exp.expenseDate ?? '')?.toLocal();
          if (d != null &&
              d.isAfter(effectiveFrom) &&
              d.isBefore(effectiveTo)) {
            final label =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            days[label] = (days[label] ?? 0.0) + exp.amount;
          }
        }
        return ExpenseTrendReport(
          dataPoints: days.entries
              .map((e) => ExpenseTrendPoint(label: e.key, amount: e.value))
              .toList(),
        );
      }
      rethrow;
    }
  }

  Future<List<ExpenseByPaymentMethod>> expenseByPaymentMethod(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_expense_by_payment_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/expense-by-payment',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final items = (response.data!['items'] as List<dynamic>?) ?? [];
      final result = items
          .map((e) => ExpenseByPaymentMethod(
                paymentMethod: (e['paymentMethod'] ?? '') as String,
                amount: (e['amount'] ?? 0) as num,
              ))
          .toList();
      if (_cache != null) {
        await _cache!.save(cacheKey, {'items': items});
      }
      return result;
    } on AppException {
      if (_expenseService != null) {
        final expenses = await _expenseService!.getExpenses(limit: 1000);
        final Map<String, double> methods = {};
        for (final exp in expenses) {
          final d = DateTime.tryParse(exp.expenseDate ?? '');
          if (d != null &&
              d.isAfter(effectiveFrom) &&
              d.isBefore(effectiveTo)) {
            final m = exp.paidViaCash ? 'Cash' : 'Bank/Electronic';
            methods[m] = (methods[m] ?? 0.0) + exp.amount;
          }
        }
        return methods.entries
            .map((e) => ExpenseByPaymentMethod(
                  paymentMethod: e.key,
                  amount: e.value,
                ))
            .toList();
      }
      rethrow;
    }
  }

  Future<PurchasesBySupplierReport> purchasesBySupplier(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_purchases_by_supplier_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/reports/purchases-by-supplier',
        query: {
          'from': effectiveFrom.toUtc().toIso8601String(),
          'to': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final items = (response.data!['items'] as List<dynamic>?) ?? [];
      final result = PurchasesBySupplierReport(
        items: items
            .map((e) => PurchasesBySupplierItem(
                  supplierName: (e['supplierName'] ?? '') as String,
                  totalAmount: (e['totalAmount'] ?? 0) as num,
                  orderCount: (e['orderCount'] ?? 0) as int,
                ))
            .toList(),
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, {
          'items': items,
        });
      }
      return result;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('purchases_list_cache');
        final items = (cached?['items'] as List<dynamic>? ?? const []);
        final Map<String, (double, int)> suppliers = {};
        for (final item in items) {
          final name = (item['supplierName'] ?? 'Supplier') as String;
          final amt = ((item['totalAmount'] as num?)?.toDouble() ?? 0.0);
          final existing = suppliers[name] ?? (0.0, 0);
          suppliers[name] = (existing.$1 + amt, existing.$2 + 1);
        }
        return PurchasesBySupplierReport(
          items: suppliers.entries
              .map((e) => PurchasesBySupplierItem(
                    supplierName: e.key,
                    totalAmount: e.value.$1,
                    orderCount: e.value.$2,
                  ))
              .toList(),
        );
      }
      rethrow;
    }
  }

  Future<ExpenseSummaryReport> getExpenseSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final cacheKey =
        'rep_expense_summary_${effectiveFrom.millisecondsSinceEpoch}_${effectiveTo.millisecondsSinceEpoch}';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/expenses/summary',
        query: {
          'fromDate': effectiveFrom.toUtc().toIso8601String(),
          'toDate': effectiveTo.toUtc().toIso8601String(),
        },
      );
      final data = response.data!;
      final result = ExpenseSummaryReport(
        total: (data['total'] ?? 0) as num,
        byCategory: (data['byCategory'] as List<dynamic>? ?? [])
            .map((e) => ExpenseCategoryTotal(
                  categoryName: e['categoryName'] as String?,
                  amount: (e['amount'] ?? 0) as num,
                ))
            .toList(),
      );
      if (_cache != null) {
        await _cache!.save(cacheKey, data);
      }
      return result;
    } on AppException {
      if (_expenseService != null) {
        final expenses = await _expenseService!.getExpenses(limit: 1000);
        double total = 0.0;
        final Map<String, double> byCat = {};
        for (final exp in expenses) {
          final d = DateTime.tryParse(exp.expenseDate ?? '');
          if (d != null &&
              d.isAfter(effectiveFrom) &&
              d.isBefore(effectiveTo)) {
            total += exp.amount;
            final cat = exp.categoryName ?? 'Other';
            byCat[cat] = (byCat[cat] ?? 0.0) + exp.amount;
          }
        }
        return ExpenseSummaryReport(
          total: total,
          byCategory: byCat.entries
              .map((e) => ExpenseCategoryTotal(
                    categoryName: e.key,
                    amount: e.value,
                  ))
              .toList(),
        );
      }
      rethrow;
    }
  }
}


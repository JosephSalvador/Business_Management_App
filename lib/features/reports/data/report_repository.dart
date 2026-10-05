import '../../../core/network/api_client.dart';

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
  });

  final String productName;
  final num totalQuantity;
  final num totalRevenue;
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

class ReportRepository {
  const ReportRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<SalesSummary> salesSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/sales-summary',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final data = response.data!;
    return SalesSummary(
      totalSales: ((data['totalSales'] ?? 0) as num).toInt(),
      totalRevenue: (data['totalRevenue'] ?? 0) as num,
      averageSale: (data['averageSale'] ?? 0) as num,
    );
  }

  Future<List<TopProduct>> topProducts({
    DateTime? from,
    DateTime? to,
    int limit = 5,
  }) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/top-products',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
        'limit': limit,
      },
    );
    final items = (response.data!['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => TopProduct(
              productName: (e['productName'] ?? '') as String,
              totalQuantity: (e['totalQuantity'] ?? 0) as num,
              totalRevenue: (e['totalRevenue'] ?? 0) as num,
            ))
        .toList();
  }

  Future<List<SalesTrendPoint>> salesTrend({int days = 7}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/sales-trend',
      query: {'days': days},
    );
    final dataPoints = (response.data!['dataPoints'] as List<dynamic>?) ?? [];
    return dataPoints
        .map((e) => SalesTrendPoint(
              label: (e['label'] ?? '') as String,
              revenue: (e['revenue'] ?? 0) as num,
            ))
        .toList();
  }

  Future<BusinessOverview> businessOverview(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
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
    return BusinessOverview(
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
              ))
          .toList(),
    );
  }

  Future<MoneyMovement> moneyMovement({DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/money-movement',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final data = response.data!;
    MoneyMovementLine parseLine(Map<String, dynamic> json) => MoneyMovementLine(
          label: (json['label'] ?? '') as String,
          amount: (json['amount'] ?? 0) as num,
        );
    return MoneyMovement(
      startingBalance: (data['startingBalance'] ?? 0) as num,
      moneyIn: (data['moneyIn'] as List<dynamic>? ?? [])
          .map((e) => parseLine(e as Map<String, dynamic>))
          .toList(),
      moneyOut: (data['moneyOut'] as List<dynamic>? ?? [])
          .map((e) => parseLine(e as Map<String, dynamic>))
          .toList(),
      currentBalance: (data['currentBalance'] ?? 0) as num,
    );
  }

  Future<PurchasesSummary> purchasesSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/purchases-summary',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final data = response.data!;
    return PurchasesSummary(
      totalPurchased: (data['totalPurchased'] ?? 0) as num,
      supplierCount: (data['supplierCount'] ?? 0) as int,
      itemsReceived: (data['itemsReceived'] ?? 0) as int,
      topSupplierName: data['topSupplierName'] as String?,
      pendingCount: (data['pendingCount'] ?? 0) as int,
      receivedCount: (data['receivedCount'] ?? 0) as int,
    );
  }

  Future<List<SalesByPaymentMethod>> salesByPaymentMethod(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/sales-by-payment',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final items = (response.data!['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => SalesByPaymentMethod(
              paymentMethod: (e['paymentMethod'] ?? '') as String,
              amount: (e['amount'] ?? 0) as num,
              count: (e['count'] ?? 0) as int,
            ))
        .toList();
  }

  Future<List<SalesByCategory>> salesByCategory(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/sales-by-category',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final items = (response.data!['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => SalesByCategory(
              categoryName: (e['categoryName'] ?? '') as String,
              amount: (e['amount'] ?? 0) as num,
              quantity: (e['quantity'] ?? 0) as num,
            ))
        .toList();
  }

  Future<StockSummaryReport> stockSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/stock-summary',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final rows = (response.data!['rows'] as List<dynamic>?) ?? [];
    return StockSummaryReport(
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
  }

  Future<StockMovementSummaryReport> stockMovementSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/stock-movements',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final items = (response.data!['items'] as List<dynamic>?) ?? [];
    return StockMovementSummaryReport(
      items: items
          .map((e) => StockMovementSummaryItem(
                movementType: (e['movementType'] ?? '') as String,
                count: (e['count'] ?? 0) as int,
                totalQuantity: (e['totalQuantity'] ?? 0) as num,
              ))
          .toList(),
    );
  }

  Future<StockVelocityReport> stockVelocity(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/stock-velocity',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final items = (response.data!['items'] as List<dynamic>?) ?? [];
    return StockVelocityReport(
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
  }

  Future<ExpenseTrendReport> expenseTrend(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/expense-trend',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final dataPoints = (response.data!['dataPoints'] as List<dynamic>?) ?? [];
    return ExpenseTrendReport(
      dataPoints: dataPoints
          .map((e) => ExpenseTrendPoint(
                label: (e['label'] ?? '') as String,
                amount: (e['amount'] ?? 0) as num,
              ))
          .toList(),
    );
  }

  Future<List<ExpenseByPaymentMethod>> expenseByPaymentMethod(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/expense-by-payment',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final items = (response.data!['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => ExpenseByPaymentMethod(
              paymentMethod: (e['paymentMethod'] ?? '') as String,
              amount: (e['amount'] ?? 0) as num,
            ))
        .toList();
  }

  Future<PurchasesBySupplierReport> purchasesBySupplier(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/reports/purchases-by-supplier',
      query: {
        'from': effectiveFrom.toUtc().toIso8601String(),
        'to': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final items = (response.data!['items'] as List<dynamic>?) ?? [];
    return PurchasesBySupplierReport(
      items: items
          .map((e) => PurchasesBySupplierItem(
                supplierName: (e['supplierName'] ?? '') as String,
                totalAmount: (e['totalAmount'] ?? 0) as num,
                orderCount: (e['orderCount'] ?? 0) as int,
              ))
          .toList(),
    );
  }

  Future<ExpenseSummaryReport> getExpenseSummary(
      {DateTime? from, DateTime? to}) async {
    final effectiveTo = to ?? DateTime.now().toUtc();
    final effectiveFrom =
        from ?? effectiveTo.subtract(const Duration(days: 30));
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/expenses/summary',
      query: {
        'fromDate': effectiveFrom.toUtc().toIso8601String(),
        'toDate': effectiveTo.toUtc().toIso8601String(),
      },
    );
    final data = response.data!;
    return ExpenseSummaryReport(
      total: (data['total'] ?? 0) as num,
      byCategory: (data['byCategory'] as List<dynamic>? ?? [])
          .map((e) => ExpenseCategoryTotal(
                categoryName: e['categoryName'] as String?,
                amount: (e['amount'] ?? 0) as num,
              ))
          .toList(),
    );
  }
}

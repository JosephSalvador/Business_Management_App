import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_sales_dao.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../customers/data/offline_customer_debt_service.dart';
import '../../finance/data/offline_expense_service.dart';
import '../domain/sale.dart';

/// Holds the reconciled totals for a day/shift.
class ShiftSummary {
  const ShiftSummary({
    required this.date,
    required this.saleCount,
    required this.cashSales,
    required this.electronicSales,
    required this.creditSales,
    required this.totalSales,
    required this.debtCashCollected,
    required this.cashExpenses,
    required this.openingCash,
    required this.expectedCash,
    this.countedCash,
    this.variance,
    this.closedAt,
  });

  final DateTime date;
  final int saleCount;
  final double cashSales;
  final double electronicSales;
  final double creditSales;
  final double totalSales;
  final double debtCashCollected;
  final double cashExpenses;
  final double openingCash;
  final double expectedCash;
  final double? countedCash;
  final double? variance;
  final DateTime? closedAt;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'saleCount': saleCount,
        'cashSales': cashSales,
        'electronicSales': electronicSales,
        'creditSales': creditSales,
        'totalSales': totalSales,
        'debtCashCollected': debtCashCollected,
        'cashExpenses': cashExpenses,
        'openingCash': openingCash,
        'expectedCash': expectedCash,
        'countedCash': countedCash,
        'variance': variance,
        'closedAt': closedAt?.toIso8601String(),
      };

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
        date: DateTime.parse(json['date'] as String),
        saleCount: json['saleCount'] as int? ?? 0,
        cashSales: (json['cashSales'] as num?)?.toDouble() ?? 0.0,
        electronicSales: (json['electronicSales'] as num?)?.toDouble() ?? 0.0,
        creditSales: (json['creditSales'] as num?)?.toDouble() ?? 0.0,
        totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
        debtCashCollected:
            (json['debtCashCollected'] as num?)?.toDouble() ?? 0.0,
        cashExpenses: (json['cashExpenses'] as num?)?.toDouble() ?? 0.0,
        openingCash: (json['openingCash'] as num?)?.toDouble() ?? 0.0,
        expectedCash: (json['expectedCash'] as num?)?.toDouble() ?? 0.0,
        countedCash: (json['countedCash'] as num?)?.toDouble(),
        variance: (json['variance'] as num?)?.toDouble(),
        closedAt: json['closedAt'] != null
            ? DateTime.tryParse(json['closedAt'] as String)
            : null,
      );
}

/// Computes offline shift close, drawer cash balancing, and thermal Z-Reports.
class OfflineShiftRegisterService {
  OfflineShiftRegisterService({
    required LocalSalesDao salesDao,
    required OfflineExpenseService expenseService,
    required OfflineCustomerDebtService debtService,
    required SyncQueueDao queue,
    required OfflineCacheDao cache,
    required Future<String?> Function() tenantIdOf,
    required Future<String?> Function() branchIdOf,
    required Future<String> Function() deviceIdOf,
    required Future<String?> Function() userIdOf,
    Uuid uuid = const Uuid(),
  })  : _salesDao = salesDao,
        _expenseService = expenseService,
        _debtService = debtService,
        _queue = queue,
        _cache = cache,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _userIdOf = userIdOf,
        _uuid = uuid;

  final LocalSalesDao _salesDao;
  final OfflineExpenseService _expenseService;
  final OfflineCustomerDebtService _debtService;
  final SyncQueueDao _queue;
  final OfflineCacheDao _cache;
  final Future<String?> Function() _tenantIdOf;
  final Future<String?> Function() _branchIdOf;
  final Future<String> Function() _deviceIdOf;
  final Future<String?> Function() _userIdOf;
  final Uuid _uuid;

  /// Calculates shift numbers directly from local SQLite.
  Future<ShiftSummary> computeShiftSummary({
    DateTime? date,
    double openingCash = 0,
    double? countedCash,
  }) async {
    final target = date ?? DateTime.now();
    final from = DateTime(target.year, target.month, target.day).toUtc();
    final to =
        DateTime(target.year, target.month, target.day, 23, 59, 59, 999).toUtc();

    final sales = await _salesDao.listSales(from: from, to: to, limit: 1000);

    double cashSales = 0;
    double electronicSales = 0;
    double creditSales = 0;
    double totalSales = 0;

    for (final sale in sales) {
      totalSales += sale.totalAmount;
      if (sale.payments.isEmpty) {
        cashSales += sale.totalAmount;
      } else {
        for (final payment in sale.payments) {
          if (payment.method == PaymentMethod.cash) {
            cashSales += payment.amount;
          } else if (payment.method == PaymentMethod.credit) {
            creditSales += payment.amount;
          } else if (PaymentMethod.isElectronic(payment.method)) {
            electronicSales += payment.amount;
          } else {
            cashSales += payment.amount;
          }
        }
      }
    }

    final debtCash =
        await _debtService.getTodayCashDebtPaymentsTotal(today: target);
    final cashExpenses =
        await _expenseService.getTodayCashExpensesTotal(today: target);

    final expectedCash = openingCash + cashSales + debtCash - cashExpenses;
    final variance = countedCash != null ? countedCash - expectedCash : null;

    return ShiftSummary(
      date: target,
      saleCount: sales.length,
      cashSales: cashSales,
      electronicSales: electronicSales,
      creditSales: creditSales,
      totalSales: totalSales,
      debtCashCollected: debtCash,
      cashExpenses: cashExpenses,
      openingCash: openingCash,
      expectedCash: expectedCash,
      countedCash: countedCash,
      variance: variance,
    );
  }

  /// Generates a standardized 32-character thermal Z-Report string.
  String generateZReportText(
    ShiftSummary summary, {
    String businessName = 'JOLINX POS',
    String branchName = 'Duka Kuu',
    String cashierName = 'Mhudumu',
  }) {
    final buffer = StringBuffer();
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    buffer.writeln('================================');
    buffer.writeln('         $businessName');
    buffer.writeln('       RIPOTI YA Z-HESABU');
    buffer.writeln('================================');
    buffer.writeln('Tawi: $branchName');
    buffer.writeln('Keshia: $cashierName');
    buffer.writeln('Tarehe: $dateFmt');
    buffer.writeln('Idadi ya Mauzo: ${summary.saleCount}');
    buffer.writeln('--------------------------------');
    buffer.writeln('MAUZO YA LEO:');
    buffer.writeln(_line('Pesa Taslimu (Cash)', summary.cashSales));
    buffer.writeln(_line('Simu / Benki', summary.electronicSales));
    buffer.writeln(_line('Mikopo', summary.creditSales));
    buffer.writeln('--------------------------------');
    buffer.writeln(_line('JUMLA YA MAUZO', summary.totalSales));
    buffer.writeln('--------------------------------');
    buffer.writeln('MWENENDO WA DROO YA PESA:');
    buffer.writeln(_line('Mtaji wa Kuanzia', summary.openingCash));
    buffer.writeln(_line('+ Mauzo ya Taslimu', summary.cashSales));
    buffer.writeln(_line('+ Malipo ya Madeni', summary.debtCashCollected));
    buffer.writeln(_line('- Matumizi ya Dukani', summary.cashExpenses));
    buffer.writeln('--------------------------------');
    buffer.writeln(_line('PESA INAYOTARAJIWA', summary.expectedCash));
    if (summary.countedCash != null) {
      buffer.writeln(_line('PESA ZILIZOHESABIWA', summary.countedCash!));
      final v = summary.variance ?? 0;
      final vLabel = v >= 0 ? 'ZIADA (+)' : 'UPUNGUFU (-)';
      buffer.writeln(_line(vLabel, v.abs()));
    }
    buffer.writeln('================================');
    buffer.writeln('  Imetolewa Nje ya Mtandao');
    buffer.writeln('       (Offline Z-Report)');
    buffer.writeln('================================\n\n\n');

    return buffer.toString();
  }

  /// Closes the shift and queues the shift reconciliation for audit sync.
  Future<void> saveShiftClose(ShiftSummary summary) async {
    final shiftId = _uuid.v4();
    final tenantId = (await _tenantIdOf()) ?? 'unknown';
    final branchId = (await _branchIdOf()) ?? tenantId;
    final deviceId = await _deviceIdOf();
    final now = DateTime.now().toUtc();

    final payload = {
      'shiftId': shiftId,
      'tenantId': tenantId,
      'branchId': branchId,
      'summary': summary.toJson(),
      'closedAt': now.toIso8601String(),
    };

    // Cache locally
    await _cache.save('last_closed_shift', payload);

    // Enqueue for cloud audit
    await _queue.enqueue(
      operationId: shiftId,
      tenantId: tenantId,
      branchId: branchId,
      deviceId: deviceId,
      operationType: 'shift.close',
      aggregateType: 'shift',
      aggregateId: shiftId,
      payload: jsonEncode(payload),
    );
  }

  String _line(String label, double amount) {
    final amtStr = 'TZS ${amount.toStringAsFixed(0)}';
    final totalWidth = 32;
    final available = totalWidth - amtStr.length;
    final trimmedLabel =
        label.length > available ? label.substring(0, available - 1) : label;
    final spaces = totalWidth - trimmedLabel.length - amtStr.length;
    return '$trimmedLabel${' ' * (spaces > 0 ? spaces : 1)}$amtStr';
  }
}

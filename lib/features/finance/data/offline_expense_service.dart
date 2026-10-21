import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import 'expense_repository.dart';

/// Provides offline storage, local queuing, and till cash deduction
/// for petty cash expenses ("Matumizi ya Dukani").
class OfflineExpenseService {
  OfflineExpenseService({
    required SyncQueueDao queue,
    required OfflineCacheDao cache,
    required Future<String?> Function() tenantIdOf,
    required Future<String?> Function() branchIdOf,
    required Future<String> Function() deviceIdOf,
    required Future<String?> Function() userIdOf,
    Uuid uuid = const Uuid(),
  })  : _queue = queue,
        _cache = cache,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _userIdOf = userIdOf,
        _uuid = uuid;

  final SyncQueueDao _queue;
  final OfflineCacheDao _cache;
  final Future<String?> Function() _tenantIdOf;
  final Future<String?> Function() _branchIdOf;
  final Future<String> Function() _deviceIdOf;
  final Future<String?> Function() _userIdOf;
  final Uuid _uuid;

  static const _categoriesCacheKey = 'expense_categories';

  static const List<ExpenseCategory> defaultFallbackCategories = [
    ExpenseCategory(id: 'cat-matumizi-duka', name: 'Matumizi ya Dukani'),
    ExpenseCategory(id: 'cat-nauli-usafiri', name: 'Usafiri / Nauli'),
    ExpenseCategory(id: 'cat-chakula', name: 'Chakula cha Wafanyakazi'),
    ExpenseCategory(id: 'cat-umeme-maji', name: 'Luku / Umeme / Maji'),
    ExpenseCategory(id: 'cat-kodi', name: 'Kodi ya Pango'),
    ExpenseCategory(id: 'cat-vocha-internet', name: 'Mawasiliano / Vocha'),
    ExpenseCategory(id: 'cat-matengenezo', name: 'Ukarabati / Matengenezo'),
  ];

  /// Records an expense locally and stages it in the persistent queue.
  Future<Map<String, dynamic>> recordOffline(Map<String, dynamic> body) async {
    final expenseId = body['id'] as String? ?? _uuid.v4();
    final tenantId = (await _tenantIdOf()) ?? 'unknown';
    final branchId = (await _branchIdOf()) ?? tenantId;
    final deviceId = await _deviceIdOf();
    final userId = (await _userIdOf()) ?? 'offline_user';

    final enrichedBody = Map<String, dynamic>.from(body);
    enrichedBody['id'] = expenseId;
    enrichedBody['userId'] ??= userId;
    enrichedBody['pendingLocally'] = true;
    enrichedBody['createdAt'] =
        enrichedBody['createdAt'] ?? DateTime.now().toUtc().toIso8601String();

    await _queue.enqueue(
      operationId: expenseId,
      tenantId: tenantId,
      branchId: branchId,
      deviceId: deviceId,
      operationType: 'expense.create',
      aggregateType: 'expense',
      aggregateId: expenseId,
      payload: jsonEncode(enrichedBody),
    );

    return enrichedBody;
  }

  /// Lists all pending expenses waiting in the sync queue.
  Future<List<Map<String, dynamic>>> listPendingExpenses() async {
    final ops = await _queue.listByOperationType('expense.create');
    final result = <Map<String, dynamic>>[];
    for (final op in ops) {
      try {
        final decoded = jsonDecode(op.payload);
        if (decoded is Map<String, dynamic>) {
          result.add({
            ...decoded,
            'id': op.aggregateId,
            'pendingLocally': true,
          });
        }
      } catch (_) {}
    }
    return result;
  }

  /// Calculates total cash expenses recorded offline today for till balancing.
  Future<double> getTodayCashExpensesTotal({DateTime? today}) async {
    final now = today ?? DateTime.now();
    final pending = await listPendingExpenses();
    double total = 0;

    for (final exp in pending) {
      final method = (exp['paymentMethod'] ?? '').toString().toLowerCase();
      final isCash = method.contains('taslimu') || method.contains('cash');
      if (!isCash) continue;

      final dateStr = exp['expenseDate'] ?? exp['createdAt'];
      if (dateStr != null) {
        final dt = DateTime.tryParse(dateStr.toString())?.toLocal();
        if (dt != null &&
            dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day) {
          total += (exp['amount'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    return total;
  }

  /// Caches or retrieves expense categories so forms work offline.
  Future<List<ExpenseCategory>> getCategoriesWithCache(
    Future<List<ExpenseCategory>> Function() fetchOnline,
  ) async {
    try {
      final remote = await fetchOnline();
      if (remote.isNotEmpty) {
        await _cache.save(_categoriesCacheKey, {
          'items': remote.map((c) => {'id': c.id, 'name': c.name}).toList(),
        });
        return remote;
      }
    } catch (_) {
      // Offline fallback
    }

    final cached = await _cache.load(_categoriesCacheKey);
    if (cached != null && cached['items'] is List) {
      final list = (cached['items'] as List)
          .whereType<Map>()
          .map((m) => ExpenseCategory(
                id: m['id']?.toString() ?? '',
                name: m['name']?.toString() ?? '',
              ))
          .toList();
      if (list.isNotEmpty) return list;
    }

    return defaultFallbackCategories;
  }
}

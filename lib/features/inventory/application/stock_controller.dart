import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/cached_catalog_dao.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/catalog.dart' show Warehouse;
import '../data/inventory_repository.dart';

/// The Stock hub state. Rows are cache-first (instant, offline OK) and then
/// silently replaced by the enriched server projection when the network lets
/// us — identical to the POS grid's cache-then-refresh contract.
sealed class StockState {
  const StockState();
}

class StockLoading extends StockState {
  const StockLoading();
}

class StockReady extends StockState {
  const StockReady({
    required this.rows,
    required this.warehouses,
    required this.search,
    required this.lowOnly,
    required this.sort,
    required this.lowThreshold,
    required this.selectedWarehouseId,
    required this.stale,
  });

  /// One row per product across the visible warehouses.
  final List<StockRow> rows;

  /// The tenant's warehouses. `length == 1` collapses the warehouse chips and
  /// the Store column (single-shop kiosks never see hub complexity).
  final List<Warehouse> warehouses;

  final String search;
  final bool lowOnly;
  final StockSort sort;
  final double lowThreshold;
  final String? selectedWarehouseId;
  final bool stale;

  bool get multiWarehouse => warehouses.length > 1;

  /// Status chip counts for `length central. statusCounts`:
  /// [ok, low, out].
  StockCounts get counts {
    var ok = 0, low = 0, out = 0;
    for (final row in rows) {
      switch (row.status(lowThreshold)) {
        case StockHealth.ok:
          ok++;
          break;
        case StockHealth.low:
          low++;
          break;
        case StockHealth.out:
          out++;
      }
    }
    return StockCounts(ok: ok, low: low, out: out);
  }

  double get onHandUnits => rows.fold(0.0, (sum, row) => sum + row.quantity);

  List<StockRow> get visible {
    final query = search.trim().toLowerCase();
    var result = rows.where((row) {
      if (query.isNotEmpty) {
        final name = row.name.toLowerCase();
        final sku = row.sku ?? '';
        final barcode = row.barcode ?? '';
        if (!name.contains(query) &&
            !sku.toLowerCase().contains(query) &&
            !barcode.toLowerCase().contains(query)) {
          return false;
        }
      }
      if (lowOnly && row.status(lowThreshold) == StockHealth.ok) {
        return false;
      }
      if (selectedWarehouseId != null &&
          row.warehouseId != selectedWarehouseId) {
        return false;
      }
      return true;
    });
    final list = result.toList();
    switch (sort) {
      case StockSort.lowest:
        list.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case StockSort.highest:
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case StockSort.alphabetical:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  StockReady copyWith({
    List<StockRow>? rows,
    List<Warehouse>? warehouses,
    String? search,
    bool? lowOnly,
    StockSort? sort,
    double? lowThreshold,
    String? Function()? selectedWarehouseId,
    bool? stale,
  }) =>
      StockReady(
        rows: rows ?? this.rows,
        warehouses: warehouses ?? this.warehouses,
        search: search ?? this.search,
        lowOnly: lowOnly ?? this.lowOnly,
        sort: sort ?? this.sort,
        lowThreshold: lowThreshold ?? this.lowThreshold,
        selectedWarehouseId: selectedWarehouseId == null
            ? this.selectedWarehouseId
            : selectedWarehouseId(),
        stale: stale ?? this.stale,
      );
}

class StockEmpty extends StockState {
  const StockEmpty();
}

class StockFailure extends StockState {
  const StockFailure(this.message);

  final String message;
}

enum StockHealth { ok, low, out }

class StockCounts {
  const StockCounts({required this.ok, required this.low, required this.out});
  final int ok;
  final int low;
  final int out;
  int get total => ok + low + out;
}

enum StockSort { lowest, highest, alphabetical }

/// One hub row: product + its balance in the currently selected warehouse
/// (or the union of all warehouses when none is selected).
class StockRow {
  const StockRow({
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.unitOfMeasureName,
    required this.quantity,
    this.productNames,
  });

  final String warehouseId;
  final String warehouseName;
  final String productId;
  final String name;
  final String? sku;
  final String? barcode;
  final String unitOfMeasureName;
  final double quantity;

  /// Per-warehouse on-hand (multi-warehouse only) keyed by warehouseId.
  final Map<String, double>? productNames;

  StockHealth status(double threshold) {
    if (quantity <= 0) return StockHealth.out;
    if (quantity < threshold) return StockHealth.low;
    return StockHealth.ok;
  }
}

/// Cache-first stock hub controller. Reads the local cache instantly (offline
/// OK — same contract as the POS grid), then refreshes the enriched balances
/// from the API when online. Ordering/filtering are pure projections over the
/// latest rows.
class StockController extends Notifier<StockState> {
  @override
  StockState build() {
    ref.listen(sessionContextProvider, (_, __) => load());
    return const StockLoading();
  }

  CachedCatalogDao get _dao => ref.read(localSalesServiceProvider).catalog;

  InventoryRepository get _repository => ref.read(inventoryRepositoryProvider);

  Future<void> load() async {
    state = await _fromCache(stale: false);
    try {
      await _repository.stockBalances(
        page: ref.read(sessionContextProvider).$1 == null ? 1 : 1,
        pageSize: 250,
        warehouseId: null,
      );
      // The repository also refreshes the offline cache; re-emit from cache so
      // names (warehouse/location/product) are never lost offline.
      state = await _fromCache(stale: false);
    } on AppException {
      state = await _fromCache(stale: true);
    }
  }

  Future<StockState> _fromCache({required bool stale}) async {
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId == null) return const StockEmpty();

    final warehouses = [
      for (final w in await _dao.warehouses(tenantId))
        Warehouse(id: w.warehouseId, name: w.name, code: w.code),
    ];
    final stock = await _dao.listStockRows(tenantId);
    if (stock.isEmpty && warehouses.isEmpty) return const StockEmpty();

    final rows = [
      for (final row in stock)
        StockRow(
          warehouseId: row.warehouseId,
          warehouseName: _nameOf(warehouses, row.warehouseId),
          productId: row.productId,
          name: row.productName,
          sku: null,
          barcode: null,
          unitOfMeasureName: '',
          quantity: row.quantity,
        ),
    ];

    final current = state;
    return StockReady(
      rows: rows,
      warehouses: warehouses,
      search: current is StockReady ? current.search : '',
      lowOnly: current is StockReady ? current.lowOnly : false,
      sort: current is StockReady ? current.sort : StockSort.lowest,
      lowThreshold: 0,
      selectedWarehouseId: null,
      stale: stale,
    );
  }

  String _nameOf(List<Warehouse> warehouses, String id) {
    for (final w in warehouses) {
      if (w.id == id) return w.name;
    }
    return 'Duka';
  }

  void setSearch(String value) {
    final current = state;
    if (current is StockReady) state = current.copyWith(search: value);
  }

  void setLowOnly(bool value) {
    final current = state;
    if (current is StockReady) state = current.copyWith(lowOnly: value);
  }

  void setSort(StockSort sort) {
    final current = state;
    if (current is StockReady) state = current.copyWith(sort: sort);
  }

  void setWarehouse(String? id) {
    final current = state;
    if (current is StockReady) {
      state = current.copyWith(selectedWarehouseId: () => id);
    }
  }

  Future<void> recordOpening(OpeningStockEntry entry) async {
    await _repository.recordOpeningStock(entry);
    await load();
  }

  Future<void> adjustStock(AdjustStockEntry entry) async {
    await _repository.adjustStock(entry);
    await load();
  }

  void reset() {
    state = const StockLoading();
  }
}

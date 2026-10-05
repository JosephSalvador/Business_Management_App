import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/product_repository.dart';
import '../domain/catalog.dart';
import '../domain/product.dart';

/// The products list plus the per-product selling prices and stock quantities
/// shown alongside it.
sealed class ProductsState {
  const ProductsState();
}

class ProductsLoading extends ProductsState {
  const ProductsLoading({this.search = ''});

  final String search;
}

class ProductsLoaded extends ProductsState {
  const ProductsLoaded({
    required this.items,
    required this.total,
    this.search = '',
    this.prices = const {},
    this.stockByProduct = const {},
  });

  final List<Product> items;
  final int total;
  final String search;

  /// productId → retail selling price (from the default price list).
  final Map<String, double> prices;

  /// productId → total on-hand quantity across locations.
  final Map<String, double> stockByProduct;

  bool get isEmpty => items.isEmpty;
}

class ProductsFailure extends ProductsState {
  const ProductsFailure(this.message);

  final String message;
}

/// Loads and mutates products through [ProductRepository]. Mutations throw on
/// failure so the calling page can surface the backend's message directly.
class ProductsController extends Notifier<ProductsState> {
  PriceList? _defaultPriceList;
  String _search = '';

  @override
  ProductsState build() => const ProductsLoading();

  ProductRepository get _repository => ref.read(productRepositoryProvider);

  /// Reloads the list. Pass [search] to change the filter; omit it to keep
  /// the current one (e.g. after create/update).
  Future<void> load({String? search}) async {
    if (search != null) {
      _search = search;
    }
    state = ProductsLoading(search: _search);
    try {
      final page = await _repository.list(search: _search);
      state = await _enrich(page);
    } on AppException catch (error) {
      state = ProductsFailure(error.message);
    }
  }

  Future<ProductsLoaded> _enrich(PagedProducts page) async {
    Map<String, double> prices = const {};
    if (_defaultPriceList == null) {
      try {
        _defaultPriceList = await _repository.defaultPriceList();
      } on AppException {
        // Prices are supplementary; the list must still render without them.
      }
    }
    final priceListId = _defaultPriceList?.id;
    if (priceListId != null) {
      try {
        final rows = await _repository.prices(priceListId);
        prices = {
          for (final row in rows)
            if (row.priceType == 0) row.productId: row.price,
        };
      } on AppException {
        // Same — badges degrade gracefully.
      }
    }

    Map<String, double> stock = const {};
    try {
      final balances = await _repository.balances();
      stock = {};
      for (final balance in balances) {
        stock[balance.productId] =
            (stock[balance.productId] ?? 0) + balance.quantity;
      }
    } on AppException {
      // Stock badges are optional decoration on this screen.
    }

    return ProductsLoaded(
      items: page.items,
      total: page.total,
      search: _search,
      prices: prices,
      stockByProduct: stock,
    );
  }

  Future<void> _ensureDefaultPriceList() async {
    if (_defaultPriceList != null) return;
    try {
      _defaultPriceList = await _repository.defaultPriceList();
    } on AppException {
      _defaultPriceList = null;
    }
  }

  /// Retail price type code (mirrors the backend enum ProductPriceType).
  static const int _retailPriceType = 0;

  /// Wholesale price type code.
  static const int _wholesalePriceType = 1;

  /// Creates the product and (optionally) its opening retail and wholesale
  /// prices. Returns the created product so the caller can offer opening stock.
  Future<Product> create(
    ProductDraft draft,
    double? sellingPrice, {
    double? wholesalePrice,
  }) async {
    final product = await _repository.create(draft);
    if (sellingPrice != null || wholesalePrice != null) {
      await _ensureDefaultPriceList();
    }
    if (sellingPrice != null && sellingPrice > 0 && _defaultPriceList != null) {
      await _repository.setSellingPrice(
        priceList: _defaultPriceList!,
        productId: product.id,
        price: sellingPrice,
        priceType: _retailPriceType,
      );
    }
    if (wholesalePrice != null &&
        wholesalePrice > 0 &&
        _defaultPriceList != null) {
      await _repository.setSellingPrice(
        priceList: _defaultPriceList!,
        productId: product.id,
        price: wholesalePrice,
        priceType: _wholesalePriceType,
      );
    }
    await load();
    return product;
  }

  Future<void> update(
    String id,
    ProductDraft draft,
    double? sellingPrice, {
    double? wholesalePrice,
  }) async {
    await _repository.update(id, draft);
    if (sellingPrice != null || wholesalePrice != null) {
      await _ensureDefaultPriceList();
    }
    if (sellingPrice != null && sellingPrice > 0 && _defaultPriceList != null) {
      await _repository.setSellingPrice(
        priceList: _defaultPriceList!,
        productId: id,
        price: sellingPrice,
        priceType: _retailPriceType,
      );
    }
    if (wholesalePrice != null &&
        wholesalePrice > 0 &&
        _defaultPriceList != null) {
      await _repository.setSellingPrice(
        priceList: _defaultPriceList!,
        productId: id,
        price: wholesalePrice,
        priceType: _wholesalePriceType,
      );
    }
    await load();
  }

  void reset() {
    _defaultPriceList = null;
    _search = '';
    state = const ProductsLoading();
  }
}

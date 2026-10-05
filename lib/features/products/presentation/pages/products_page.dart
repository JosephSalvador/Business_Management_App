import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/products_controller.dart';
import '../../domain/product.dart';
import 'opening_stock_sheet.dart';

/// Products page: searchable list with price and stock info.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(productsControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsControllerProvider);
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(title: Text(loc.productsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-product',
        onPressed: () async {
          final created = await context.push('/products/new');
          if (created is Product && context.mounted) {
            await _offerOpeningStock(created);
          }
        },
        icon: const Icon(Icons.add, size: 20),
        label: Text(loc.productsAdd),
      ),
      body: WaveBackground(
        child: switch (state) {
          ProductsLoading() => const Center(child: CircularProgressIndicator()),
          ProductsFailure(:final message) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.resolveTextSecondary(context)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.read(productsControllerProvider.notifier).load(),
                    child: Text(context.loc.commonRetry),
                  ),
                ],
              ),
            ),
          ProductsLoaded() when state.isEmpty && state.search.isEmpty =>
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: loc.productsEmpty,
              message: loc.productsEmptyMessage,
              actionLabel: loc.productsAdd,
              onAction: () => context.push('/products/new'),
            ),
          ProductsLoaded() => _ProductList(
              state: state,
              searchController: _searchController,
            ),
        },
      ),
    );
  }

  Future<void> _offerOpeningStock(Product product) async {
    final quantity = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OpeningStockSheet(product: product),
    );
    if (quantity != null) {
      await ref.read(stockControllerProvider.notifier).load();
      if (mounted) {
        ref.read(productsControllerProvider.notifier).load();
      }
    }
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({
    required this.state,
    required this.searchController,
  });
  final ProductsLoaded state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: loc.productsSearch,
              prefixIcon: Icon(Icons.search,
                  size: 20, color: AppColors.resolveTextTertiary(context)),
              suffixIcon: state.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        searchController.clear();
                        ref.read(productsControllerProvider.notifier).load();
                      },
                    ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (term) => ref
                .read(productsControllerProvider.notifier)
                .load(search: term),
          ),
        ),
        Expanded(
          child: state.isEmpty
              ? Center(
                  child: Text(
                    '${loc.productsNoResults} "${state.search}"',
                    style: TextStyle(
                        color: AppColors.resolveTextSecondary(context)),
                  ),
                )
              : ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = state.items[index];
                    return _ProductTile(
                      product: product,
                      price: state.prices[product.id],
                      stock: state.stockByProduct[product.id],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.price,
    required this.stock,
  });

  final Product product;
  final double? price;
  final double? stock;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: product.isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: product.isActive
                ? AppColors.primary
                : AppColors.resolveTextTertiary(context),
          ),
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (price != null)
            Text(
              '${loc.productsPrice}: ${price!.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            )
          else
            Text(
              loc.productsPriceNotSet,
              style: TextStyle(
                  fontSize: 13, color: AppColors.resolveTextTertiary(context)),
            ),
          Row(
            children: [
              if (product.sku != null && product.sku!.isNotEmpty)
                Expanded(
                  child: Text(
                    'SKU: ${product.sku}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.resolveTextTertiary(context),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              _StockBadge(
                stock: stock,
                inactive: !product.isActive,
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right,
          color: AppColors.resolveTextTertiary(context)),
      onTap: () => context.push('/products/${product.id}'),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({
    required this.stock,
    required this.inactive,
  });

  final double? stock;
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    if (inactive) {
      return _Badge(
          label: loc.productsClosed,
          color: AppColors.resolveTextTertiary(context));
    }
    if (stock == null) {
      return _Badge(label: loc.productsNoStock, color: AppColors.warning);
    }
    if (stock! <= 0) {
      return _Badge(label: loc.productsOutOfStock, color: AppColors.error);
    }
    final label = stock! % 1 == 0
        ? loc.productsStockLabel(stock!.toInt())
        : 'Stock: ${stock!.toStringAsFixed(2)}';
    return _Badge(label: label, color: AppColors.success);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

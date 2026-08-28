import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../application/products_controller.dart';
import '../../domain/product.dart';
import 'opening_stock_sheet.dart';

/// The Bidhaa tab: searchable product list with selling price and stock.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bidhaa')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-product',
        onPressed: () async {
          final created = await context.push('/products/new');
          if (created is Product && context.mounted) {
            await _offerOpeningStock(created);
          }
        },
        label: const Text('Ongeza bidhaa'),
        icon: const Icon(Icons.add),
      ),
      body: switch (state) {
        ProductsLoading() => const Center(child: CircularProgressIndicator()),
        ProductsFailure(:final message) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(productsControllerProvider.notifier).load(),
                  child: const Text('Jaribu tena'),
                ),
              ],
            ),
          ),
        ProductsLoaded() when state.isEmpty && state.search.isEmpty =>
          _EmptyProducts(onAdd: () => context.push('/products/new')),
          ProductsLoaded() => _ProductList(state: state, searchController: _searchController),
      },
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

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('Hujaongeza bidhaa bado'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Ongeza bidhaa'),
          ),
        ],
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({required this.state, required this.searchController});

  final ProductsLoaded state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Tafuta bidhaa…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
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
                  child: Text('Hakuna bidhaa kwa "${state.search}"'),
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
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        product.name,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (price != null)
            Text(
              'Bei: ${price!.toStringAsFixed(0)}',
              style: theme.textTheme.bodyLarge,
            )
          else
            Text('Bei: bado haijawekwa', style: theme.textTheme.bodySmall),
          Row(
            children: [
              if (product.sku != null && product.sku!.isNotEmpty)
                Expanded(child: Text('SKU: ${product.sku}', overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              _StockBadge(stock: stock, inactive: !product.isActive),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/products/${product.id}/edit'),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock, required this.inactive});

  final double? stock;
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    if (inactive) {
      return const Chip(label: Text('Imefungwa'), visualDensity: VisualDensity.compact);
    }
    final label = stock == null
        ? 'Hakuna stock'
        : stock! <= 0
            ? 'Stock imeisha'
            : 'Stock: ${_format(stock!)}';
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }

  static String _format(double value) => value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

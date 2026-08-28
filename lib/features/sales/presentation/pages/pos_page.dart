import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/connectivity_monitor.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/format/money.dart';
import '../../application/cart_controller.dart';
import '../../application/pos_catalog_controller.dart';
import 'sync_status_sheet.dart';
import 'payment_sheet.dart';

/// The Mauzo tab: search products, tap to add to the cart, pay. Works the
/// same online and offline — when offline, sales are recorded locally and
/// synced automatically once the internet returns (M5).
class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final state = ref.read(posCatalogControllerProvider);
    if (!state.hasLoadedOnce && !state.loading) {
      Future.microtask(
        () => ref.read(posCatalogControllerProvider.notifier).load(),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // Local-only search: instant and fully offline (M5.3).
      ref.read(posCatalogControllerProvider.notifier).load(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(posCatalogControllerProvider);
    final cart = ref.watch(cartControllerProvider);
    final connection = ref.watch(connectionQualityProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mauzo'),
        actions: [
          IconButton(
            tooltip: 'Hali ya mauzo',
            icon: Badge(
              isLabelVisible: syncStatus.pendingCount > 0,
              label: Text('${syncStatus.pendingCount}'),
              child: const Icon(Icons.sync),
            ),
            onPressed: () => showSyncStatusSheet(context),
          ),
          IconButton(
            tooltip: 'Mauzo ya leo',
            icon: const Icon(Icons.receipt_long),
            onPressed: () => context.push(Routes.salesHistory),
          ),
        ],
      ),
      body: Column(
        children: [
          _ConnectionBanner(quality: connection, stale: catalog.stale),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Tafuta bidhaa...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: switch (catalog) {
            _ when catalog.loading && catalog.items.isEmpty =>
              const Center(child: CircularProgressIndicator()),
            _ when catalog.items.isEmpty && catalog.search.isEmpty =>
              _EmptyView(hasSearch: false, stale: catalog.stale),
            _ when catalog.items.isEmpty => const _EmptyView(hasSearch: true),
            _ => _ProductGrid(
                items: catalog.items,
                onTap: _addToCart,
              ),
          }),
        ],
      ),
      bottomNavigationBar: cart.isEmpty ? null : _CartBar(cart: cart),
    );
  }

  void _addToCart(PosProduct product) {
    HapticFeedback.selectionClick();
    if (product.outOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bidhaa hii imeisha kwenye hesabu.')),
      );
      return;
    }
    ref
        .read(cartControllerProvider.notifier)
        .add(product.productId, product.name, product.price);
  }
}

/// The only network awareness a shop worker sees: one calm banner (M5.13).
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.quality, required this.stale});

  final ConnectionQuality quality;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (quality == ConnectionQuality.online && !stale) {
      return const SizedBox.shrink();
    }
    final (color, text) = switch (quality) {
      ConnectionQuality.online ||
      ConnectionQuality.unknown when stale =>
        (theme.colorScheme.error, 'Taarifa za bidhaa zinahitaji intaneti.'),
      ConnectionQuality.offline ||
      ConnectionQuality.unreachable =>
        (
          Colors.orange.shade800,
          'Offline — Mauzo yataendelea. Yatasawazishwa internet ikirudi.'
        ),
      _ => (Colors.orange.shade800, 'Inaangalia mtandao...'),
    };
    return Material(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.items, required this.onTap});

  final List<PosProduct> items;
  final void Function(PosProduct) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final product = items[index];
        return _ProductCard(
          name: product.name,
          price: product.price,
          outOfStock: product.outOfStock,
          onTap: () => onTap(product),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.outOfStock,
    required this.onTap,
  });

  final String name;
  final double? price;
  final bool outOfStock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      price == null || price == 0
                          ? 'Hakuna bei'
                          : formatMoney(price!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: price == null || price == 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (outOfStock)
                    Icon(Icons.inventory_2_outlined,
                        size: 18, color: theme.colorScheme.error),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBar extends ConsumerWidget {
  const _CartBar({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${cart.itemCount} bidhaa'),
                  Text(
                    formatMoney(cart.total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Lipa'),
              onPressed: () => showPaymentSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasSearch, this.stale = false});

  final bool hasSearch;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        hasSearch
            ? 'Bidhaa hazipatikani.'
            : stale
                ? 'Bidhaa zitaonekana hapa mara intaneti ikija.'
                : 'Hujaongeza bidhaa bado.',
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}

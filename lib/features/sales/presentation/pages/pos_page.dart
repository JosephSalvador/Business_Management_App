import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/connectivity_monitor.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/storage/local_database.dart' show CachedProduct;
import '../../../../core/storage/quick_sale_memory.dart' show RecentQuickSale;
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../shared/format/money.dart';
import '../../../products/data/product_repository.dart' show ProductDraft;
import '../../../products/domain/product.dart' show ProductType;
import '../../domain/sale.dart';
import '../../application/cart_controller.dart';
import '../../application/pos_catalog_controller.dart';
import '../../../../shared/design_system/responsive.dart';
import 'sync_status_sheet.dart';
import 'payment_sheet.dart';
import 'parked_carts_sheet.dart';
import 'shift_close_sheet.dart';

/// POS page: search products, add to cart, pay.
/// Works online and offline — offline sales sync when internet returns.
class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

/// One committed quick-sale line from the inline Quick Sale panel.
typedef QuickSaleEntry = ({String name, double amount, bool saveAsProduct});

class _PosPageState extends ConsumerState<PosPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  /// When true the product grid is replaced by the inline Quick Sale panel;
  /// the cart sidebar/bottom bar stays visible so totals update live.
  bool _quickSaleActive = false;
  String? _quickProductId;

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
      ref.read(posCatalogControllerProvider.notifier).load(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(posCatalogControllerProvider);
    final cart = ref.watch(cartControllerProvider);
    final connection = ref.watch(connectionQualityProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final parkedCarts = ref.watch(parkedCartsProvider);
    final loc = context.loc;

    return PopScope(
      canPop: !_quickSaleActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _quickSaleActive) {
          _exitQuickSale();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.posTitle),
          actions: [
            // Customer selector
            if (_selectedCustomerName != null)
              GestureDetector(
                onTap: _pickCustomer,
                child: Chip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: Text(
                    _selectedCustomerName!,
                    style: TextStyle(fontSize: 12),
                  ),
                  onDeleted: () => setState(() {
                    _selectedCustomerId = null;
                    _selectedCustomerName = null;
                  }),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                onPressed: _pickCustomer,
                tooltip: loc.posAddCustomer,
              ),
            // Parked carts button with badge
            Badge(
              isLabelVisible: parkedCarts.isNotEmpty,
              label: Text('${parkedCarts.length}'),
              child: IconButton(
                icon: const Icon(Icons.pause_circle_outline),
                tooltip: 'Oda Pembeni',
                onPressed: () => showParkedCartsSheet(context),
              ),
            ),
            // Shift close / Z-Report
            IconButton(
              icon: const Icon(Icons.point_of_sale_outlined),
              tooltip: 'Funga Hesabu (Z-Report)',
              onPressed: () => showShiftCloseSheet(context),
            ),
            // Connection status icon (wifi signal)
            _ConnectionIcon(quality: connection, stale: catalog.stale),
            Badge(
              isLabelVisible: syncStatus.pendingCount > 0,
              label: Text('${syncStatus.pendingCount}'),
              child: IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Usawazishaji & Outbox',
                onPressed: () => showSyncStatusSheet(context),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Historia ya Mauzo',
              onPressed: () => context.push(Routes.salesHistory),
            ),
          ],
        ),
        body: WaveBackground(
          child: Responsive.isDesktop(context) || Responsive.isTablet(context)
              ? _DesktopLayout(
                  catalog: catalog,
                  cart: cart,
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  onQuickSale: _startQuickSale,
                  onAddToCart: _addToCart,
                  onQuickQuantity: _quickQuantity,
                  loc: loc,
                  customerId: _selectedCustomerId,
                  customerName: _selectedCustomerName,
                  quickSalePanel:
                      _quickSaleActive ? _buildQuickSalePanel() : null,
                )
              : _MobileLayout(
                  catalog: catalog,
                  cart: cart,
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  onQuickSale: _startQuickSale,
                  onAddToCart: _addToCart,
                  onQuickQuantity: _quickQuantity,
                  loc: loc,
                  quickSalePanel:
                      _quickSaleActive ? _buildQuickSalePanel() : null,
                ),
        ),
        bottomNavigationBar:
            (Responsive.isDesktop(context) || Responsive.isTablet(context))
                ? null
                : (cart.isEmpty
                    ? null
                    : _CartBar(
                        cart: cart,
                        customerId: _selectedCustomerId,
                        customerName: _selectedCustomerName,
                      )),
      ),
    );
  }

  void _addToCart(PosProduct product) {
    HapticFeedback.selectionClick();
    if (product.outOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name}: ${context.loc.posOutOfStock}'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    ref
        .read(cartControllerProvider.notifier)
        .add(product.productId, product.name, product.price);
  }

  /// Quick sale flow: toggles the inline Quick Sale panel that replaces the
  /// product grid (cart stays visible so totals update live). Every committed
  /// entry is added to the cart immediately. The hidden product id comes from
  /// the local cache (bySku) or the persisted id first — both work offline;
  /// the server lazily creates it the first time.
  Future<void> _startQuickSale() async {
    final quickMemory = ref.read(localSalesServiceProvider).quickMemory;

    String? quickProductId;
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId != null) {
      final cached = await ref
          .read(localSalesServiceProvider)
          .catalog
          .bySku(tenantId, QuickSaleDefaults.sku);
      quickProductId =
          cached?.productId ?? await quickMemory.productId(tenantId);
    }
    if (quickProductId == null) {
      try {
        quickProductId = await ref
            .read(saleRepositoryProvider)
            .getOrCreateQuickSaleProduct();
        if (tenantId != null) {
          await quickMemory.rememberProductId(tenantId, quickProductId);
        }
      } catch (_) {
        // Resilient offline fallback: never block an offline sale!
        quickProductId = QuickSaleDefaults.provisionalProductId;
        if (tenantId != null) {
          await quickMemory.rememberProductId(tenantId, quickProductId);
        }
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _quickProductId = quickProductId;
      _quickSaleActive = true;
    });
  }

  void _exitQuickSale() {
    if (!_quickSaleActive) {
      return;
    }
    setState(() {
      _quickSaleActive = false;
      _quickProductId = null;
    });
  }

  Widget _buildQuickSalePanel() {
    return _QuickSalePanel(
      onCommit: _commitQuickEntry,
      onExit: _exitQuickSale,
    );
  }

  /// Commits one quick-sale entry to the cart immediately (so the cart sidebar
  /// updates live) and best-effort records it in quick-sale memory +
  /// registers it as a product when asked.
  void _commitQuickEntry(QuickSaleEntry entry) {
    final productId = _quickProductId;
    if (productId == null) {
      return;
    }
    final cart = ref.read(cartControllerProvider.notifier);
    cart.addQuickSale(
      productId: productId,
      name: entry.name,
      unitPrice: entry.amount,
    );
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId != null) {
      unawaited(
        ref
            .read(localSalesServiceProvider)
            .quickMemory
            .remember(tenantId, entry.name, entry.amount),
      );
    }
    if (entry.saveAsProduct) {
      unawaited(_saveAsProduct(entry));
    }
  }

  /// Best-effort "Rekodi kama bidhaa": registers the quick-sale item as a real
  /// catalogue product (with its retail price). Never blocks the sale itself —
  /// failures surface as a snackbar only.
  Future<void> _saveAsProduct(QuickSaleEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    try {
      final repo = ref.read(productRepositoryProvider);
      final tenantId = ref.read(sessionContextProvider).$1;
      if (tenantId != null) {
        final matches = await ref
            .read(localSalesServiceProvider)
            .catalog
            .search(tenantId, entry.name, limit: 5);
        final exists = matches.any(
          (p) => p.name.toLowerCase() == entry.name.toLowerCase(),
        );
        if (exists) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(loc.posQuickSaleProductExists),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }
      }
      final units = await repo.units();
      if (units.isEmpty) {
        return;
      }
      final product = await repo.create(
        ProductDraft(
          name: entry.name,
          unitOfMeasureId: units.first.id,
          productType: ProductType.goods,
        ),
      );
      final priceList = await repo.defaultPriceList();
      if (priceList != null) {
        await repo.setSellingPrice(
          priceList: priceList,
          productId: product.id,
          price: entry.amount,
          priceType: 0,
        );
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(loc.posQuickSaleProductSaved),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(loc.posQuickSaleProductSaveFailed(error.message)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Long-press a product to set an exact quantity without tapping +1 many
  /// times ("6 maji" in one step instead of six).
  Future<void> _quickQuantity(PosProduct product) async {
    if (product.outOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name}: ${context.loc.posOutOfStock}'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    final loc = context.loc;
    final controller = TextEditingController(text: '1');
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.posQuantity),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            hintText: product.name,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(parsed);
            },
            child: Text(loc.commonDone),
          ),
        ],
      ),
    );
    if (quantity != null && quantity > 0) {
      ref
          .read(cartControllerProvider.notifier)
          .add(product.productId, product.name, product.price);
      ref
          .read(cartControllerProvider.notifier)
          .setQuantity(product.productId, quantity);
    }
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<CustomerPick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedCustomerId = picked.id;
        _selectedCustomerName = picked.name;
      });
    }
  }
}

// ── Search Bar (shared between layouts) ──────────────────────────

Widget _buildSearchBar({
  required BuildContext context,
  required TextEditingController controller,
  required ValueChanged<String> onChanged,
  required AppLocalizations loc,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: loc.posSearchProducts,
        prefixIcon: Icon(Icons.search,
            size: 20, color: AppColors.resolveTextTertiary(context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
    ),
  );
}

Widget _buildQuickSaleButton({
  required VoidCallback onPressed,
  required AppLocalizations loc,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.bolt, size: 18, color: AppColors.primary),
            label: Text(
              loc.posQuickSale,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildProductArea({
  required PosCatalogState catalog,
  required void Function(PosProduct) onTap,
  required void Function(PosProduct) onQuantityTap,
  required AppLocalizations loc,
  required VoidCallback onQuickSale,
}) {
  return switch (catalog) {
    _ when catalog.loading && catalog.items.isEmpty =>
      const Center(child: CircularProgressIndicator()),
    _ when catalog.items.isEmpty && catalog.search.isEmpty => _EmptyView(
        message: catalog.stale ? loc.posOfflineProducts : loc.posNoProducts,
        icon: catalog.stale
            ? Icons.wifi_off_outlined
            : Icons.inventory_2_outlined,
        isOffline: catalog.stale,
        onQuickSale: onQuickSale,
      ),
    _ when catalog.items.isEmpty =>
      _EmptyView(message: loc.posNoSearchResults, icon: Icons.search_off),
    _ => _ProductGrid(
        items: catalog.items,
        onTap: onTap,
        onQuantityTap: onQuantityTap,
      ),
  };
}

// ── Mobile Layout (phone) ────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.catalog,
    required this.cart,
    required this.searchController,
    required this.onSearchChanged,
    required this.onQuickSale,
    required this.onAddToCart,
    required this.onQuickQuantity,
    required this.loc,
    this.quickSalePanel,
  });

  final PosCatalogState catalog;
  final CartState cart;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onQuickSale;
  final void Function(PosProduct) onAddToCart;
  final void Function(PosProduct) onQuickQuantity;
  final AppLocalizations loc;

  /// Inline Quick Sale panel replacing the product grid while active.
  final Widget? quickSalePanel;

  @override
  Widget build(BuildContext context) {
    if (quickSalePanel != null) {
      return quickSalePanel!;
    }
    return Column(
      children: [
        _buildSearchBar(
            context: context,
            controller: searchController,
            onChanged: onSearchChanged,
            loc: loc),
        _buildQuickSaleButton(onPressed: onQuickSale, loc: loc),
        Expanded(
          child: _buildProductArea(
              catalog: catalog,
              onTap: onAddToCart,
              onQuantityTap: onQuickQuantity,
              loc: loc,
              onQuickSale: onQuickSale),
        ),
      ],
    );
  }
}

// ── Desktop/Tablet Layout (sidebar cart) ─────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.catalog,
    required this.cart,
    required this.searchController,
    required this.onSearchChanged,
    required this.onQuickSale,
    required this.onAddToCart,
    required this.onQuickQuantity,
    required this.loc,
    this.customerId,
    this.customerName,
    this.quickSalePanel,
  });

  final PosCatalogState catalog;
  final CartState cart;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onQuickSale;
  final void Function(PosProduct) onAddToCart;
  final void Function(PosProduct) onQuickQuantity;
  final AppLocalizations loc;
  final String? customerId;
  final String? customerName;

  /// Inline Quick Sale panel replacing the product grid while active.
  final Widget? quickSalePanel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Product side (left)
        Expanded(
          flex: 3,
          child: quickSalePanel ??
              Column(
                children: [
                  _buildSearchBar(
                      context: context,
                      controller: searchController,
                      onChanged: onSearchChanged,
                      loc: loc),
                  _buildQuickSaleButton(onPressed: onQuickSale, loc: loc),
                  Expanded(
                    child: _buildProductArea(
                        catalog: catalog,
                        onTap: onAddToCart,
                        onQuantityTap: onQuickQuantity,
                        loc: loc,
                        onQuickSale: onQuickSale),
                  ),
                ],
              ),
        ),
        const VerticalDivider(width: 1),
        // Cart sidebar (right)
        SizedBox(
          width: 320,
          child: _DesktopCartSidebar(
            cart: cart,
            customerId: customerId,
            customerName: customerName,
          ),
        ),
      ],
    );
  }
}

class _DesktopCartSidebar extends ConsumerWidget {
  const _DesktopCartSidebar({
    required this.cart,
    this.customerId,
    this.customerName,
  });
  final CartState cart;
  final String? customerId;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    return Column(
      children: [
        // Cart header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(loc.posCart,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${cart.itemCount} ${loc.posItemsInCart}',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.resolveTextSecondary(context))),
            ],
          ),
        ),
        const Divider(height: 1),
        // Cart items list
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text(loc.posNoProducts,
                      style: TextStyle(
                          color: AppColors.resolveTextSecondary(context))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: cart.lines.length,
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    return _CartItemRow(line: line, ref: ref);
                  },
                ),
        ),
        const Divider(height: 1),
        // Total + Pay
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loc.posTotal,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                    formatMoney(cart.total),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: cart.isEmpty
                      ? null
                      : () => showPaymentSheet(
                            context,
                            ref,
                            customerId: customerId,
                            customerName: customerName,
                          ),
                  icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                  label: Text(loc.posPay, style: const TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Connection Icon (app bar wifi signal) ─────────────────────────

class _ConnectionIcon extends StatelessWidget {
  const _ConnectionIcon({required this.quality, required this.stale});

  final ConnectionQuality quality;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (quality) {
      ConnectionQuality.online || ConnectionQuality.unknown when stale => (
          AppColors.error,
          Icons.wifi_off
        ),
      ConnectionQuality.offline || ConnectionQuality.unreachable => (
          AppColors.warning,
          Icons.wifi_off
        ),
      ConnectionQuality.online => (AppColors.success, Icons.wifi),
      _ => (AppColors.warning, Icons.wifi_find),
    };

    return Tooltip(
      message: switch (quality) {
        ConnectionQuality.online when !stale => 'Mtandao',
        ConnectionQuality.online => 'Taarifa zimepropa',
        ConnectionQuality.offline => 'Offline',
        ConnectionQuality.unreachable => 'Haijaeleweka',
        _ => 'Inaangalia...',
      },
      child: Icon(icon, size: 20, color: color),
    );
  }
}

// ── Product Grid ──────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.items,
    required this.onTap,
    required this.onQuantityTap,
  });

  final List<PosProduct> items;
  final void Function(PosProduct) onTap;
  final void Function(PosProduct) onQuantityTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final product = items[index];
        return _ProductCard(
          name: product.name,
          price: product.price,
          outOfStock: product.outOfStock,
          onTap: () => onTap(product),
          onQuantityTap: () => onQuantityTap(product),
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
    this.onQuantityTap,
  });

  final String name;
  final double? price;
  final bool outOfStock;
  final VoidCallback onTap;
  final VoidCallback? onQuantityTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product initial or icon + quantity button
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: outOfStock
                          ? AppColors.warningContainer
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            outOfStock ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onQuantityTap != null)
                    InkWell(
                      onTap: onQuantityTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.tag,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      price == null || price == 0
                          ? 'Hakuna bei'
                          : formatMoney(price!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: price == null || price == 0
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  if (outOfStock)
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: AppColors.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cart Bar ──────────────────────────────────────────────────────

class _CartBar extends ConsumerWidget {
  const _CartBar({required this.cart, this.customerId, this.customerName});
  final CartState cart;
  final String? customerId;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Inline cart items — always visible when cart has items
            if (cart.lines.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: cart.lines.length,
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    return _CartItemRow(line: line, ref: ref);
                  },
                ),
              ),
            if (cart.lines.isNotEmpty) const SizedBox(height: 6),
            // Total + Pay button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cart.itemCount} ${context.loc.posItemsInCart}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.resolveTextSecondary(context),
                        ),
                      ),
                      Text(
                        formatMoney(cart.total),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.resolveTextPrimary(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.pause_circle_outline, size: 20),
                  tooltip: 'Weka Oda Pembeni',
                  onPressed: () async {
                    await ref.read(parkedCartsProvider.notifier).park(
                          cart.lines,
                          customerName: customerName,
                          customerId: customerId,
                        );
                    ref.read(cartControllerProvider.notifier).clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Oda imewekwa pembeni!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                  label: Text(
                    context.loc.posPay,
                    style: const TextStyle(fontSize: 15),
                  ),
                  onPressed: () => showPaymentSheet(
                    context,
                    ref,
                    customerId: customerId,
                    customerName: customerName,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({required this.line, required this.ref});
  final CartLine line;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final quantityLabel = line.quantity % 1 == 0
        ? line.quantity.round().toString()
        : line.quantity.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            onPressed: () =>
                ref.read(cartControllerProvider.notifier).decrement(line.key),
          ),
          SizedBox(
            width: 32,
            child: Text(
              quantityLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            onPressed: () =>
                ref.read(cartControllerProvider.notifier).increment(line.key),
          ),
          const SizedBox(width: 2),
          // Tappable price — tap to override
          InkWell(
            onTap: () => _editPrice(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                formatPrice(line),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () =>
                ref.read(cartControllerProvider.notifier).remove(line.key),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child:
                  Icon(Icons.delete_outline, size: 16, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  String formatPrice(CartLine line) {
    final effectivePrice = line.unitPriceOverride ?? line.unitPrice;
    final total = effectivePrice * line.quantity;
    return formatMoney(total);
  }

  Future<void> _editPrice(BuildContext context) async {
    final loc = context.loc;
    final currentPrice = line.unitPriceOverride ?? line.unitPrice;
    final controller = TextEditingController(
      text: currentPrice == currentPrice.roundToDouble()
          ? currentPrice.round().toString()
          : currentPrice.toStringAsFixed(2),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.posEditPrice),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            hintText: loc.posEditPriceHint,
            prefixText: 'TSh ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(parsed);
            },
            child: Text(loc.commonDone),
          ),
        ],
      ),
    );
    if (value != null && value > 0) {
      ref
          .read(cartControllerProvider.notifier)
          .setPriceOverride(line.key, value);
    }
  }
}

// ── Empty View ────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.message,
    this.icon = Icons.inventory_2_outlined,
    this.isOffline = false,
    this.onQuickSale,
  });

  final String message;
  final IconData icon;
  final bool isOffline;
  final VoidCallback? onQuickSale;

  @override
  Widget build(BuildContext context) {
    if (isOffline) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'Uuzaji wa Nje ya Mtandao Umewezeshwa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Endelea Kuuza Bila Mtandao',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.resolveTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  'Hakuna orodha ya bidhaa zilizopakuliwa awali, lakini unaweza kuuza kwa '
                  'kuweka jina na bei moja kwa moja. Mauzo yote yanahifadhiwa salama kwenye kifaa hiki '
                  'na yatasawazishwa kiotomatiki mtandao ukirudi.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.resolveTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              if (onQuickSale != null)
                FilledButton.icon(
                  onPressed: onQuickSale,
                  icon: const Icon(Icons.bolt, size: 20),
                  label: const Text(
                    'Uza Haraka (Weka Bei)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon,
                size: 32, color: AppColors.resolveTextTertiary(context)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.resolveTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Quick Sale Panel ─────────────────────────────────────────────
// A cashier types a required name + price per item right inside the POS page
// (the product grid is swapped out, the cart stays visible). "+ Ongeza
// nyingine" commits the current entry to the cart immediately so totals
// update live; a big "UZA" commits any leftover text and returns to the
// catalog; "Ghairi"/X just closes the panel. The cart sidebar/bottom bar
// shows the added lines, so this panel does not keep its own entry list.

class _QuickSalePanel extends ConsumerStatefulWidget {
  const _QuickSalePanel({required this.onCommit, required this.onExit});

  /// Adds [QuickSaleEntry] to the cart + records memory/product.
  final void Function(QuickSaleEntry) onCommit;

  /// Closes the panel and returns to the catalog (cart stays as-is).
  final VoidCallback onExit;

  @override
  ConsumerState<_QuickSalePanel> createState() => _QuickSalePanelState();
}

class _QuickSalePanelState extends ConsumerState<_QuickSalePanel> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();
  Timer? _debounce;
  bool _saveAsProduct = false;
  String? _error;
  String _lastQuery = '';
  List<CachedProduct> _suggestions = const [];
  List<RecentQuickSale> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _amountController.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId == null) return;
    final value =
        await ref.read(localSalesServiceProvider).quickMemory.recent(tenantId);
    if (!mounted) return;
    setState(() => _recent = value);
  }

  void _onNameChanged() {
    final query = _nameController.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _lastQuery = '';
      setState(() => _suggestions = const []);
      return;
    }
    _lastQuery = query;
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query != _lastQuery) return;
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId == null) return;
    final found = await ref
        .read(localSalesServiceProvider)
        .catalog
        .search(tenantId, query, limit: 6);
    if (!mounted || query != _lastQuery) return;
    setState(() => _suggestions = found);
  }

  void _fillFromProduct(CachedProduct product) {
    _debounce?.cancel();
    _lastQuery = '';
    _nameController.text = product.name;
    if (product.retailPrice > 0) {
      _amountController.text = _priceValue(product.retailPrice);
    }
    _amountFocus.requestFocus();
  }

  void _fillFromRecent(RecentQuickSale item) {
    _debounce?.cancel();
    _lastQuery = '';
    _nameController.text = item.name;
    _amountController.text = _priceValue(item.price);
    _amountFocus.requestFocus();
  }

  static String _priceValue(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);

  /// Validates the current name + price and commits it to the cart. Returns
  /// false (showing the inline error) when the entry is not valid. The name is
  /// REQUIRED (Jina ni muhimu sana sio optional) — a receipt without a product
  /// name is useless.
  bool _commitCurrentEntry() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.loc.posQuickSaleNameRequired);
      return false;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = context.loc.posQuickSaleAmountRequired);
      return false;
    }
    widget
        .onCommit((name: name, amount: amount, saveAsProduct: _saveAsProduct));
    setState(() {
      _error = null;
      _suggestions = const [];
      _nameController.clear();
      _amountController.clear();
      // One-shot checkbox: "save THIS product" only. It resets so the next
      // item is never silently registered too — the cashier re-checks it per
      // product.
      _saveAsProduct = false;
    });
    _nameFocus.requestFocus();
    return true;
  }

  void _addAnother() {
    if (_commitCurrentEntry()) {
      setState(() {});
    }
  }

  void _sell() {
    final hasText = _nameController.text.trim().isNotEmpty ||
        _amountController.text.trim().isNotEmpty;
    if (hasText && !_commitCurrentEntry()) {
      return;
    }
    widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final quickCount = ref
        .watch(cartControllerProvider)
        .lines
        .where((line) => line.key.startsWith('quick-'))
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(loc.posQuickSale,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              InkWell(
                onTap: widget.onExit,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close,
                      size: 20, color: AppColors.resolveTextTertiary(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.posQuickSaleName,
                      hintText: loc.posQuickSaleHint,
                      prefixIcon:
                          const Icon(Icons.inventory_2_outlined, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  if (_suggestions.isNotEmpty) _buildSuggestions(loc),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: loc.posQuickSaleAmount,
                      prefixText: 'TSh ',
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(loc.posQuickSaleRecent,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.resolveTextPrimary(context))),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_recent.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in _recent.take(8))
                          ActionChip(
                            avatar: Icon(Icons.history,
                                size: 16,
                                color: AppColors.resolveTextTertiary(context)),
                            label: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: item.name,
                                    style: TextStyle(
                                        color: AppColors.resolveTextPrimary(
                                            context),
                                        fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text: ' · ${formatPriceValue(item.price)}',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.outline),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _fillFromRecent(item),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _saveAsProduct,
                    onChanged: (value) =>
                        setState(() => _saveAsProduct = value ?? false),
                    title: Text(loc.posQuickSaleSaveProduct,
                        style: const TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  if (quickCount > 0) ...[
                    const Divider(height: 16),
                    Text(
                      loc.posQuickSaleAddedCount(quickCount),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.resolveTextSecondary(context)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;
              final addAnother = OutlinedButton.icon(
                onPressed: _addAnother,
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.posQuickSaleAddAnother),
              );
              final sellButton = FilledButton.icon(
                onPressed: _sell,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: AppColors.success,
                ),
                icon: const Icon(Icons.sell, size: 18),
                label: Text(
                  loc.posQuickSaleSell,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: addAnother),
                        const SizedBox(width: 8),
                        Expanded(child: sellButton),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: widget.onExit,
                      child: Text(loc.commonCancel),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  TextButton(
                    onPressed: widget.onExit,
                    child: Text(loc.commonCancel),
                  ),
                  const Spacer(),
                  addAnother,
                  const SizedBox(width: 8),
                  sellButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(AppLocalizations loc) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final product in _suggestions)
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              leading:
                  const Icon(Icons.check, size: 18, color: AppColors.success),
              title: Text(product.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(formatPriceValue(product.retailPrice),
                  style: const TextStyle(fontSize: 12)),
              onTap: () => _fillFromProduct(product),
            ),
        ],
      ),
    );
  }
}

// ── Customer Picker Sheet (POS app bar) ──────────────────────────

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(customerRepositoryProvider)
          .list(search: _searchController.text.trim());
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _addCustomer() async {
    final loc = context.loc;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showDialog<({String name, String? phone})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.posAddCustomer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: loc.posAddCustomerName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: loc.posAddCustomerPhone),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop((
                name: name,
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
              ));
            },
            child: Text(loc.posAddCustomerSave),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      try {
        final created = await ref.read(customerRepositoryProvider).create({
          'name': result.name,
          if (result.phone != null) 'phone': result.phone,
        });
        if (mounted) {
          Navigator.of(context).pop(CustomerPick(
            id: created['id'] as String? ?? '',
            name: result.name,
          ));
        }
      } on AppException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.posCreditCustomer,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.resolveTextPrimary(context),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _addCustomer,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(loc.posAddCustomer),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: loc.posCreditCustomerHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(loc.posCreditNoCustomers),
              )
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final name = item['name'] as String? ?? '';
                    final phone = item['phone'] as String?;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(name),
                      subtitle: phone == null ? null : Text(phone),
                      onTap: () => Navigator.of(context).pop(
                        CustomerPick(
                          id: item['id'] as String? ?? '',
                          name: name,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

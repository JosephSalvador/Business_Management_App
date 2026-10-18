import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../application/suppliers_controller.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(suppliersControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _filter = v.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(suppliersControllerProvider.notifier)
          .load(search: v.trim(), silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(suppliersControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.suppliersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/suppliers/new'),
          ),
        ],
      ),
      body: WaveBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppSearchBar(
                controller: _searchController,
                hintText: context.loc.suppliersSearchHint,
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: _buildBody(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SuppliersState state) {
    if (state is SuppliersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is SuppliersFailure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(suppliersControllerProvider.notifier).load(),
                child: Text(context.loc.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    final loaded = state as SuppliersLoaded;
    final filtered = _filter.isEmpty
        ? loaded.items
        : loaded.items.where((s) {
            final name = (s['name'] ?? '').toString().toLowerCase();
            final phone = (s['phone'] ?? '').toString().toLowerCase();
            final email = (s['email'] ?? '').toString().toLowerCase();
            final contact = (s['contactPerson'] ?? '').toString().toLowerCase();
            return name.contains(_filter) ||
                phone.contains(_filter) ||
                email.contains(_filter) ||
                contact.contains(_filter);
          }).toList();

    if (filtered.isEmpty) {
      if (_filter.isNotEmpty) {
        return Center(
          child: Text(
            'Hakuna msambazaji aliyepatikana kwa "$_filter"',
            style: TextStyle(color: AppColors.resolveTextSecondary(context)),
          ),
        );
      }
      return EmptyState(
        icon: Icons.local_shipping_outlined,
        title: context.loc.suppliersEmpty,
        message: context.loc.suppliersEmptyMessage,
        actionLabel: context.loc.suppliersAdd,
        onAction: () => context.push('/suppliers/new'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(suppliersControllerProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final supplier = filtered[index];
          return _buildSupplierTile(supplier);
        },
      ),
    );
  }

  Widget _buildSupplierTile(Map<String, dynamic> supplier) {
    final name = supplier['name'] ?? '';
    final phone = supplier['phone'] ?? '';
    final email = supplier['email'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF00D4AA).withValues(alpha: 0.1),
          child: Text(
            initials,
            style: const TextStyle(
              color: Color(0xFF00D4AA),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(phone.isNotEmpty ? phone : email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/suppliers/${supplier['id']}/edit'),
      ),
    );
  }
}

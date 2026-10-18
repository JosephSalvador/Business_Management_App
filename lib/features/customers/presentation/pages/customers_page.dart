import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  Timer? _debounce;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    ref.read(customersControllerProvider.notifier).load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _filter = v.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(customersControllerProvider.notifier)
          .load(search: v.trim(), silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersControllerProvider);
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.customersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/credit/outstanding'),
            tooltip: loc.customersDebtors,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push('/customers/new'),
          ),
        ],
      ),
      body: WaveBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppSearchBar(
                hintText: loc.customersSearch,
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CustomersState state) {
    final loc = context.loc;
    return switch (state) {
      CustomersLoading() => const Center(child: CircularProgressIndicator()),
      CustomersFailure(:final message) => Center(
          child: Text(
            message,
            style: TextStyle(color: AppColors.resolveTextSecondary(context)),
          ),
        ),
      CustomersLoaded(:final items) => () {
          final filtered = _filter.isEmpty
              ? items
              : items.where((c) {
                  final name = (c['name'] ?? '').toString().toLowerCase();
                  final phone = (c['phone'] ?? '').toString().toLowerCase();
                  final email = (c['email'] ?? '').toString().toLowerCase();
                  return name.contains(_filter) ||
                      phone.contains(_filter) ||
                      email.contains(_filter);
                }).toList();

          return filtered.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: loc.customersEmpty,
                  message: loc.customersEmptyMessage,
                  actionLabel: loc.customersAdd,
                  onAction: () => context.push('/customers/new'),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(customersControllerProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return _CustomerTile(customer: customer);
                    },
                  ),
                );
        }(),
    };
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});
  final Map<String, dynamic> customer;

  @override
  Widget build(BuildContext context) {
    final name = customer['name'] ?? '';
    final phone = customer['phone'] ?? '';
    final email = customer['email'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          phone.isNotEmpty ? phone : email,
          style: TextStyle(
              color: AppColors.resolveTextSecondary(context), fontSize: 13),
        ),
        trailing: Icon(Icons.chevron_right,
            color: AppColors.resolveTextTertiary(context)),
        onTap: () => context.push('/customers/${customer['id']}'),
      ),
    );
  }
}

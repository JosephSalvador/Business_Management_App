import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/design_system/app_colors.dart';
import '../../application/notifications_controller.dart';
import '../../domain/notification_item.dart';

class NotificationCenterSheet extends ConsumerStatefulWidget {
  const NotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationCenterSheet(),
    );
  }

  @override
  ConsumerState<NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState
    extends ConsumerState<NotificationCenterSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(notificationsControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final isSwahili = Localizations.localeOf(context).languageCode != 'en';
    final cardBg = AppColors.resolveCardBackground(context);
    final textColor = AppColors.resolveTextPrimary(context);
    final secondaryText = AppColors.resolveTextSecondary(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.resolveOutline(context)
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Top Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      isSwahili ? 'Arifa' : 'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    if (state.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (state.unreadCount > 0)
                      TextButton(
                        onPressed: () => controller.markAllAsRead(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          isSwahili ? 'Soma Zote' : 'Mark all read',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Filter Tabs
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: NotificationCategory.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = NotificationCategory.values[index];
                      final isSelected = state.selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(isSwahili ? cat.labelSw : cat.labelEn),
                        selected: isSelected,
                        onSelected: (_) => controller.setCategory(cat),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 16),

              // Content List
              Expanded(
                child: state.isLoading && state.items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 56,
                                  color: secondaryText.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isSwahili
                                      ? 'Hauna arifa zozote kwa sasa'
                                      : 'No notifications at this time',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: state.items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.items[index];
                              return _NotificationCard(
                                item: item,
                                isSwahili: isSwahili,
                                onTap: () {
                                  controller.markAsRead(item.id);
                                  _handleNotificationTap(context, item);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleNotificationTap(BuildContext context, NotificationItem item) {
    if (item.dataJson == null) return;
    try {
      final data = jsonDecode(item.dataJson!) as Map<String, dynamic>;
      final route = data['route'] as String?;
      if (route != null && route.isNotEmpty) {
        Navigator.of(context).pop();
        context.push(route);
      }
    } catch (_) {
      // Ignored non-json payload
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isSwahili,
    required this.onTap,
  });

  final NotificationItem item;
  final bool isSwahili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, bgBadgeColor) = switch (item.category) {
      'Cash' => (
          Icons.payments_rounded,
          Colors.amber.shade800,
          Colors.amber.shade50
        ),
      'Sales' => (
          Icons.point_of_sale_rounded,
          Colors.green.shade800,
          Colors.green.shade50
        ),
      'Stock' => (
          Icons.inventory_2_rounded,
          Colors.deepOrange.shade800,
          Colors.deepOrange.shade50
        ),
      'Credit' => (
          Icons.receipt_long_rounded,
          Colors.blue.shade800,
          Colors.blue.shade50
        ),
      _ => (
          Icons.notifications_rounded,
          AppColors.primary,
          Colors.blueGrey.shade50
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.resolveCardBackground(context)
              : AppColors.primary.withValues(alpha: 0.04),
          border: Border.all(
            color: item.isRead
                ? AppColors.resolveOutline(context).withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.25),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgBadgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title(isSwahili ? 'sw' : 'en'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                item.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.resolveTextPrimary(context),
                          ),
                        ),
                      ),
                      Text(
                        _formatRelativeTime(item.createdAt, isSwahili),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.resolveTextTertiary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body(isSwahili ? 'sw' : 'en'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time, bool isSwahili) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return isSwahili ? 'Sasa hivi' : 'Just now';
    }
    if (diff.inMinutes < 60) {
      return isSwahili ? 'Dk ${diff.inMinutes}' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return isSwahili ? 'Saa ${diff.inHours}' : '${diff.inHours}h ago';
    }
    return isSwahili ? 'Siku ${diff.inDays}' : '${diff.inDays}d ago';
  }
}

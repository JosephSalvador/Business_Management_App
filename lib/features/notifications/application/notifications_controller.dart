import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_providers.dart';
import '../data/notification_repository.dart';
import '../domain/notification_item.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const <NotificationItem>[],
    this.unreadCount = 0,
    this.isLoading = false,
    this.selectedCategory = NotificationCategory.all,
    this.errorMessage,
  });

  final List<NotificationItem> items;
  final int unreadCount;
  final bool isLoading;
  final NotificationCategory selectedCategory;
  final String? errorMessage;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? isLoading,
    NotificationCategory? selectedCategory,
    String? errorMessage,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessage: errorMessage,
    );
  }
}

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    return const NotificationsState();
  }

  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final unreadCount = await _repository.getUnreadCount();
      final page = await _repository.list(
        page: 1,
        pageSize: 50,
        category: state.selectedCategory.apiValue,
      );

      state = state.copyWith(
        items: page.items,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> setCategory(NotificationCategory category) async {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category, isLoading: true);
    try {
      final page = await _repository.list(
        page: 1,
        pageSize: 50,
        category: category.apiValue,
      );
      state = state.copyWith(items: page.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> markAsRead(String id) async {
    final updated = state.items.map((n) {
      if (n.id == id && !n.isRead) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }
      return n;
    }).toList(growable: false);

    final newCount = (state.unreadCount - 1).clamp(0, 9999);
    state = state.copyWith(items: updated, unreadCount: newCount);

    try {
      await _repository.markAsRead(id);
    } catch (_) {
      // Optimistic update
    }
  }

  Future<void> markAllAsRead() async {
    final updated = state.items.map((n) {
      return n.copyWith(isRead: true, readAt: DateTime.now());
    }).toList(growable: false);

    state = state.copyWith(items: updated, unreadCount: 0);

    try {
      await _repository.markAllAsRead();
    } catch (_) {
      // Optimistic update
    }
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolinx_app/features/notifications/application/notifications_controller.dart';
import 'package:jolinx_app/features/notifications/data/notification_providers.dart';
import 'package:jolinx_app/features/notifications/data/notification_repository.dart';
import 'package:jolinx_app/features/notifications/domain/notification_item.dart';

class FakeNotificationRepository implements NotificationRepository {
  List<NotificationItem> items = [];
  int unreadCount = 0;
  bool markAsReadCalled = false;
  bool markAllAsReadCalled = false;
  bool registerDeviceCalled = false;
  bool unregisterDeviceCalled = false;

  @override
  Future<NotificationPage> list({
    int page = 1,
    int pageSize = 50,
    String? category,
    bool? unreadOnly,
  }) async {
    final filtered = items.where((i) {
      if (category != null && i.category != category) return false;
      if (unreadOnly == true && i.isRead) return false;
      return true;
    }).toList();
    return NotificationPage(
      items: filtered,
      page: page,
      total: filtered.length,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    return unreadCount;
  }

  @override
  Future<bool> markAsRead(String id) async {
    markAsReadCalled = true;
    items = items.map((i) {
      if (i.id == id) {
        return i.copyWith(isRead: true, readAt: DateTime.now());
      }
      return i;
    }).toList();
    unreadCount = (unreadCount - 1).clamp(0, 999);
    return true;
  }

  @override
  Future<int> markAllAsRead() async {
    markAllAsReadCalled = true;
    final count = items.where((i) => !i.isRead).length;
    items = items.map((i) => i.copyWith(isRead: true, readAt: DateTime.now())).toList();
    unreadCount = 0;
    return count;
  }

  @override
  Future<bool> registerDevice({
    required String deviceId,
    required String fcmToken,
    required String platform,
    String? deviceName,
  }) async {
    registerDeviceCalled = true;
    return true;
  }

  @override
  Future<bool> unregisterDevice(String deviceId) async {
    unregisterDeviceCalled = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NotificationItem tests', () {
    test('NotificationItem.fromJson parses correctly', () {
      final json = <String, dynamic>{
        'id': 'notif-1',
        'userId': 'user-1',
        'targetRole': 'Owner',
        'branchId': 'branch-1',
        'category': 'Cash',
        'type': 'CashShortage',
        'titleSw': 'Upungufu wa Fedha',
        'titleEn': 'Cash Shortage Detected',
        'bodySw': 'Upungufu wa TZS 15,000 umerekodiwa',
        'bodyEn': 'Discrepancy of TZS 15,000 detected',
        'dataJson': '{"shortage": 15000}',
        'isRead': false,
        'readAt': null,
        'createdAt': '2026-10-13T10:00:00Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, 'notif-1');
      expect(item.category, 'Cash');
      expect(item.type, 'CashShortage');
      expect(item.title('sw'), 'Upungufu wa Fedha');
      expect(item.title('en'), 'Cash Shortage Detected');
      expect(item.body('sw'), 'Upungufu wa TZS 15,000 umerekodiwa');
      expect(item.body('en'), 'Discrepancy of TZS 15,000 detected');
      expect(item.isRead, isFalse);
    });

    test('NotificationItem.copyWith updates isRead and readAt', () {
      final item = NotificationItem(
        id: '1',
        category: 'Cash',
        type: 'CashShortage',
        titleSw: 'Sw',
        titleEn: 'En',
        bodySw: 'BSw',
        bodyEn: 'BEn',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final now = DateTime.now();
      final updated = item.copyWith(isRead: true, readAt: now);

      expect(updated.isRead, isTrue);
      expect(updated.readAt, now);
      expect(updated.id, '1');
    });
  });

  group('NotificationsController tests', () {
    test('load fetches notifications and unread count', () async {
      final fakeRepo = FakeNotificationRepository();
      fakeRepo.unreadCount = 3;
      fakeRepo.items = [
        NotificationItem(
          id: 'n1',
          category: 'Cash',
          type: 'CashShortage',
          titleSw: 'Sw 1',
          titleEn: 'En 1',
          bodySw: 'B1',
          bodyEn: 'B1',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationItem(
          id: 'n2',
          category: 'Stock',
          type: 'LowStock',
          titleSw: 'Sw 2',
          titleEn: 'En 2',
          bodySw: 'B2',
          bodyEn: 'B2',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(notificationsControllerProvider.notifier);
      await controller.load();

      final state = container.read(notificationsControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.unreadCount, 3);
      expect(state.items.length, 2);
    });

    test('markAsRead optimistically updates item state and unread count', () async {
      final fakeRepo = FakeNotificationRepository();
      fakeRepo.unreadCount = 2;
      fakeRepo.items = [
        NotificationItem(
          id: 'n1',
          category: 'Cash',
          type: 'CashShortage',
          titleSw: 'Sw 1',
          titleEn: 'En 1',
          bodySw: 'B1',
          bodyEn: 'B1',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(notificationsControllerProvider.notifier);
      await controller.load();
      await controller.markAsRead('n1');

      final state = container.read(notificationsControllerProvider);
      expect(state.unreadCount, 1);
      expect(state.items.first.isRead, isTrue);
      expect(fakeRepo.markAsReadCalled, isTrue);
    });

    test('markAllAsRead marks all items read and clears unread counter', () async {
      final fakeRepo = FakeNotificationRepository();
      fakeRepo.unreadCount = 2;
      fakeRepo.items = [
        NotificationItem(
          id: 'n1',
          category: 'Cash',
          type: 'CashShortage',
          titleSw: 'Sw 1',
          titleEn: 'En 1',
          bodySw: 'B1',
          bodyEn: 'B1',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(notificationsControllerProvider.notifier);
      await controller.load();
      await controller.markAllAsRead();

      final state = container.read(notificationsControllerProvider);
      expect(state.unreadCount, 0);
      expect(state.items.every((n) => n.isRead), isTrue);
      expect(fakeRepo.markAllAsReadCalled, isTrue);
    });
  });
}

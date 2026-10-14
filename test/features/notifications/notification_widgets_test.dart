import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/l10n/generated/app_localizations.dart';
import 'package:jolinx_app/features/notifications/application/notifications_controller.dart';
import 'package:jolinx_app/features/notifications/data/notification_providers.dart';
import 'package:jolinx_app/features/notifications/data/notification_repository.dart';
import 'package:jolinx_app/features/notifications/domain/notification_item.dart';
import 'package:jolinx_app/features/notifications/presentation/pages/notification_center_sheet.dart';
import 'package:jolinx_app/features/notifications/presentation/widgets/notification_bell_button.dart';

class FakeNotificationRepository implements NotificationRepository {
  List<NotificationItem> items = [];
  int unreadCount = 0;
  bool markAsReadCalled = false;
  bool markAllAsReadCalled = false;

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
  Future<int> getUnreadCount() async => unreadCount;

  @override
  Future<bool> markAsRead(String id) async {
    markAsReadCalled = true;
    items = items.map((i) {
      if (i.id == id) return i.copyWith(isRead: true, readAt: DateTime.now());
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
  }) async => true;

  @override
  Future<bool> unregisterDevice(String deviceId) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('NotificationBellButton shows unread badge when unreadCount > 0', (tester) async {
    final fakeRepo = FakeNotificationRepository();
    fakeRepo.unreadCount = 5;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NotificationBellButton(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Bell icon should be present
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

    // Initial state before load is 0, so trigger load
    final container = ProviderScope.containerOf(tester.element(find.byType(NotificationBellButton)));
    await container.read(notificationsControllerProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('NotificationCenterSheet displays notifications and tabs', (tester) async {
    final fakeRepo = FakeNotificationRepository();
    fakeRepo.unreadCount = 1;
    fakeRepo.items = [
      NotificationItem(
        id: 'n1',
        category: 'Cash',
        type: 'CashShortage',
        titleSw: 'Upungufu wa Fedha',
        titleEn: 'Cash Shortage Detected',
        bodySw: 'Upungufu wa TZS 15,000 umerekodiwa mwisho wa zamu.',
        bodyEn: 'Discrepancy of TZS 15,000 detected at session close.',
        isRead: false,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          locale: Locale('sw'),
          supportedLocales: [Locale('sw'), Locale('en')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 500,
              child: NotificationCenterSheet(),
            ),
          ),
        ),
      ),
    );

    // Initial load
    final container = ProviderScope.containerOf(tester.element(find.byType(NotificationCenterSheet)));
    await container.read(notificationsControllerProvider.notifier).load();
    await tester.pumpAndSettle();

    // Check title and item presence
    expect(find.text('Arifa'), findsOneWidget);
    expect(find.text('Upungufu wa Fedha'), findsOneWidget);
    expect(find.text('Upungufu wa TZS 15,000 umerekodiwa mwisho wa zamu.'), findsOneWidget);
  });
}

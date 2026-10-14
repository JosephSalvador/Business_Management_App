import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../domain/notification_item.dart';

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
    required this.page,
  });

  final List<NotificationItem> items;
  final int total;
  final int page;
}

class NotificationRepository {
  NotificationRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<NotificationPage> list({
    int page = 1,
    int pageSize = 20,
    String? category,
    bool? unreadOnly,
  }) async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/notifications'),
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (category != null) 'category': category,
        if (unreadOnly != null) 'unreadOnly': unreadOnly,
      },
    );

    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Arifa hazipatikani kwa sasa.');
    }

    final doc = Map<String, dynamic>.from(response.data as Map);
    final rawItems = doc['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) =>
                NotificationItem.fromJson(Map<String, dynamic>.from(raw)))
            .toList(growable: false)
        : <NotificationItem>[];

    return NotificationPage(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
      page: (doc['page'] as num?)?.toInt() ?? page,
    );
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/notifications/unread-count'),
    );

    if (response.statusCode != 200 || response.data is! Map) {
      return 0;
    }

    final doc = Map<String, dynamic>.from(response.data as Map);
    return (doc['count'] as num?)?.toInt() ?? 0;
  }

  Future<bool> markAsRead(String id) async {
    final response = await _apiClient.patch<dynamic>(
      ApiRoutes.v1('/notifications/$id/read'),
    );
    return response.statusCode == 200;
  }

  Future<int> markAllAsRead() async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/notifications/mark-all-read'),
    );
    if (response.statusCode == 200 && response.data is num) {
      return (response.data as num).toInt();
    }
    return 0;
  }

  Future<bool> registerDevice({
    required String deviceId,
    required String fcmToken,
    required String platform,
    String? deviceName,
  }) async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/devices/register'),
      body: <String, dynamic>{
        'deviceId': deviceId,
        'fcmToken': fcmToken,
        'platform': platform,
        if (deviceName != null) 'deviceName': deviceName,
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> unregisterDevice(String deviceId) async {
    final response = await _apiClient.delete<dynamic>(
      ApiRoutes.v1('/devices/$deviceId'),
    );
    return response.statusCode == 200;
  }
}

import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _api = ApiService();

  Future<NotificationResponse> getNotifications({
    int page = 1,
    int limit = 20,
    bool? read,
    String? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (read != null) queryParams['read'] = read.toString();
      if (type != null) queryParams['type'] = type;

      final response = await _api.get(
        ApiConfig.notifications,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          final notifications = (data['notifications'] as List<dynamic>?)
                  ?.map((n) => NotificationModel.fromJson(
                      Map<String, dynamic>.from(n as Map)))
                  .toList() ??
              [];
          final unreadCount = data['unreadCount'] as int? ?? 0;
          final pagination = data['pagination'] as Map<String, dynamic>?;
          return NotificationResponse(
            notifications: notifications,
            unreadCount: unreadCount,
            pagination: pagination != null
                ? NotificationPagination(
                    page: pagination['page'] as int? ?? 1,
                    limit: pagination['limit'] as int? ?? 20,
                    total: pagination['total'] as int? ?? 0,
                    pages: pagination['pages'] as int? ?? 1,
                  )
                : null,
          );
        }
      }
      return NotificationResponse(
        notifications: [],
        unreadCount: 0,
        pagination: null,
      );
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: Error fetching notifications: $e');
      }
      rethrow;
    }
  }

  Future<void> markAsRead(String id) async {
    await _api.put(ApiConfig.notificationMarkRead(id));
  }

  Future<void> markAllAsRead() async {
    await _api.put(ApiConfig.notificationsReadAll);
  }
}

class NotificationResponse {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final NotificationPagination? pagination;

  NotificationResponse({
    required this.notifications,
    required this.unreadCount,
    this.pagination,
  });
}

class NotificationPagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  NotificationPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });
}

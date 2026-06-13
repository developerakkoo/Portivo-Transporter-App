import 'package:flutter/foundation.dart';
import '../data/models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final SocketService _socketService = SocketService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  NotificationProvider() {
    _socketService.addTripCreatedListener(_onTripCreated);
    _socketService.addMarketplaceChatListener(_onMarketplaceSocket);
    _socketService.addVehicleTypeRequestListener(_onVehicleTypeRequestUpdated);
  }

  void _onTripCreated(Map<String, dynamic> _) {
    loadNotifications(refresh: true);
  }

  void _onMarketplaceSocket(Map<String, dynamic> payload) {
    if (payload.containsKey('message') || payload['_event'] == 'booking:price-proposed') {
      loadNotifications(refresh: true);
    }
  }

  void _onVehicleTypeRequestUpdated(Map<String, dynamic> _) {
    loadNotifications(refresh: true);
  }

  Future<void> loadNotifications({bool refresh = false}) async {
    _isLoading = true;
    _error = null;
    if (refresh) _notifications = [];
    notifyListeners();

    try {
      final response = await _notificationService.getNotifications(
        page: 1,
        limit: 50,
      );
      _notifications = response.notifications;
      _unreadCount = response.unreadCount;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('NotificationProvider: Error loading notifications: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _notificationService.markAsRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index >= 0 && !_notifications[index].read) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          type: _notifications[index].type,
          title: _notifications[index].title,
          message: _notifications[index].message,
          data: _notifications[index].data,
          read: true,
          readAt: DateTime.now(),
          priority: _notifications[index].priority,
          createdAt: _notifications[index].createdAt,
        );
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationProvider: Error marking as read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      _notifications = _notifications
          .map((n) => NotificationModel(
                id: n.id,
                type: n.type,
                title: n.title,
                message: n.message,
                data: n.data,
                read: true,
                readAt: DateTime.now(),
                priority: n.priority,
                createdAt: n.createdAt,
              ))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('NotificationProvider: Error marking all as read: $e');
      }
    }
  }

  @override
  void dispose() {
    _socketService.removeTripCreatedListener(_onTripCreated);
    _socketService.removeMarketplaceChatListener(_onMarketplaceSocket);
    super.dispose();
  }
}

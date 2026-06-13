import 'package:flutter/foundation.dart';

import '../data/models/marketplace_chat_models.dart';
import '../services/marketplace_message_cache.dart';
import '../services/socket_service.dart';
import '../services/vehicle_booking_service.dart';

/// Global marketplace chat: conversation list + socket fan-in for badges / refresh.
class MarketplaceChatProvider extends ChangeNotifier {
  MarketplaceChatProvider() {
    _socket.addMarketplaceChatListener(_onSocketPayload);
  }

  final VehicleBookingService _bookingService = VehicleBookingService();
  final SocketService _socket = SocketService();

  List<MarketplaceConversation> _conversations = [];
  bool _loading = false;
  String? _error;
  int _totalUnread = 0;

  List<MarketplaceConversation> get conversations => _conversations;
  bool get isLoading => _loading;
  String? get error => _error;
  int get totalUnread => _totalUnread;

  @override
  void dispose() {
    _socket.removeMarketplaceChatListener(_onSocketPayload);
    super.dispose();
  }

  void _onSocketPayload(Map<String, dynamic> payload) {
    final event = payload['_event']?.toString();
    if (event == 'chat:typing' || event == 'chat:message:read') {
      return;
    }
    if (payload.containsKey('message') || payload.containsKey('booking')) {
      loadConversations(silent: true);
    }
  }

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      _conversations = await _bookingService.fetchConversations();
      _totalUnread = _conversations.fold<int>(0, (s, c) => s + c.unreadCount);
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('MarketplaceChatProvider: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Optimistic remove from list; rolls back on API failure.
  Future<void> hideConversation(String bookingId, {required String actorId}) async {
    final idx = _conversations.indexWhere((c) => c.booking.id == bookingId);
    if (idx < 0) return;
    final removed = _conversations[idx];
    _conversations = List<MarketplaceConversation>.from(_conversations)..removeAt(idx);
    _totalUnread = _conversations.fold<int>(0, (s, c) => s + c.unreadCount);
    notifyListeners();

    try {
      await _bookingService.hideConversationFromInbox(bookingId);
      try {
        await MarketplaceMessageCache.instance.removeBooking(
          actorId: actorId,
          bookingId: bookingId,
        );
      } catch (_) {}
    } catch (e) {
      _conversations = List<MarketplaceConversation>.from(_conversations)..insert(idx, removed);
      _totalUnread = _conversations.fold<int>(0, (s, c) => s + c.unreadCount);
      notifyListeners();
      rethrow;
    }
  }

  void bumpUnreadHint() {
    notifyListeners();
  }
}

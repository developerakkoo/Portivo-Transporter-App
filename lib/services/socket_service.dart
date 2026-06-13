import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../core/config/api_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  final StorageService _storage = StorageService();
  bool _isConnected = false;
  DateTime? _lastSocketIssueLog;

  /// Last requested Socket.IO rooms (re-applied on every connect / reconnect).
  String? _joinedTransporterId;
  String? _joinedTripId;
  String? _joinedVehicleId;
  final Set<String> _joinedBookingIds = {};
  final Set<String> _threadActiveBookingIds = {};
  final Set<String> _joinedSupportTicketIds = {};

  final List<Completer<void>> _pendingConnectCompleters = [];
  final List<void Function(Map<String, dynamic>)> _marketplaceChatListeners = [];
  final List<void Function(Map<String, dynamic>)> _supportChatListeners = [];
  final List<void Function(Map<String, dynamic>)> _chatPeerPresenceListeners = [];
  final List<void Function(Map<String, dynamic>)> _marketplaceBookingLifecycleListeners = [];
  final List<void Function(String message)> _marketplaceChatErrorListeners = [];

  final List<void Function()> _reconnectedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripUpdatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripCreatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripCreatedFromBookingListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripCustomerAssignedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripStartedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripMilestoneUpdatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripCompletedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripPodPendingListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripAutoActivatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _vehicleStatusUpdatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _podUploadedListeners = [];
  final List<void Function(Map<String, dynamic>)> _podApprovedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripClosedWithoutPodListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripCancelledListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripVehicleAssignedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripDriverAssignedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripCustomerAcceptedListeners = [];
  final List<void Function(Map<String, dynamic>)> _tripCustomerRejectedListeners = [];
  final List<void Function(Map<String, dynamic>)> _driverLocationUpdatedListeners = [];
  final List<void Function(Map<String, dynamic>)> _driverStatusChangedListeners = [];
  final List<void Function(Map<String, dynamic>)> _vehicleTypeRequestUpdatedListeners = [];

  /// Marketplace T2T: `userId` is transporter id.
  void Function(String userId)? onUserOnline;
  void Function(String userId)? onUserOffline;

  void _dispatchPayload(
    List<void Function(Map<String, dynamic>)> listeners,
    dynamic data,
  ) {
    final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    for (final listener in listeners) {
      listener(payload);
    }
  }

  void _dispatchReconnect() {
    for (final listener in _reconnectedListeners) {
      listener();
    }
  }

  bool get isConnected => _isConnected;

  void _logSocketIssueThrottled(String headline, Object? detail) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    if (_lastSocketIssueLog != null &&
        now.difference(_lastSocketIssueLog!) < const Duration(seconds: 5)) {
      return;
    }
    _lastSocketIssueLog = now;
    print('SocketService: $headline${detail != null ? ' — $detail' : ''}');
    if (detail != null && detail.toString().toLowerCase().contains('timeout')) {
      print(
        'SocketService: Real-time channel unavailable; REST API still works. Retrying with backoff.',
      );
    }
  }

  /// Waits until the socket reports connected, or [timeout] elapses.
  Future<void> connectUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_isConnected) return;
    await connect();
    if (_isConnected) return;

    final completer = Completer<void>();
    _pendingConnectCompleters.add(completer);
    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      _logSocketIssueThrottled('connectUntilReady', 'timed out');
    } finally {
      _pendingConnectCompleters.remove(completer);
    }
  }

  void _completePendingConnects() {
    for (final c in _pendingConnectCompleters) {
      if (!c.isCompleted) c.complete();
    }
    _pendingConnectCompleters.clear();
  }

  void _rejoinRooms() {
    if (_socket == null || !_isConnected) return;
    final t = _joinedTransporterId;
    if (t != null) {
      _socket!.emit('join:transporter', t);
      if (kDebugMode) {
        print('SocketService: Re-joined transporter room: $t');
      }
    }
    final v = _joinedVehicleId;
    if (v != null) {
      _socket!.emit('join:vehicle', v);
      if (kDebugMode) {
        print('SocketService: Re-joined vehicle room: $v');
      }
    }
    final trip = _joinedTripId;
    if (trip != null) {
      _socket!.emit('join:trip', trip);
      if (kDebugMode) {
        print('SocketService: Re-joined trip room: $trip');
      }
    }
    for (final bookingId in _joinedBookingIds) {
      _socket!.emit('chat:join', {'bookingId': bookingId});
      if (kDebugMode) {
        print('SocketService: Re-joined chat: $bookingId');
      }
    }
    for (final bookingId in _threadActiveBookingIds) {
      _socket!.emit('chat:thread:join', {'bookingId': bookingId});
      if (kDebugMode) {
        print('SocketService: Re-joined chat thread presence: $bookingId');
      }
    }
    for (final ticketId in _joinedSupportTicketIds) {
      _socket!.emit('support:join', {'ticketId': ticketId});
      if (kDebugMode) {
        print('SocketService: Re-joined support ticket: $ticketId');
      }
    }
  }

  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      if (kDebugMode) {
        print('SocketService: Already connected');
      }
      return;
    }

    try {
      final token = await _storage.getAccessToken();
      if (token == null) {
        if (kDebugMode) {
          print('SocketService: No access token available - skipping connection');
        }
        return;
      }

      if (_socket != null) {
        _socket!.dispose();
        _socket = null;
      }

      final baseUrl = ApiConfig.effectiveSocketBaseUrl;

      if (kDebugMode) {
        print('SocketService: Connecting to Socket.IO at $baseUrl (path ${ApiConfig.socketPath})');
        if (ApiConfig.socketBaseUrlOverride.trim().isNotEmpty) {
          print('SocketService: Using socketBaseUrlOverride (REST base: ${ApiConfig.baseUrl})');
        }
      }

      // Flutter / dart:io: Engine.IO polling over XHR is not supported like in the browser.
      // Using polling first causes connectUntilReady timeouts while curl to /socket.io still works.
      // WebSocket-only matches socket_io_client expectations on mobile.
      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setPath(ApiConfig.socketPath)
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .setTimeout(45000)
            .setReconnectionAttempts(12)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(30000)
            .setRandomizationFactor(0.5)
            .enableReconnection()
            .disableAutoConnect()
            .build(),
      );

      _setupEventListeners();
      _socket!.connect();
    } catch (e, stackTrace) {
      _logSocketIssueThrottled('Connection setup failed', e);
      if (kDebugMode) {
        print('Stack: $stackTrace');
      }
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      _lastSocketIssueLog = null;
      _rejoinRooms();
      _completePendingConnects();
      _dispatchReconnect();
      if (kDebugMode) {
        print('SocketService: Connected successfully');
      }
    });

    _socket!.on('reconnect', (_) {
      _isConnected = true;
      _rejoinRooms();
      _dispatchReconnect();
      if (kDebugMode) {
        print('SocketService: Reconnected — rooms re-joined');
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      if (kDebugMode) {
        print('SocketService: Disconnected');
      }
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      _logSocketIssueThrottled('connect_error', error);
    });

    _socket!.onError((error) {
      _logSocketIssueThrottled('socket error', error);
    });

    _socket!.on('trip:updated', (data) {
      if (kDebugMode) {
        print('SocketService: trip:updated - $data');
      }
      _dispatchPayload(_tripUpdatedListeners, data);
    });

    // Trip events
    _socket!.on('trip:created', (data) {
      if (kDebugMode) {
        print('SocketService: trip:created - $data');
      }
      _dispatchPayload(_tripCreatedListeners, data);
    });

    _socket!.on('trip:created:from-booking', (data) {
      if (kDebugMode) {
        print('SocketService: trip:created:from-booking - $data');
      }
      _dispatchPayload(_tripCreatedFromBookingListeners, data);
    });

    _socket!.on('trip:customer:assigned', (data) {
      if (kDebugMode) {
        print('SocketService: trip:customer:assigned - $data');
      }
      _dispatchPayload(_tripCustomerAssignedListeners, data);
    });

    _socket!.on('trip:started', (data) {
      if (kDebugMode) {
        print('SocketService: trip:started - $data');
      }
      _dispatchPayload(_tripStartedListeners, data);
    });

    _socket!.on('trip:milestone:updated', (data) {
      if (kDebugMode) {
        print('SocketService: trip:milestone:updated - $data');
      }
      _dispatchPayload(_tripMilestoneUpdatedListeners, data);
    });

    _socket!.on('trip:completed', (data) {
      if (kDebugMode) {
        print('SocketService: trip:completed - $data');
      }
      _dispatchPayload(_tripCompletedListeners, data);
    });

    _socket!.on('trip:pod:pending', (data) {
      if (kDebugMode) {
        print('SocketService: trip:pod:pending - $data');
      }
      _dispatchPayload(_tripPodPendingListeners, data);
    });

    _socket!.on('trip:auto-activated', (data) {
      if (kDebugMode) {
        print('SocketService: trip:auto-activated - $data');
      }
      _dispatchPayload(_tripAutoActivatedListeners, data);
    });

    _socket!.on('vehicle:status:updated', (data) {
      if (kDebugMode) {
        print('SocketService: vehicle:status:updated - $data');
      }
      _dispatchPayload(_vehicleStatusUpdatedListeners, data);
    });

    // POD events (backend emits trip:pod:uploaded, trip:closed:with-pod)
    _socket!.on('trip:pod:uploaded', (data) {
      if (kDebugMode) {
        print('SocketService: trip:pod:uploaded - $data');
      }
      _dispatchPayload(_podUploadedListeners, data);
    });

    _socket!.on('trip:closed:with-pod', (data) {
      if (kDebugMode) {
        print('SocketService: trip:closed:with-pod - $data');
      }
      _dispatchPayload(_podApprovedListeners, data);
    });

    _socket!.on('trip:closed:without-pod', (data) {
      if (kDebugMode) {
        print('SocketService: trip:closed:without-pod - $data');
      }
      _dispatchPayload(_tripClosedWithoutPodListeners, data);
    });

    _socket!.on('trip:vehicle:assigned', (data) {
      if (kDebugMode) {
        print('SocketService: trip:vehicle:assigned - $data');
      }
      _dispatchPayload(_tripVehicleAssignedListeners, data);
    });

    _socket!.on('trip:driver:assigned', (data) {
      if (kDebugMode) {
        print('SocketService: trip:driver:assigned - $data');
      }
      _dispatchPayload(_tripDriverAssignedListeners, data);
    });

    _socket!.on('trip:customer:accepted', (data) {
      if (kDebugMode) {
        print('SocketService: trip:customer:accepted - $data');
      }
      _dispatchPayload(_tripCustomerAcceptedListeners, data);
    });

    _socket!.on('trip:customer:rejected', (data) {
      if (kDebugMode) {
        print('SocketService: trip:customer:rejected - $data');
      }
      _dispatchPayload(_tripCustomerRejectedListeners, data);
    });

    // Trip cancelled event
    _socket!.on('trip:cancelled', (data) {
      if (kDebugMode) {
        print('SocketService: trip:cancelled - $data');
      }
      _dispatchPayload(_tripCancelledListeners, data);
    });

    // Driver location update (real-time tracking)
    _socket!.on('driver:location:updated', (data) {
      if (kDebugMode) {
        print('SocketService: driver:location:updated - $data');
      }
      _dispatchPayload(_driverLocationUpdatedListeners, data);
    });

    // Driver tracking/presence status change (online, gps_off, offline,
    // logged_out, stale) so the transporter can surface connectivity issues.
    _socket!.on('driver:status:changed', (data) {
      if (kDebugMode) {
        print('SocketService: driver:status:changed - $data');
      }
      _dispatchPayload(_driverStatusChangedListeners, data);
    });

    // Error event (server: socket.emit('error', { code?, message }))
    _socket!.on('error', (data) {
      String? msg;
      String? code;
      if (data is Map) {
        if (data['message'] != null) {
          msg = data['message'].toString();
        }
        if (data['code'] != null) {
          code = data['code'].toString();
        }
      } else if (data is String) {
        msg = data;
      }
      if (kDebugMode) {
        if (code != null) {
          print('SocketService: error [$code] — ${msg ?? data}');
        } else {
          print('SocketService: error event — $data');
        }
      }
      if (msg != null && msg.isNotEmpty) {
        for (final listener in _marketplaceChatErrorListeners) {
          listener(msg);
        }
      }
    });

    void dispatchMarketplace(Map<String, dynamic> payload) {
      for (final listener in _marketplaceChatListeners) {
        listener(payload);
      }
    }

    _socket!.on('chat:message:new', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        dispatchMarketplace(m);
      }
    });

    _socket!.on('message:new', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        if (m.containsKey('bookingId')) {
          dispatchMarketplace(m);
        }
      }
    });

    _socket!.on('chat:message:read', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        m['_event'] = 'chat:message:read';
        dispatchMarketplace(m);
      }
    });

    _socket!.on('chat:typing', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        m['_event'] = 'chat:typing';
        dispatchMarketplace(m);
      }
    });

    _socket!.on('booking:price-proposed', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        m['_event'] = 'booking:price-proposed';
        dispatchMarketplace(m);
      }
    });

    _socket!.on('booking:requested', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        m['_event'] = 'booking:requested';
        dispatchMarketplace(m);
      }
    });

    _socket!.on('user:online', (data) {
      if (data is Map) {
        final id = data['userId']?.toString();
        if (id != null) onUserOnline?.call(id);
      }
    });

    _socket!.on('user:offline', (data) {
      if (data is Map) {
        final id = data['userId']?.toString();
        if (id != null) onUserOffline?.call(id);
      }
    });

    _socket!.on('chat:peer:presence', (data) {
      if (data is! Map) return;
      final m = Map<String, dynamic>.from(data);
      for (final listener in _chatPeerPresenceListeners) {
        listener(m);
      }
    });

    void dispatchSupport(Map<String, dynamic> payload) {
      for (final listener in _supportChatListeners) {
        listener(payload);
      }
    }

    _socket!.on('support:message:new', (data) {
      if (data is Map) {
        dispatchSupport(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('support:ticket:updated', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        m['_event'] = 'support:ticket:updated';
        dispatchSupport(m);
      }
    });

    _socket!.on('support:message:read', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        m['_event'] = 'support:message:read';
        dispatchSupport(m);
      }
    });

    _socket!.on('support:typing', (data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        m['_event'] = 'support:typing';
        dispatchSupport(m);
      }
    });

    void dispatchBookingLifecycle(String event, Map<dynamic, dynamic> raw) {
      final m = Map<String, dynamic>.from(raw);
      m['_event'] = event;
      for (final listener in _marketplaceBookingLifecycleListeners) {
        listener(m);
      }
    }

    _socket!.on('booking:rejected', (data) {
      if (data is Map) dispatchBookingLifecycle('booking:rejected', data);
    });
    _socket!.on('booking:cancelled', (data) {
      if (data is Map) dispatchBookingLifecycle('booking:cancelled', data);
    });
    _socket!.on('booking:confirmed', (data) {
      if (data is Map) dispatchBookingLifecycle('booking:confirmed', data);
    });
    _socket!.on('booking:completed', (data) {
      if (data is Map) dispatchBookingLifecycle('booking:completed', data);
    });

    _socket!.on('vehicle-type:request:updated', (data) {
      if (kDebugMode) {
        print('SocketService: vehicle-type:request:updated - $data');
      }
      _dispatchPayload(_vehicleTypeRequestUpdatedListeners, data);
    });
  }

  void addTripCreatedListener(void Function(Map<String, dynamic>) listener) {
    _tripCreatedListeners.add(listener);
  }

  void removeTripCreatedListener(void Function(Map<String, dynamic>) listener) {
    _tripCreatedListeners.remove(listener);
  }

  void addTripCreatedFromBookingListener(void Function(Map<String, dynamic>) listener) {
    _tripCreatedFromBookingListeners.add(listener);
  }

  void removeTripCreatedFromBookingListener(void Function(Map<String, dynamic>) listener) {
    _tripCreatedFromBookingListeners.remove(listener);
  }

  void addMarketplaceChatErrorListener(void Function(String message) listener) {
    _marketplaceChatErrorListeners.add(listener);
  }

  void removeMarketplaceChatErrorListener(void Function(String message) listener) {
    _marketplaceChatErrorListeners.remove(listener);
  }

  void addReconnectedListener(void Function() listener) {
    _reconnectedListeners.add(listener);
  }

  void removeReconnectedListener(void Function() listener) {
    _reconnectedListeners.remove(listener);
  }

  void addTripUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _tripUpdatedListeners.add(listener);
  }

  void removeTripUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _tripUpdatedListeners.remove(listener);
  }

  void addTripCustomerAssignedListener(void Function(Map<String, dynamic>) listener) {
    _tripCustomerAssignedListeners.add(listener);
  }

  void removeTripCustomerAssignedListener(void Function(Map<String, dynamic>) listener) {
    _tripCustomerAssignedListeners.remove(listener);
  }

  void addTripStartedListener(void Function(Map<String, dynamic>) listener) {
    _tripStartedListeners.add(listener);
  }

  void removeTripStartedListener(void Function(Map<String, dynamic>) listener) {
    _tripStartedListeners.remove(listener);
  }

  void addTripMilestoneUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _tripMilestoneUpdatedListeners.add(listener);
  }

  void removeTripMilestoneUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _tripMilestoneUpdatedListeners.remove(listener);
  }

  void addTripCompletedListener(void Function(Map<String, dynamic>) listener) {
    _tripCompletedListeners.add(listener);
  }

  void removeTripCompletedListener(void Function(Map<String, dynamic>) listener) {
    _tripCompletedListeners.remove(listener);
  }

  void addTripPodPendingListener(void Function(Map<String, dynamic>) listener) {
    _tripPodPendingListeners.add(listener);
  }

  void removeTripPodPendingListener(void Function(Map<String, dynamic>) listener) {
    _tripPodPendingListeners.remove(listener);
  }

  void addTripAutoActivatedListener(void Function(Map<String, dynamic>) listener) {
    _tripAutoActivatedListeners.add(listener);
  }

  void removeTripAutoActivatedListener(void Function(Map<String, dynamic>) listener) {
    _tripAutoActivatedListeners.remove(listener);
  }

  void addVehicleStatusUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _vehicleStatusUpdatedListeners.add(listener);
  }

  void removeVehicleStatusUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _vehicleStatusUpdatedListeners.remove(listener);
  }

  void addPODUploadedListener(void Function(Map<String, dynamic>) listener) {
    _podUploadedListeners.add(listener);
  }

  void removePODUploadedListener(void Function(Map<String, dynamic>) listener) {
    _podUploadedListeners.remove(listener);
  }

  void addPODApprovedListener(void Function(Map<String, dynamic>) listener) {
    _podApprovedListeners.add(listener);
  }

  void removePODApprovedListener(void Function(Map<String, dynamic>) listener) {
    _podApprovedListeners.remove(listener);
  }

  void addTripClosedWithoutPODListener(void Function(Map<String, dynamic>) listener) {
    _tripClosedWithoutPodListeners.add(listener);
  }

  void removeTripClosedWithoutPODListener(void Function(Map<String, dynamic>) listener) {
    _tripClosedWithoutPodListeners.remove(listener);
  }

  void addTripCancelledListener(void Function(Map<String, dynamic>) listener) {
    _tripCancelledListeners.add(listener);
  }

  void removeTripCancelledListener(void Function(Map<String, dynamic>) listener) {
    _tripCancelledListeners.remove(listener);
  }

  void addTripVehicleAssignedListener(void Function(Map<String, dynamic>) listener) {
    _tripVehicleAssignedListeners.add(listener);
  }

  void removeTripVehicleAssignedListener(void Function(Map<String, dynamic>) listener) {
    _tripVehicleAssignedListeners.remove(listener);
  }

  void addTripDriverAssignedListener(void Function(Map<String, dynamic>) listener) {
    _tripDriverAssignedListeners.add(listener);
  }

  void removeTripDriverAssignedListener(void Function(Map<String, dynamic>) listener) {
    _tripDriverAssignedListeners.remove(listener);
  }

  void addTripCustomerAcceptedListener(void Function(Map<String, dynamic>) listener) {
    _tripCustomerAcceptedListeners.add(listener);
  }

  void removeTripCustomerAcceptedListener(void Function(Map<String, dynamic>) listener) {
    _tripCustomerAcceptedListeners.remove(listener);
  }

  void addTripCustomerRejectedListener(void Function(Map<String, dynamic>) listener) {
    _tripCustomerRejectedListeners.add(listener);
  }

  void removeTripCustomerRejectedListener(void Function(Map<String, dynamic>) listener) {
    _tripCustomerRejectedListeners.remove(listener);
  }

  void addDriverLocationUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _driverLocationUpdatedListeners.add(listener);
  }

  void removeDriverLocationUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _driverLocationUpdatedListeners.remove(listener);
  }

  void addDriverStatusChangedListener(void Function(Map<String, dynamic>) listener) {
    _driverStatusChangedListeners.add(listener);
  }

  void removeDriverStatusChangedListener(void Function(Map<String, dynamic>) listener) {
    _driverStatusChangedListeners.remove(listener);
  }

  void addVehicleTypeRequestListener(void Function(Map<String, dynamic>) listener) {
    _vehicleTypeRequestUpdatedListeners.add(listener);
  }

  void removeVehicleTypeRequestListener(void Function(Map<String, dynamic>) listener) {
    _vehicleTypeRequestUpdatedListeners.remove(listener);
  }

  void addMarketplaceChatListener(void Function(Map<String, dynamic>) listener) {
    _marketplaceChatListeners.add(listener);
  }

  void removeMarketplaceChatListener(void Function(Map<String, dynamic>) listener) {
    _marketplaceChatListeners.remove(listener);
  }

  void addChatPeerPresenceListener(void Function(Map<String, dynamic>) listener) {
    _chatPeerPresenceListeners.add(listener);
  }

  void removeChatPeerPresenceListener(void Function(Map<String, dynamic>) listener) {
    _chatPeerPresenceListeners.remove(listener);
  }

  void addMarketplaceBookingLifecycleListener(void Function(Map<String, dynamic>) listener) {
    _marketplaceBookingLifecycleListeners.add(listener);
  }

  void removeMarketplaceBookingLifecycleListener(void Function(Map<String, dynamic>) listener) {
    _marketplaceBookingLifecycleListeners.remove(listener);
  }

  void addSupportChatListener(void Function(Map<String, dynamic>) listener) {
    _supportChatListeners.add(listener);
  }

  void removeSupportChatListener(void Function(Map<String, dynamic>) listener) {
    _supportChatListeners.remove(listener);
  }

  void joinSupportTicket(String ticketId) {
    _joinedSupportTicketIds.add(ticketId);
    if (_socket == null) {
      connect();
      return;
    }
    if (_isConnected) {
      _socket!.emit('support:join', {'ticketId': ticketId});
    } else {
      connect();
    }
  }

  void leaveSupportTicket(String ticketId) {
    _joinedSupportTicketIds.remove(ticketId);
    if (_socket != null && _isConnected) {
      _socket!.emit('support:leave', {'ticketId': ticketId});
    }
  }

  bool sendSupportMessage(
    String ticketId,
    String content, {
    List<Map<String, dynamic>>? attachments,
  }) {
    if (_socket == null || !_isConnected) return false;
    final payload = <String, dynamic>{
      'ticketId': ticketId,
      'content': content,
      if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
    };
    _socket!.emit('support:message:send', payload);
    return true;
  }

  void emitSupportTyping(String ticketId) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('support:typing', {'ticketId': ticketId});
  }

  void markSupportMessageRead(String messageId) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('support:message:read', {'messageId': messageId});
  }

  /// Call when this device is viewing the marketplace chat thread (peer sees "Online").
  void emitChatThreadJoin(String bookingId) {
    _threadActiveBookingIds.add(bookingId);
    if (_socket == null) {
      connect();
      return;
    }
    if (_isConnected) {
      _socket!.emit('chat:thread:join', {'bookingId': bookingId});
    } else {
      connect();
    }
  }

  /// Call when leaving the chat UI (peer sees "Away").
  void emitChatThreadLeave(String bookingId) {
    _threadActiveBookingIds.remove(bookingId);
    if (_socket != null && _isConnected) {
      _socket!.emit('chat:thread:leave', {'bookingId': bookingId});
    }
  }

  void joinChatBooking(String bookingId) {
    _joinedBookingIds.add(bookingId);
    if (_socket == null) {
      connect();
      return;
    }
    if (_isConnected) {
      _socket!.emit('chat:join', {'bookingId': bookingId});
    } else {
      connect();
    }
  }

  void leaveChatBooking(String bookingId) {
    _joinedBookingIds.remove(bookingId);
    _threadActiveBookingIds.remove(bookingId);
    if (_socket != null && _isConnected) {
      _socket!.emit('chat:leave', {'bookingId': bookingId});
    }
  }

  /// Returns `true` if the packet was emitted (socket connected).
  bool sendChatMessage(
    String bookingId,
    String content, {
    String? messageType,
    num? proposedPrice,
    List<Map<String, dynamic>>? attachments,
  }) {
    if (_socket == null || !_isConnected) return false;
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'content': content,
      if (messageType != null) 'messageType': messageType,
      if (proposedPrice != null) 'proposedPrice': proposedPrice,
      if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
    };
    _socket!.emit('chat:message:send', payload);
    return true;
  }

  void emitChatTyping(String bookingId) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('chat:typing', {'bookingId': bookingId});
  }

  void markChatMessageRead(String messageId) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('chat:message:read', {'messageId': messageId});
  }

  void joinTransporterRoom(String transporterId) {
    _joinedTransporterId = transporterId;
    if (_socket == null) {
      connect();
      return;
    }
    if (_isConnected) {
      _socket!.emit('join:transporter', transporterId);
    } else {
      connect();
    }
  }

  void joinVehicleRoom(String vehicleId) {
    _joinedVehicleId = vehicleId;
    if (_socket == null) {
      connect();
      return;
    }
    if (_isConnected) {
      _socket!.emit('join:vehicle', vehicleId);
    } else {
      connect();
    }
  }

  void joinTripRoom(String tripId) {
    _joinedTripId = tripId;
    if (_socket == null) {
      connect();
      return;
    }
    if (_isConnected) {
      _socket!.emit('join:trip', tripId);
    } else {
      connect();
    }
  }

  /// Clears remembered rooms (call on logout). [disconnect] keeps them so reconnect can rejoin.
  void clearJoinedRooms() {
    _joinedTransporterId = null;
    _joinedTripId = null;
    _joinedVehicleId = null;
    _joinedBookingIds.clear();
    _threadActiveBookingIds.clear();
  }

  void disconnect() {
    for (final c in _pendingConnectCompleters) {
      if (!c.isCompleted) {
        c.completeError(StateError('Socket disconnected'));
      }
    }
    _pendingConnectCompleters.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void reconnect() {
    disconnect();
    connect();
  }
}

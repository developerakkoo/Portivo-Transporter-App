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

  final List<Completer<void>> _pendingConnectCompleters = [];

  // Event callbacks
  Function(Map<String, dynamic>)? onTripCreated;
  final List<void Function(Map<String, dynamic>)> _tripCreatedListeners = [];
  Function(Map<String, dynamic>)? onTripCustomerAssigned;
  Function(Map<String, dynamic>)? onTripStarted;
  Function(Map<String, dynamic>)? onTripMilestoneUpdated;
  Function(Map<String, dynamic>)? onTripCompleted;
  Function(Map<String, dynamic>)? onTripPodPending;
  Function(Map<String, dynamic>)? onTripAutoActivated;
  Function(Map<String, dynamic>)? onVehicleStatusUpdated;
  Function(Map<String, dynamic>)? onPODUploaded;
  Function(Map<String, dynamic>)? onPODApproved;
  Function(Map<String, dynamic>)? onTripClosedWithoutPOD;
  Function(Map<String, dynamic>)? onTripCancelled;
  Function(Map<String, dynamic>)? onTripVehicleAssigned;
  Function(Map<String, dynamic>)? onTripDriverAssigned;
  Function(Map<String, dynamic>)? onTripCustomerAccepted;
  Function(Map<String, dynamic>)? onTripCustomerRejected;
  Function(Map<String, dynamic>)? onDriverLocationUpdated;

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

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setPath(ApiConfig.socketPath)
            .setTransports(['polling', 'websocket'])
            .setAuth({'token': token})
            .setTimeout(45000)
            .setReconnectionAttempts(12)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(30000)
            .setRandomizationFactor(0.5)
            .enableReconnection()
            .enableAutoConnect()
            .build(),
      );

      _setupEventListeners();
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
      if (kDebugMode) {
        print('SocketService: Connected successfully');
      }
    });

    _socket!.on('reconnect', (_) {
      _isConnected = true;
      _rejoinRooms();
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

    // Trip events
    _socket!.on('trip:created', (data) {
      if (kDebugMode) {
        print('SocketService: trip:created - $data');
      }
      final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      onTripCreated?.call(payload);
      for (final listener in _tripCreatedListeners) {
        listener(payload);
      }
    });

    _socket!.on('trip:customer:assigned', (data) {
      if (kDebugMode) {
        print('SocketService: trip:customer:assigned - $data');
      }
      onTripCustomerAssigned?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:started', (data) {
      if (kDebugMode) {
        print('SocketService: trip:started - $data');
      }
      onTripStarted?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:milestone:updated', (data) {
      if (kDebugMode) {
        print('SocketService: trip:milestone:updated - $data');
      }
      onTripMilestoneUpdated?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:completed', (data) {
      if (kDebugMode) {
        print('SocketService: trip:completed - $data');
      }
      onTripCompleted?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:pod:pending', (data) {
      if (kDebugMode) {
        print('SocketService: trip:pod:pending - $data');
      }
      onTripPodPending?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:auto-activated', (data) {
      if (kDebugMode) {
        print('SocketService: trip:auto-activated - $data');
      }
      onTripAutoActivated?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('vehicle:status:updated', (data) {
      if (kDebugMode) {
        print('SocketService: vehicle:status:updated - $data');
      }
      onVehicleStatusUpdated?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    // POD events (backend emits trip:pod:uploaded, trip:closed:with-pod)
    _socket!.on('trip:pod:uploaded', (data) {
      if (kDebugMode) {
        print('SocketService: trip:pod:uploaded - $data');
      }
      onPODUploaded?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:closed:with-pod', (data) {
      if (kDebugMode) {
        print('SocketService: trip:closed:with-pod - $data');
      }
      onPODApproved?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:closed:without-pod', (data) {
      if (kDebugMode) {
        print('SocketService: trip:closed:without-pod - $data');
      }
      onTripClosedWithoutPOD?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:vehicle:assigned', (data) {
      if (kDebugMode) {
        print('SocketService: trip:vehicle:assigned - $data');
      }
      onTripVehicleAssigned?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:driver:assigned', (data) {
      if (kDebugMode) {
        print('SocketService: trip:driver:assigned - $data');
      }
      onTripDriverAssigned?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:customer:accepted', (data) {
      if (kDebugMode) {
        print('SocketService: trip:customer:accepted - $data');
      }
      onTripCustomerAccepted?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('trip:customer:rejected', (data) {
      if (kDebugMode) {
        print('SocketService: trip:customer:rejected - $data');
      }
      onTripCustomerRejected?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    // Trip cancelled event
    _socket!.on('trip:cancelled', (data) {
      if (kDebugMode) {
        print('SocketService: trip:cancelled - $data');
      }
      onTripCancelled?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    // Driver location update (real-time tracking)
    _socket!.on('driver:location:updated', (data) {
      if (kDebugMode) {
        print('SocketService: driver:location:updated - $data');
      }
      onDriverLocationUpdated?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    // Error event
    _socket!.on('error', (data) {
      if (kDebugMode) {
        print('SocketService: error event - $data');
      }
    });
  }

  void addTripCreatedListener(void Function(Map<String, dynamic>) listener) {
    _tripCreatedListeners.add(listener);
  }

  void removeTripCreatedListener(void Function(Map<String, dynamic>) listener) {
    _tripCreatedListeners.remove(listener);
  }

  void joinTransporterRoom(String transporterId) {
    _joinedTransporterId = transporterId;
    if (_socket == null) {
      connect();
      return;
    }
    if (_isConnected) {
      _socket!.emit('join:transporter', transporterId);
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
    }
  }

  /// Clears remembered rooms (call on logout). [disconnect] keeps them so reconnect can rejoin.
  void clearJoinedRooms() {
    _joinedTransporterId = null;
    _joinedTripId = null;
    _joinedVehicleId = null;
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

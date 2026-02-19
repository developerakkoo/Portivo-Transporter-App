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

  // Event callbacks
  Function(Map<String, dynamic>)? onTripCreated;
  Function(Map<String, dynamic>)? onTripStarted;
  Function(Map<String, dynamic>)? onTripMilestoneUpdated;
  Function(Map<String, dynamic>)? onTripCompleted;
  Function(Map<String, dynamic>)? onTripAutoActivated;
  Function(Map<String, dynamic>)? onVehicleStatusUpdated;
  Function(Map<String, dynamic>)? onPODUploaded;
  Function(Map<String, dynamic>)? onPODApproved;
  Function(Map<String, dynamic>)? onTripCancelled;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      if (kDebugMode) {
        print('SocketService: Already connected');
      }
      return; // Already connected
    }

    try {
      final token = await _storage.getAccessToken();
      if (token == null) {
        if (kDebugMode) {
          print('SocketService: No access token available - skipping connection');
        }
        return;
      }

      // Extract base URL from ApiConfig (remove /api suffix for Socket.IO)
      // baseUrl is 'https://api.port.porttivo.com/api', Socket.IO needs 'https://api.port.porttivo.com'
      final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
      
      if (kDebugMode) {
        print('SocketService: Connecting to Socket.IO server at $baseUrl');
        print('SocketService: API base URL is ${ApiConfig.baseUrl}');
      }

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .build(),
      );

      _setupEventListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('SocketService: Connection error: $e');
        print('Stack: $stackTrace');
      }
      // Don't throw - allow app to continue without Socket.IO
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      if (kDebugMode) {
        print('SocketService: Connected successfully');
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
      if (kDebugMode) {
        print('SocketService: Connection error: $error');
        // Handle timeout errors gracefully
        if (error.toString().contains('timeout')) {
          print('SocketService: Connection timeout - Socket.IO will retry automatically');
        }
      }
    });

    _socket!.onError((error) {
      if (kDebugMode) {
        print('SocketService: Error: $error');
        // Handle timeout errors gracefully
        if (error.toString().contains('timeout')) {
          print('SocketService: Socket.IO timeout - This is non-critical, connection will retry');
        }
      }
    });

    // Trip events
    _socket!.on('trip:created', (data) {
      if (kDebugMode) {
        print('SocketService: trip:created - $data');
      }
      onTripCreated?.call(data is Map ? Map<String, dynamic>.from(data) : {});
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

    // POD events
    _socket!.on('pod:uploaded', (data) {
      if (kDebugMode) {
        print('SocketService: pod:uploaded - $data');
      }
      onPODUploaded?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('pod:approved', (data) {
      if (kDebugMode) {
        print('SocketService: pod:approved - $data');
      }
      onPODApproved?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    // Trip cancelled event
    _socket!.on('trip:cancelled', (data) {
      if (kDebugMode) {
        print('SocketService: trip:cancelled - $data');
      }
      onTripCancelled?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    // Error event
    _socket!.on('error', (data) {
      if (kDebugMode) {
        print('SocketService: error event - $data');
      }
    });
  }

  void joinTransporterRoom(String transporterId) {
    _socket?.emit('join:transporter', transporterId);
  }

  void joinVehicleRoom(String vehicleId) {
    _socket?.emit('join:vehicle', vehicleId);
  }

  void joinTripRoom(String tripId) {
    _socket?.emit('join:trip', tripId);
  }

  void disconnect() {
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

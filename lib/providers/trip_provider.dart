import 'package:flutter/foundation.dart';
import '../data/models/trip_model.dart';
import '../services/trip_service.dart';
import '../services/socket_service.dart';
import '../core/constants/app_constants.dart';
import '../utils/error_utils.dart';

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();
  final SocketService _socketService = SocketService();

  List<TripModel> _trips = [];
  List<TripModel> _availableTrips = [];
  Map<String, List<TripModel>> _tripsByStatus = {};
  TripModel? _selectedTrip;
  bool _isLoading = false;
  String? _error;

  List<TripModel> get trips => _trips;
  List<TripModel> get availableTrips => _availableTrips;
  List<TripModel> get activeTrips => _tripsByStatus[AppConstants.tripStatusActive] ?? [];
  List<TripModel> get acceptedTrips => _tripsByStatus[AppConstants.tripStatusAccepted] ?? [];
  List<TripModel> get completedTrips => _tripsByStatus[AppConstants.tripStatusCompleted] ?? [];
  List<TripModel> get podPendingTrips => _tripsByStatus[AppConstants.tripStatusPodPending] ?? [];
  List<TripModel> get plannedTrips => _tripsByStatus[AppConstants.tripStatusPlanned] ?? [];
  /// Trips with status BOOKED from GET /api/trips (e.g. customer-booked awaiting acceptance)
  List<TripModel> get bookedTrips => _tripsByStatus[AppConstants.tripStatusBooked] ?? [];
  TripModel? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Single in-flight bootstrap so [HomeTab] and [TripsTab] do not double-fetch pages.
  Future<void>? _tripsBootstrapFuture;

  TripProvider() {
    _setupSocketListeners();
  }

  /// Runs [loadTrips] + [loadAvailableTrips] once per concurrent burst (shared [Future]).
  Future<void> bootstrapTripsIfNeeded() {
    return _tripsBootstrapFuture ??= _runTripsBootstrap();
  }

  Future<void> _runTripsBootstrap() async {
    try {
      await loadTrips(refresh: true);
      await loadAvailableTrips(refresh: true);
    } finally {
      _tripsBootstrapFuture = null;
    }
  }

  void _setupSocketListeners() {
    _socketService.onTripCreated = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:created');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _addTripToList(trip);
        if (trip.status == AppConstants.tripStatusBooked) {
          _addToAvailableTrips(trip);
        }
        notifyListeners();
      }
    };

    _socketService.onTripCustomerAssigned = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:customer:assigned');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _removeFromAvailableTrips(trip.id);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripStarted = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:started');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripMilestoneUpdated = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:milestone:updated');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripCompleted = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:completed');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripPodPending = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:pod:pending');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripAutoActivated = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:auto-activated');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _addTripToList(trip);
        notifyListeners();
      }
    };

    _socketService.onPODUploaded = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - pod:uploaded');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onPODApproved = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - pod:approved');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripClosedWithoutPOD = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:closed:without-pod');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripVehicleAssigned = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:vehicle:assigned');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripDriverAssigned = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:driver:assigned');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripCustomerAccepted = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:customer:accepted');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _removeFromAvailableTrips(trip.id);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripCustomerRejected = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:customer:rejected');
      }
      if (data['tripId'] != null) {
        _removeFromAvailableTrips(data['tripId'].toString());
        notifyListeners();
      } else if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _removeFromAvailableTrips(trip.id);
        _updateTripInList(trip);
        notifyListeners();
      }
    };

    _socketService.onTripCancelled = (data) {
      if (kDebugMode) {
        print('TripProvider: Socket event - trip:cancelled');
      }
      if (data['trip'] != null) {
        final trip = TripModel.fromJson(data['trip']);
        _removeFromAvailableTrips(trip.id);
        _updateTripInList(trip);
        notifyListeners();
      }
    };
  }

  void _addToAvailableTrips(TripModel trip) {
    final existingIndex = _availableTrips.indexWhere((t) => t.id == trip.id);
    if (existingIndex != -1) {
      _availableTrips[existingIndex] = trip;
    } else {
      _availableTrips.insert(0, trip);
    }
  }

  void _removeFromAvailableTrips(String tripId) {
    _availableTrips.removeWhere((t) => t.id == tripId);
  }

  void _addTripToList(TripModel trip) {
    // Check if trip already exists
    final existingIndex = _trips.indexWhere((t) => t.id == trip.id);
    if (existingIndex != -1) {
      // Update existing trip instead of adding duplicate
      if (kDebugMode) {
        print('TripProvider: Trip ${trip.id} already exists, updating it');
      }
      _trips[existingIndex] = trip;
    } else {
      // Add new trip at the beginning
      if (kDebugMode) {
        print('TripProvider: Adding new trip ${trip.id} with status ${trip.status}');
        print('TripProvider: Total trips before add: ${_trips.length}');
      }
      _trips.insert(0, trip);
      if (kDebugMode) {
        print('TripProvider: Total trips after add: ${_trips.length}');
      }
    }
    _updateTripsByStatus();
    if (kDebugMode) {
      print('TripProvider: Active trips: ${activeTrips.length}, Planned trips: ${plannedTrips.length}');
    }
  }

  void _updateTripInList(TripModel updatedTrip) {
    final index = _trips.indexWhere((t) => t.id == updatedTrip.id);
    if (index != -1) {
      final oldStatus = _trips[index].status;
      _trips[index] = updatedTrip;
      
      // If status changed, reorganize trips by status
      if (oldStatus != updatedTrip.status) {
        if (kDebugMode) {
          print('TripProvider: Trip ${updatedTrip.id} status changed from $oldStatus to ${updatedTrip.status}');
        }
        _updateTripsByStatus();
      } else {
        // Status didn't change, but still update the status map to reflect any other changes
        _updateTripsByStatus();
      }
    } else {
      // Trip not in list, add it
      if (kDebugMode) {
        print('TripProvider: Trip ${updatedTrip.id} not found in list, adding it');
      }
      _addTripToList(updatedTrip);
    }
  }

  void _updateTripsByStatus() {
    _tripsByStatus = {
      AppConstants.tripStatusBooked: _trips.where((t) => t.status == AppConstants.tripStatusBooked).toList(),
      AppConstants.tripStatusAccepted: _trips.where((t) => t.status == AppConstants.tripStatusAccepted).toList(),
      AppConstants.tripStatusPlanned: _trips.where((t) => t.status == AppConstants.tripStatusPlanned).toList(),
      AppConstants.tripStatusActive: _trips.where((t) => t.status == AppConstants.tripStatusActive).toList(),
      AppConstants.tripStatusCompleted: _trips.where((t) => AppConstants.tripStatusesCompleted.contains(t.status)).toList(),
      AppConstants.tripStatusPodPending: _trips.where((t) => t.status == AppConstants.tripStatusPodPending).toList(),
      AppConstants.tripStatusCancelled: _trips.where((t) => t.status == AppConstants.tripStatusCancelled).toList(),
    };
  }

  /// Loads all trips for this transporter from [TripService.getTrips] with multi-page fetch.
  ///
  /// Backend: [Porttivo-API/src/controllers/trip.controller.js] `getTrips` sorts by `createdAt` desc
  /// and paginates. Status lifecycle for execution is implemented in
  /// [Porttivo-API/src/controllers/tripStatus.controller.js] (`acceptTripByDriver`, `startTrip`, `completeTrip`).
  /// Customer booking vs transporter create: [Porttivo-API/src/controllers/trip.controller.js]
  /// (`createTrip`, customer book, `acceptCustomerTrip`, `finalizeAssignmentState`).
  Future<void> loadTrips({
    String? status,
    String? vehicleId,
    String? driverId,
    String? tripType,
    bool refresh = false,
  }) async {
    if (!refresh && _trips.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('TripProvider: Loading trips...');
      }
      
      final trips = await _tripService.getTrips(
        status: status,
        vehicleId: vehicleId,
        driverId: driverId,
        tripType: tripType,
        fetchAllPages: true,
      );

      if (refresh) {
        _trips = trips;
      } else {
        _trips.addAll(trips);
      }

      _updateTripsByStatus();
      
      if (kDebugMode) {
        print('TripProvider: Loaded ${trips.length} trips');
      }
    } catch (e, stackTrace) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading trips: $_error');
        print('Stack: $stackTrace');
      }
      // Return empty list instead of throwing
      if (refresh) {
        _trips = [];
        _updateTripsByStatus();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAvailableTrips({bool refresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trips = await _tripService.getAvailableCustomerTrips();
      if (refresh) {
        _availableTrips = trips;
      } else {
        for (final trip in trips) {
          _addToAvailableTrips(trip);
        }
      }
      if (kDebugMode) {
        print('TripProvider: Loaded ${trips.length} available trips');
      }
    } catch (e, stackTrace) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading available trips: $_error');
        print('Stack: $stackTrace');
      }
      if (refresh) {
        _availableTrips = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> acceptTrip(String tripId) async {
    try {
      final trip = await _tripService.acceptCustomerTrip(tripId);
      if (trip != null) {
        _removeFromAvailableTrips(tripId);
        await loadTrips(refresh: true);
        await loadAvailableTrips(refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('TripProvider: Error accepting trip: $e');
      }
      rethrow;
    }
  }

  Future<bool> rejectTrip(String tripId) async {
    try {
      final success = await _tripService.rejectCustomerTrip(tripId);
      if (success) {
        _removeFromAvailableTrips(tripId);
        await loadAvailableTrips(refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('TripProvider: Error rejecting trip: $e');
      }
      rethrow;
    }
  }

  Future<void> loadTripsByStatus(String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trips = await _tripService.getTripsByStatus(status);
      _tripsByStatus[status] = trips;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading trips by status: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns trip from _trips if present (fresher from socket), for real-time updates.
  TripModel? getTripForDetail(String id) {
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// [silent] avoids toggling global loading (trip detail uses its own spinner).
  Future<TripModel?> getTripById(String id, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final trip = await _tripService.getTripById(id);
      _selectedTrip = trip;
      if (trip != null) {
        _addTripToList(trip);
        _socketService.joinTripRoom(trip.id);
      }
      return trip;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading trip: $_error');
      }
      return null;
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<TripModel?> createTrip(Map<String, dynamic> tripData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.createTrip(tripData);
      if (trip != null) {
        _addTripToList(trip);
        _socketService.joinTripRoom(trip.id);
      }
      return trip;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error creating trip: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTrip(String id, Map<String, dynamic> tripData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.updateTrip(id, tripData);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error updating trip: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> assignVehicle(String tripId, String vehicleId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.assignVehicle(tripId, vehicleId);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error assigning vehicle: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> assignDriver(String tripId, String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.assignDriver(tripId, driverId);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error assigning driver: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelTrip(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _tripService.cancelTrip(id);
      if (success) {
        await loadTrips(refresh: true);
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error cancelling trip: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startTrip(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.startTrip(id);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error starting trip: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeTrip(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.completeTrip(id);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error completing trip: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> closeTripWithoutPOD(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.closeTripWithoutPOD(id);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error closing trip without POD: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<TripModel>> searchTrips(String query) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _tripService.searchTrips(query: query);
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error searching trips: $_error');
      }
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<TripModel>> getActiveTrips() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trips = await _tripService.getActiveTrips();
      _tripsByStatus[AppConstants.tripStatusActive] = trips;
      return trips;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading active trips: $_error');
      }
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getPendingPODTrips({
    int page = 1,
    int limit = 20,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _tripService.getPendingPODTrips(
        page: page,
        limit: limit,
      );
      if (result['trips'] != null) {
        final List<dynamic> tripsData = result['trips'];
        final trips = tripsData.map((json) => TripModel.fromJson(json)).toList();
        _tripsByStatus[AppConstants.tripStatusPodPending] = trips;
      }
      return result;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading pending POD trips: $_error');
      }
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadPOD(String tripId, String photoPath) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.uploadPOD(tripId, photoPath);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error uploading POD: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approvePOD(String tripId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _tripService.approvePOD(tripId);
      if (trip != null) {
        _updateTripInList(trip);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error approving POD: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> shareTrip(String tripId, {int expiryHours = 24}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _tripService.shareTrip(tripId, expiryHours: expiryHours);
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error sharing trip: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

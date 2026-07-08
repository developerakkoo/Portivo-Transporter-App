import 'package:flutter/foundation.dart';
import '../data/models/trip_model.dart';
import '../services/trip_service.dart';
import '../services/socket_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/json_parser.dart';
import '../utils/error_utils.dart';

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();
  final SocketService _socketService = SocketService();

  List<TripModel> _trips = [];
  List<TripModel> _availableTrips = [];
  List<TripModel> _draftTrips = [];
  Map<String, List<TripModel>> _tripsByStatus = {};
  TripModel? _selectedTrip;
  bool _isLoading = false;
  bool _isLoadingDrafts = false;
  String? _error;

  /// Latest driver tracking status per tripId (online, gps_off, offline,
  /// logged_out, stale) from `driver:status:changed`, for live card badges.
  final Map<String, String> _driverStatusByTrip = {};

  /// Driver tracking status for [tripId], or null if unknown.
  String? driverTrackingStatusFor(String tripId) => _driverStatusByTrip[tripId];

  List<TripModel> get trips => _trips;
  List<TripModel> get availableTrips => _availableTrips;
  List<TripModel> get draftTrips => _draftTrips;
  List<TripModel> get activeTrips => _tripsByStatus[AppConstants.tripStatusActive] ?? [];
  List<TripModel> get acceptedTrips => _tripsByStatus[AppConstants.tripStatusAccepted] ?? [];
  List<TripModel> get completedTrips => _tripsByStatus[AppConstants.tripStatusCompleted] ?? [];
  List<TripModel> get podPendingTrips => _tripsByStatus[AppConstants.tripStatusPodPending] ?? [];
  List<TripModel> get plannedTrips => _tripsByStatus[AppConstants.tripStatusPlanned] ?? [];
  List<TripModel> get cancelledTrips => _tripsByStatus[AppConstants.tripStatusCancelled] ?? [];
  /// Trips with status BOOKED from GET /api/trips (e.g. customer-booked awaiting acceptance)
  List<TripModel> get bookedTrips => _tripsByStatus[AppConstants.tripStatusBooked] ?? [];
  TripModel? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  bool get isLoadingDrafts => _isLoadingDrafts;
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
      await loadTripsByStatus(AppConstants.tripStatusCancelled);
      await loadAvailableTrips(refresh: true);
    } finally {
      _tripsBootstrapFuture = null;
    }
  }

  void _onSocketReconnected() {
    loadTrips(refresh: true);
  }

  void _setupSocketListeners() {
    _socketService.addReconnectedListener(_onSocketReconnected);
    _socketService.addTripCreatedListener(_onSocketTripCreated);
    _socketService.addTripCreatedFromBookingListener(_onSocketTripCreatedFromBooking);
    _socketService.addTripCustomerAssignedListener(_onSocketTripCustomerAssigned);
    _socketService.addTripStartedListener(_onSocketTripStarted);
    _socketService.addTripMilestoneUpdatedListener(_onSocketTripMilestoneUpdated);
    _socketService.addTripCompletedListener(_onSocketTripCompleted);
    _socketService.addTripPodPendingListener(_onSocketTripPodPending);
    _socketService.addTripAutoActivatedListener(_onSocketTripAutoActivated);
    _socketService.addPODUploadedListener(_onSocketPODUploaded);
    _socketService.addPODApprovedListener(_onSocketPODApproved);
    _socketService.addTripClosedWithoutPODListener(_onSocketTripClosedWithoutPOD);
    _socketService.addTripVehicleAssignedListener(_onSocketTripVehicleAssigned);
    _socketService.addTripDriverAssignedListener(_onSocketTripDriverAssigned);
    _socketService.addTripCustomerAcceptedListener(_onSocketTripCustomerAccepted);
    _socketService.addTripCustomerRejectedListener(_onSocketTripCustomerRejected);
    _socketService.addTripCancelledListener(_onSocketTripCancelled);
    _socketService.addTripUpdatedListener(_onSocketTripUpdated);
    _socketService.addDriverStatusChangedListener(_onSocketDriverStatusChanged);
    _socketService.addDriverLocationUpdatedListener(_onSocketDriverLocationUpdated);
  }

  void _onSocketDriverStatusChanged(Map<String, dynamic> data) {
    final tripId = data['tripId']?.toString();
    final status = data['status']?.toString();
    if (tripId == null || status == null) return;
    if (_driverStatusByTrip[tripId] == status) return;
    _driverStatusByTrip[tripId] = status;
    notifyListeners();
  }

  void _onSocketDriverLocationUpdated(Map<String, dynamic> data) {
    final tripId = data['tripId']?.toString();
    if (tripId == null) return;
    // A live fix implies the driver is online; refresh the badge.
    if (_driverStatusByTrip[tripId] != 'online') {
      _driverStatusByTrip[tripId] = 'online';
      notifyListeners();
    }
  }

  void _onSocketTripCreated(Map<String, dynamic> data) {
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
  }

  void _onSocketTripCreatedFromBooking(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:created:from-booking');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _addTripToList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripCustomerAssigned(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:customer:assigned');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _removeFromAvailableTrips(trip.id);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripStarted(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:started');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripMilestoneUpdated(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:milestone:updated');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripCompleted(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:completed');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripPodPending(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:pod:pending');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripAutoActivated(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:auto-activated');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _addTripToList(trip);
      notifyListeners();
    }
  }

  void _onSocketPODUploaded(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - pod:uploaded');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketPODApproved(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - pod:approved');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripClosedWithoutPOD(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:closed:without-pod');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripVehicleAssigned(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:vehicle:assigned');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripDriverAssigned(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:driver:assigned');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripCustomerAccepted(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:customer:accepted');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _removeFromAvailableTrips(trip.id);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripCustomerRejected(Map<String, dynamic> data) {
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
  }

  void _onSocketTripCancelled(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:cancelled');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _removeFromAvailableTrips(trip.id);
      _updateTripInList(trip);
      notifyListeners();
    }
  }

  void _onSocketTripUpdated(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('TripProvider: Socket event - trip:updated');
    }
    if (data['trip'] != null) {
      final trip = TripModel.fromJson(data['trip']);
      _updateTripInList(trip);
      if (_selectedTrip?.id == trip.id) {
        _selectedTrip = trip;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socketService.removeReconnectedListener(_onSocketReconnected);
    _socketService.removeTripCreatedListener(_onSocketTripCreated);
    _socketService.removeTripCreatedFromBookingListener(_onSocketTripCreatedFromBooking);
    _socketService.removeTripCustomerAssignedListener(_onSocketTripCustomerAssigned);
    _socketService.removeTripStartedListener(_onSocketTripStarted);
    _socketService.removeTripMilestoneUpdatedListener(_onSocketTripMilestoneUpdated);
    _socketService.removeTripCompletedListener(_onSocketTripCompleted);
    _socketService.removeTripPodPendingListener(_onSocketTripPodPending);
    _socketService.removeTripAutoActivatedListener(_onSocketTripAutoActivated);
    _socketService.removePODUploadedListener(_onSocketPODUploaded);
    _socketService.removePODApprovedListener(_onSocketPODApproved);
    _socketService.removeTripClosedWithoutPODListener(_onSocketTripClosedWithoutPOD);
    _socketService.removeTripVehicleAssignedListener(_onSocketTripVehicleAssigned);
    _socketService.removeTripDriverAssignedListener(_onSocketTripDriverAssigned);
    _socketService.removeTripCustomerAcceptedListener(_onSocketTripCustomerAccepted);
    _socketService.removeTripCustomerRejectedListener(_onSocketTripCustomerRejected);
    _socketService.removeTripCancelledListener(_onSocketTripCancelled);
    _socketService.removeTripUpdatedListener(_onSocketTripUpdated);
    super.dispose();
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
      final prev = _trips[index];
      final merged = (updatedTrip.marketplaceRole == null && updatedTrip.capabilities == null)
          ? updatedTrip.copyWith(
              marketplaceRole: prev.marketplaceRole,
              capabilities: prev.capabilities,
            )
          : updatedTrip;
      final sameDriver =
          JsonParser.extractId(updatedTrip.driverId) ==
          JsonParser.extractId(prev.driverId);
      final withPreservedDriver = merged.copyWith(
        driverMobile: merged.driverMobile ??
            (sameDriver ? prev.driverMobile : null),
      );
      final withBookingFlag = (!withPreservedDriver.isFromBooking && prev.isFromBooking)
          ? withPreservedDriver.copyWith(isFromBooking: true)
          : withPreservedDriver;
      final oldStatus = prev.status;
      _trips[index] = withBookingFlag;
      if (_selectedTrip?.id == withBookingFlag.id) {
        _selectedTrip = withBookingFlag;
      }

      // If status changed, reorganize trips by status
      if (oldStatus != withBookingFlag.status) {
        if (kDebugMode) {
          print('TripProvider: Trip ${withBookingFlag.id} status changed from $oldStatus to ${withBookingFlag.status}');
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
        _socketService.joinTripRoom(trip.id);
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
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
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error sharing trip: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDrafts({bool refresh = false}) async {
    if (_isLoadingDrafts && !refresh) return;

    _isLoadingDrafts = true;
    _error = null;
    notifyListeners();

    try {
      _draftTrips = await _tripService.listTripDrafts();
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading drafts: $_error');
      }
    } finally {
      _isLoadingDrafts = false;
      notifyListeners();
    }
  }

  Future<TripModel?> saveDraft(Map<String, dynamic> draftData, {String? draftId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = Map<String, dynamic>.from(draftData);
      if (draftId != null && draftId.isNotEmpty) {
        payload['draftId'] = draftId;
      }
      final saved = await _tripService.saveTripDraft(payload);
      if (saved != null) {
        final index = _draftTrips.indexWhere((draft) => draft.id == saved.id);
        if (index >= 0) {
          _draftTrips[index] = saved;
        } else {
          _draftTrips.insert(0, saved);
        }
      }
      return saved;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error saving draft: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TripModel?> loadDraft(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _tripService.getTripDraft(id);
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error loading draft: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDraft(String id) async {
    _error = null;
    notifyListeners();

    try {
      final success = await _tripService.deleteTripDraft(id);
      if (success) {
        _draftTrips.removeWhere((draft) => draft.id == id);
        notifyListeners();
        return true;
      }
      _error = 'Failed to delete draft';
      notifyListeners();
      return false;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('TripProvider: Error deleting draft: $_error');
      }
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

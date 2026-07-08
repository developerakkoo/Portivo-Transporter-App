import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/trail_points.dart';
import '../data/models/trip_model.dart';
import '../models/trip_map_live_data.dart';
import 'socket_service.dart';
import 'trip_location_trail_service.dart';
import 'trip_route_service.dart';

/// Driver presence/tracking status as reported by the API `driver:status:changed`
/// event (or inferred locally when updates go stale).
enum DriverTrackingStatus { unknown, online, gpsOff, offline, loggedOut, stale }

DriverTrackingStatus driverTrackingStatusFromString(String? raw) {
  switch (raw) {
    case 'online':
      return DriverTrackingStatus.online;
    case 'gps_off':
      return DriverTrackingStatus.gpsOff;
    case 'offline':
      return DriverTrackingStatus.offline;
    case 'logged_out':
      return DriverTrackingStatus.loggedOut;
    case 'stale':
      return DriverTrackingStatus.stale;
    default:
      return DriverTrackingStatus.unknown;
  }
}

/// Shared live-tracking state for trip detail and dev sandbox.
class LiveTrackingController extends ChangeNotifier {
  LiveTrackingController({
    TripRouteService? routeService,
    TripLocationTrailService? trailService,
  })  : _routeService = routeService ?? TripRouteService(),
        _trailService = trailService ?? TripLocationTrailService();

  final TripRouteService _routeService;
  final TripLocationTrailService _trailService;

  final ValueNotifier<TripMapLiveData> liveMap =
      ValueNotifier(const TripMapLiveData());

  LatLng? pickup;
  LatLng? waypoint;
  LatLng? drop;
  LatLng? driverLocation;
  double? driverHeading;
  final List<LatLng> driverTrail = [];
  List<LatLng> routePolyline = [];
  bool trailLoaded = false;
  String? tripId;

  String directionsStatus = '—';
  String? directionsDetail;
  String roadsStatus = '—';
  String? etaText;
  String? distanceText;

  /// Timestamp of the most recent live GPS fix received (for "updated Xs ago").
  DateTime? lastLocationAt;

  /// Driver presence/tracking status (from `driver:status:changed`).
  DriverTrackingStatus driverStatus = DriverTrackingStatus.unknown;
  String? driverStatusReason;
  DateTime? driverStatusAt;

  /// Live ETA / route-progress. Prefer server-computed values when present in
  /// the location payload; otherwise estimated locally from the route polyline.
  int? etaSeconds;
  double? distanceRemainingMeters;
  double? routeProgress; // 0..1
  double? _lastSpeedMps;

  /// Server-computed movement stage (preferred over the local milestone guess).
  String? movementStage;

  static const LatLng defaultPickup = LatLng(19.0760, 72.8777);
  static const LatLng defaultDrop = LatLng(19.2183, 72.9781);

  void setEndpoints(LatLng pick, LatLng dropPt) {
    pickup = pick;
    drop = dropPt;
    syncLiveMap();
    notifyListeners();
  }

  void useDefaultEndpoints() {
    setEndpoints(defaultPickup, defaultDrop);
  }

  void resetTracking({bool clearRoute = false}) {
    driverLocation = null;
    driverHeading = null;
    driverTrail.clear();
    trailLoaded = false;
    lastLocationAt = null;
    etaSeconds = null;
    distanceRemainingMeters = null;
    routeProgress = null;
    _lastSpeedMps = null;
    if (clearRoute) {
      routePolyline = [];
      directionsStatus = '—';
      directionsDetail = null;
    }
    syncLiveMap();
    notifyListeners();
  }

  void resetForTrip(String id, SocketService socket) {
    tripId = id;
    driverLocation = null;
    driverHeading = null;
    driverTrail.clear();
    routePolyline = [];
    trailLoaded = false;
    lastLocationAt = null;
    etaSeconds = null;
    distanceRemainingMeters = null;
    routeProgress = null;
    _lastSpeedMps = null;
    driverStatus = DriverTrackingStatus.unknown;
    driverStatusReason = null;
    driverStatusAt = null;
    movementStage = null;
    socket.joinTripRoom(id);
    syncLiveMap();
    notifyListeners();
  }

  void applyDriverUpdate(
    LatLng next, {
    double? heading,
    double? speedMps,
    DateTime? at,
  }) {
    driverLocation = next;
    if (heading != null && heading >= 0) {
      driverHeading = heading;
    }
    if (speedMps != null && speedMps >= 0) {
      _lastSpeedMps = speedMps;
    }
    lastLocationAt = at ?? DateTime.now();
    // A live fix implies the driver is online; refine if a status event says otherwise.
    if (driverStatus == DriverTrackingStatus.unknown ||
        driverStatus == DriverTrackingStatus.stale ||
        driverStatus == DriverTrackingStatus.offline) {
      driverStatus = DriverTrackingStatus.online;
    }
    appendTrailPoint(driverTrail, next);
    trimTrailInPlace(driverTrail);
    _recomputeEtaProgress();
    syncLiveMap();
    notifyListeners();
  }

  /// Update driver presence from a `driver:status:changed` socket payload.
  bool handleDriverStatusSocket(Map<String, dynamic> data) {
    final id = tripId;
    if (id == null) return false;
    if (!_matchesTripSocketPayload(data, id)) return false;
    final tracking = data['driverTracking'];
    String? statusRaw;
    String? reason;
    if (tracking is Map) {
      statusRaw = tracking['status']?.toString();
      reason = tracking['reason']?.toString();
    }
    statusRaw ??= data['status']?.toString();
    reason ??= data['reason']?.toString();
    driverStatus = driverTrackingStatusFromString(statusRaw);
    driverStatusReason = reason;
    driverStatusAt = DateTime.now();
    notifyListeners();
    return true;
  }

  void setRoutePolyline(List<LatLng> pts, {required String status, String? detail}) {
    routePolyline = pts;
    directionsStatus = status;
    directionsDetail = detail;
    _recomputeEtaProgress();
    syncLiveMap();
    notifyListeners();
  }

  void setTrailFromPoints(List<LatLng> points) {
    driverTrail
      ..clear()
      ..addAll(points);
    if (driverTrail.isNotEmpty) {
      driverLocation = driverTrail.last;
    }
    trailLoaded = true;
    syncLiveMap();
    notifyListeners();
  }

  void setEtaDistance({String? eta, String? distance}) {
    etaText = eta;
    distanceText = distance;
    notifyListeners();
  }

  void setRoadsStatus(String status) {
    roadsStatus = status;
    notifyListeners();
  }

  Future<void> loadRoute() async {
    final pick = pickup;
    final waypointPt = waypoint;
    final dropPt = drop;
    if (pick == null || dropPt == null) return;

    final RouteFetchResult result;
    if (waypointPt != null) {
      result = await _routeService.getMultiStopRouteDetailed(
        pick,
        waypointPt,
        dropPt,
      );
    } else {
      result = await _routeService.getPickupDropRouteDetailed(pick, dropPt);
    }
    setRoutePolyline(
      result.points,
      status: result.status,
      detail: result.message,
    );
  }

  Future<void> loadTrail(String id, String status) async {
    if (!_isTrackableStatus(status)) {
      trailLoaded = true;
      syncLiveMap();
      notifyListeners();
      return;
    }

    trailLoaded = false;
    syncLiveMap();
    notifyListeners();

    final points = await _trailService.fetchTrail(id);
    setTrailFromPoints(points);
  }

  bool handleDriverLocationSocket(Map<String, dynamic> data) {
    final id = tripId;
    if (id == null) return false;
    if (!_matchesTripSocketPayload(data, id)) return false;
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return false;

    final ts = data['timestamp'];
    DateTime? at;
    if (ts is String) {
      at = DateTime.tryParse(ts)?.toLocal();
    }

    applyDriverUpdate(
      LatLng(lat, lng),
      heading: (data['heading'] as num?)?.toDouble(),
      speedMps: (data['speed'] as num?)?.toDouble(),
      at: at,
    );

    // Prefer server-computed ETA / progress when the API provides them.
    final serverEta = (data['etaSeconds'] as num?)?.toInt();
    final serverRemaining = (data['distanceRemainingMeters'] as num?)?.toDouble();
    final serverProgress = (data['routeProgressPercent'] as num?)?.toDouble();
    var changed = false;
    if (serverEta != null) {
      etaSeconds = serverEta;
      changed = true;
    }
    if (serverRemaining != null) {
      distanceRemainingMeters = serverRemaining;
      changed = true;
    }
    if (serverProgress != null) {
      routeProgress = (serverProgress / 100).clamp(0.0, 1.0);
      changed = true;
    }
    final serverStage = data['movementStage']?.toString();
    if (serverStage != null && serverStage.isNotEmpty) {
      movementStage = serverStage;
      changed = true;
    }
    if (changed) notifyListeners();
    return true;
  }

  /// Estimate distance-remaining, route progress, and ETA from the planned
  /// route polyline + the latest driver fix. Interim until the API ships
  /// server-side ETA in the location payload.
  void _recomputeEtaProgress() {
    final driver = driverLocation;
    final route = routePolyline;
    if (driver == null || route.length < 2) {
      return;
    }

    final totalLen = _polylineLength(route);
    if (totalLen <= 0) return;

    // Nearest route vertex to the driver.
    var nearestIdx = 0;
    var nearestDist = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final d = _distanceMeters(driver, route[i]);
      if (d < nearestDist) {
        nearestDist = d;
        nearestIdx = i;
      }
    }

    // Remaining = driver→nearest vertex + remaining route segments to drop.
    var remaining = nearestDist;
    for (var i = nearestIdx; i < route.length - 1; i++) {
      remaining += _distanceMeters(route[i], route[i + 1]);
    }

    distanceRemainingMeters = remaining;
    routeProgress = ((totalLen - remaining) / totalLen).clamp(0.0, 1.0);

    // Speed: use the last reported GPS speed if it's a sensible driving speed,
    // otherwise assume ~30 km/h urban average.
    final speed = (_lastSpeedMps != null && _lastSpeedMps! > 1.5)
        ? _lastSpeedMps!
        : 8.33;
    etaSeconds = (remaining / speed).round();
  }

  static double _polylineLength(List<LatLng> pts) {
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += _distanceMeters(pts[i], pts[i + 1]);
    }
    return total;
  }

  /// Haversine distance in meters.
  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  /// Human-readable ETA, e.g. "12 min" or "1 h 5 min".
  String? get etaDisplay {
    final s = etaSeconds;
    if (s == null || s < 0) return null;
    if (s < 60) return '< 1 min';
    final minutes = (s / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// Human-readable remaining distance, e.g. "850 m" or "12.4 km".
  String? get distanceRemainingDisplay {
    final d = distanceRemainingMeters;
    if (d == null || d < 0) return null;
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  void seedDriverFromTrip(TripModel trip) {
    if (trip.status != AppConstants.tripStatusActive) return;
    final loc = trip.lastDriverLocation;
    if (loc == null) return;
    if (loc.latitude == 0 && loc.longitude == 0) return;
    driverLocation = LatLng(loc.latitude, loc.longitude);
    // Carry the server timestamp so "updated Xs ago" and staleness work, and so
    // ETA shows up immediately on the first milestone/trip update (without a
    // manual refresh).
    final updatedAt = loc.updatedAt;
    if (updatedAt != null &&
        (lastLocationAt == null || updatedAt.isAfter(lastLocationAt!))) {
      lastLocationAt = updatedAt;
    }
    // We have a real position; treat the driver as live unless a status event
    // (logout / GPS off / offline) or staleness says otherwise.
    if (driverStatus == DriverTrackingStatus.unknown) {
      driverStatus = DriverTrackingStatus.online;
    }
    _recomputeEtaProgress();
    syncLiveMap();
    notifyListeners();
  }

  void setPickupDropFromTrip(TripModel trip) {
    final p = trip.pickupLocation?.coordinates;
    final w = trip.intermediateLocation?.coordinates;
    final d = trip.dropLocation?.coordinates;
    if (p != null) pickup = LatLng(p.latitude, p.longitude);
    if (w != null) {
      waypoint = LatLng(w.latitude, w.longitude);
    } else {
      waypoint = null;
    }
    if (d != null) drop = LatLng(d.latitude, d.longitude);
    syncLiveMap();
    notifyListeners();
  }

  Future<void> loadRouteIfActive(TripModel trip) async {
    if (trip.status != AppConstants.tripStatusActive) {
      routePolyline = [];
      syncLiveMap();
      notifyListeners();
      return;
    }
    setPickupDropFromTrip(trip);
    await loadRoute();
  }

  void syncLiveMap() {
    liveMap.value = TripMapLiveData(
      pickup: pickup,
      waypoint: waypoint,
      drop: drop,
      driverTarget: driverLocation,
      trail: List.from(driverTrail),
      routePolyline: List.from(routePolyline),
      driverHeading: driverHeading,
      trailLoaded: trailLoaded,
    );
  }

  static bool _isTrackableStatus(String status) {
    return status == AppConstants.tripStatusActive ||
        status == AppConstants.tripStatusPodPending;
  }

  static bool _matchesTripSocketPayload(Map<String, dynamic> data, String id) {
    final direct = data['tripId']?.toString();
    if (direct != null && direct == id) return true;
    final t = data['trip'];
    if (t is Map) {
      final m = Map<String, dynamic>.from(t);
      final tid = m['_id']?.toString() ?? m['id']?.toString();
      if (tid != null && tid == id) return true;
    }
    return false;
  }

  @override
  void dispose() {
    liveMap.dispose();
    super.dispose();
  }
}

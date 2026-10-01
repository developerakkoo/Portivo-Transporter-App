import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants/route_colors.dart';
import '../core/utils/map_marker_bitmap.dart';
import '../data/models/trip_group.dart';
import '../data/models/trip_model.dart';
import 'socket_service.dart';
import 'trip_route_service.dart';

/// Per-vehicle live state rendered on the fleet map.
class FleetVehicle {
  FleetVehicle({
    required this.tripId,
    required this.routeIndex,
    required this.vehicleLabel,
    required this.category,
    this.position,
    this.heading = 0,
  });

  final String tripId;
  final int routeIndex;
  final String vehicleLabel;
  VehicleMovementCategory category;
  LatLng? position;

  /// Bearing (degrees, 0 = north) the truck marker is rotated to.
  double heading;

  Color get color => RouteColors.forIndex(routeIndex);
}

/// Pickup / intermediate / drop points for one route in the group.
class _RouteEndpoints {
  const _RouteEndpoints({this.pickup, this.waypoint, this.drop});
  final LatLng? pickup;
  final LatLng? waypoint;
  final LatLng? drop;
}

/// Drives the multi-vehicle fleet map for a trip group:
/// - seeds each vehicle marker from its trip's `lastDriverLocation` (or pickup),
/// - fetches one route polyline per distinct `routeIndex` (colored by route),
/// - subscribes to `driver:location:updated` and moves the matching vehicle's
///   marker by `tripId` in realtime,
/// - filters markers by a selected [VehicleMovementCategory].
///
/// Exposes [markers] and [polylines] as [ValueNotifier]s the map widget listens
/// to. The transporter room (which already receives every trip's updates) must
/// be joined by the caller; this controller only filters events to the group.
class FleetTrackingController {
  FleetTrackingController({
    required List<TripModel> trips,
    SocketService? socketService,
    TripRouteService? routeService,
  })  : _socket = socketService ?? SocketService(),
        _routeService = routeService ?? TripRouteService() {
    _seed(trips);
    _socket.addDriverLocationUpdatedListener(_onDriverLocationUpdated);
    _rebuildMarkers();
    _loadIcons(trips);
    buildRoutePolylines(trips);
  }

  final SocketService _socket;
  final TripRouteService _routeService;

  final Map<String, FleetVehicle> _vehicles = {};
  final Map<int, List<LatLng>> _routePolylines = {};
  final Map<int, _RouteEndpoints> _routeEndpoints = {};

  // Marker bitmaps (loaded async): pickup/drop shared, one truck per route color.
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropIcon;
  BitmapDescriptor? _waypointIcon;
  final Map<int, BitmapDescriptor> _truckIconByRoute = {};

  bool _disposed = false;

  VehicleMovementCategory? _filter;

  final ValueNotifier<Set<Marker>> markers = ValueNotifier<Set<Marker>>({});
  final ValueNotifier<Set<Polyline>> polylines =
      ValueNotifier<Set<Polyline>>({});

  VehicleMovementCategory? get filter => _filter;

  List<FleetVehicle> get vehicles => _vehicles.values.toList();

  void setFilter(VehicleMovementCategory? category) {
    if (_filter == category) return;
    _filter = category;
    _rebuildMarkers();
  }

  /// Re-seed when the group's trips change (e.g. new socket-created vehicle).
  void updateTrips(List<TripModel> trips) {
    _seed(trips);
    _rebuildMarkers();
    final missingIcons =
        trips.any((t) => !_truckIconByRoute.containsKey(t.routeIndex));
    if (missingIcons || _pickupIcon == null) {
      _loadIcons(trips);
    }
    if (_routePolylines.isEmpty) {
      buildRoutePolylines(trips);
    }
  }

  static LatLng? _latLngFrom(TripLocation? loc) {
    if (loc == null) return null;
    final lat = loc.coordinates.latitude;
    final lng = loc.coordinates.longitude;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  void _seed(List<TripModel> trips) {
    for (final trip in trips) {
      final label = (trip.vehicleNumber?.isNotEmpty == true)
          ? trip.vehicleNumber!
          : (trip.tripId.isNotEmpty ? trip.tripId : trip.id);

      // Prefer the last live fix; fall back to the route pickup so a "not
      // started" vehicle still shows at its origin.
      LatLng? position;
      final last = trip.lastDriverLocation;
      if (last != null && !(last.latitude == 0 && last.longitude == 0)) {
        position = LatLng(last.latitude, last.longitude);
      } else {
        position = _latLngFrom(trip.pickupLocation);
      }

      final existing = _vehicles[trip.id];
      _vehicles[trip.id] = FleetVehicle(
        tripId: trip.id,
        routeIndex: trip.routeIndex,
        vehicleLabel: label,
        category: movementCategoryForTrip(trip),
        // Keep a live position we may have already received over socket.
        position: existing?.position ?? position,
        heading: existing?.heading ?? 0,
      );

      _routeEndpoints.putIfAbsent(
        trip.routeIndex,
        () => _RouteEndpoints(
          pickup: _latLngFrom(trip.pickupLocation),
          waypoint: _latLngFrom(trip.intermediateLocation),
          drop: _latLngFrom(trip.dropLocation),
        ),
      );
    }
    // Drop vehicles no longer in the group.
    final ids = trips.map((t) => t.id).toSet();
    _vehicles.removeWhere((id, _) => !ids.contains(id));
  }

  /// Render the pickup/drop pins and a route-colored truck for each vehicle.
  Future<void> _loadIcons(List<TripModel> trips) async {
    try {
      final base = await MapMarkerBitmap.loadTripMarkers();
      _pickupIcon = base.pickup;
      _dropIcon = base.drop;
      _waypointIcon = await MapMarkerBitmap.fromIcon(
        Icons.adjust,
        const Color(0xFFEF6C00),
        logicalSize: 46,
      );

      final routeIndexes = trips.map((t) => t.routeIndex).toSet();
      for (final ri in routeIndexes) {
        _truckIconByRoute[ri] = await MapMarkerBitmap.fromIcon(
          Icons.local_shipping,
          RouteColors.forIndex(ri),
          logicalSize: 60,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('FleetTrackingController: icon load failed: $e');
      }
    }
    if (_disposed) return;
    _rebuildMarkers();
  }

  /// Build colored route polylines from a snapshot of the group's trips.
  Future<void> buildRoutePolylines(List<TripModel> trips) async {
    final byRoute = <int, TripModel>{};
    for (final t in trips) {
      byRoute.putIfAbsent(t.routeIndex, () => t);
    }

    for (final entry in byRoute.entries) {
      final routeIndex = entry.key;
      final trip = entry.value;
      final pickup = _latLngFrom(trip.pickupLocation);
      final waypoint = _latLngFrom(trip.intermediateLocation);
      final drop = _latLngFrom(trip.dropLocation);
      if (pickup == null || drop == null) continue;

      try {
        final result = waypoint != null
            ? await _routeService.getMultiStopRouteDetailed(
                pickup, waypoint, drop)
            : await _routeService.getPickupDropRouteDetailed(pickup, drop);
        if (result.points.length >= 2) {
          _routePolylines[routeIndex] = result.points;
        }
      } catch (e) {
        if (kDebugMode) {
          print('FleetTrackingController: route $routeIndex fetch failed: $e');
        }
      }
    }
    _rebuildPolylineSet();
  }

  void _rebuildPolylineSet() {
    final set = <Polyline>{};
    for (final entry in _routePolylines.entries) {
      set.add(
        Polyline(
          polylineId: PolylineId('route_${entry.key}'),
          points: entry.value,
          color: RouteColors.forIndex(entry.key),
          width: 4,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }
    polylines.value = set;
  }

  void _onDriverLocationUpdated(Map<String, dynamic> data) {
    final tripId = data['tripId']?.toString();
    if (tripId == null) return;
    final vehicle = _vehicles[tripId];
    if (vehicle == null) return; // event for a trip outside this group

    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat is num && lng is num) {
      final next = LatLng(lat.toDouble(), lng.toDouble());
      final prev = vehicle.position;
      final reported = data['heading'];
      if (reported is num && reported >= 0) {
        vehicle.heading = reported.toDouble() % 360;
      } else if (prev != null &&
          (prev.latitude != next.latitude ||
              prev.longitude != next.longitude)) {
        vehicle.heading = _bearingBetween(prev, next);
      }
      vehicle.position = next;
    }
    final stage = data['movementStage']?.toString();
    if (stage != null && stage.isNotEmpty) {
      final lower = stage.toLowerCase();
      if (lower.contains('loading') || lower.contains('unloading')) {
        vehicle.category = VehicleMovementCategory.loading;
      } else if (vehicle.category != VehicleMovementCategory.delivered) {
        vehicle.category = VehicleMovementCategory.inTransit;
      }
    }
    _rebuildMarkers();
  }

  bool _passesFilter(FleetVehicle v) => _filter == null || v.category == _filter;

  void _rebuildMarkers() {
    final set = <Marker>{};

    // Route context: pickup + drop (+ intermediate) pins per route.
    for (final entry in _routeEndpoints.entries) {
      final ri = entry.key;
      final ep = entry.value;
      if (ep.pickup != null) {
        set.add(
          Marker(
            markerId: MarkerId('pickup_$ri'),
            position: ep.pickup!,
            icon: _pickupIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Pickup'),
            zIndexInt: 0,
          ),
        );
      }
      if (ep.waypoint != null) {
        set.add(
          Marker(
            markerId: MarkerId('waypoint_$ri'),
            position: ep.waypoint!,
            icon: _waypointIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
            infoWindow: const InfoWindow(title: 'Stop'),
            zIndexInt: 0,
          ),
        );
      }
      if (ep.drop != null) {
        set.add(
          Marker(
            markerId: MarkerId('drop_$ri'),
            position: ep.drop!,
            icon: _dropIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Drop'),
            zIndexInt: 0,
          ),
        );
      }
    }

    // Live vehicles: route-colored truck, rotated to travel heading.
    for (final v in _vehicles.values) {
      final pos = v.position;
      if (pos == null) continue;
      if (!_passesFilter(v)) continue;
      set.add(
        Marker(
          markerId: MarkerId('vehicle_${v.tripId}'),
          position: pos,
          icon: _truckIconByRoute[v.routeIndex] ??
              BitmapDescriptor.defaultMarkerWithHue(_hueFor(v.color)),
          rotation: v.heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: InfoWindow(
            title: v.vehicleLabel,
            snippet: v.category.label,
          ),
          zIndexInt: 2,
        ),
      );
    }
    markers.value = set;
  }

  /// Google marker hue (0–360) approximating a route color.
  static double _hueFor(Color color) {
    final hsv = HSVColor.fromColor(color);
    return hsv.hue;
  }

  /// Initial bearing (degrees, 0 = north) from [a] to [b].
  static double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// All current vehicle positions + route endpoints + polyline points, for
  /// camera fitting.
  List<LatLng> get boundsPoints {
    final pts = <LatLng>[];
    for (final v in _vehicles.values) {
      if (v.position != null) pts.add(v.position!);
    }
    for (final ep in _routeEndpoints.values) {
      if (ep.pickup != null) pts.add(ep.pickup!);
      if (ep.waypoint != null) pts.add(ep.waypoint!);
      if (ep.drop != null) pts.add(ep.drop!);
    }
    for (final line in _routePolylines.values) {
      pts.addAll(line);
    }
    return pts;
  }

  void dispose() {
    _disposed = true;
    _socket.removeDriverLocationUpdatedListener(_onDriverLocationUpdated);
    markers.dispose();
    polylines.dispose();
  }
}

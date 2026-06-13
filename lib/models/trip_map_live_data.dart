import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Snapshot of live tracking data shared between trip detail and fullscreen map.
class TripMapLiveData {
  const TripMapLiveData({
    this.pickup,
    this.drop,
    this.driverTarget,
    this.trail = const [],
    this.routePolyline = const [],
    this.driverHeading,
    this.trailLoaded = false,
  });

  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? driverTarget;
  final List<LatLng> trail;
  final List<LatLng> routePolyline;
  final double? driverHeading;
  final bool trailLoaded;

  TripMapLiveData copyWith({
    LatLng? pickup,
    LatLng? drop,
    LatLng? driverTarget,
    List<LatLng>? trail,
    List<LatLng>? routePolyline,
    double? driverHeading,
    bool? trailLoaded,
  }) {
    return TripMapLiveData(
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      driverTarget: driverTarget ?? this.driverTarget,
      trail: trail ?? this.trail,
      routePolyline: routePolyline ?? this.routePolyline,
      driverHeading: driverHeading ?? this.driverHeading,
      trailLoaded: trailLoaded ?? this.trailLoaded,
    );
  }
}

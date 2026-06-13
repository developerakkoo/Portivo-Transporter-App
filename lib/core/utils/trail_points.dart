import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Append [next] to [trail] if it is at least [minMeters] from the last point.
/// Returns true when a point was added.
bool appendTrailPoint(
  List<LatLng> trail,
  LatLng next, {
  double minMeters = 5,
}) {
  if (trail.isEmpty) {
    trail.add(next);
    return true;
  }
  final last = trail.last;
  final meters = Geolocator.distanceBetween(
    last.latitude,
    last.longitude,
    next.latitude,
    next.longitude,
  );
  if (meters < minMeters) return false;
  trail.add(next);
  return true;
}

/// Combine server history with in-memory live points without duplicating the join.
List<LatLng> mergeTrails(List<LatLng> historical, List<LatLng> live) {
  if (historical.isEmpty) return List<LatLng>.from(live);
  if (live.isEmpty) return List<LatLng>.from(historical);

  final merged = List<LatLng>.from(historical);
  var startIdx = 0;
  if (live.isNotEmpty) {
    final last = merged.last;
    final firstLive = live.first;
    final meters = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      firstLive.latitude,
      firstLive.longitude,
    );
    if (meters < 5) startIdx = 1;
  }
  merged.addAll(live.sublist(startIdx));
  return merged;
}

/// Cap polyline size for map performance (keeps first and last points).
List<LatLng> simplifyTrail(List<LatLng> points, {int maxPoints = 800}) {
  if (points.length <= maxPoints) return List<LatLng>.from(points);
  if (maxPoints < 2) return points.isEmpty ? [] : [points.last];

  final result = <LatLng>[];
  final step = (points.length - 1) / (maxPoints - 1);
  for (var i = 0; i < maxPoints; i++) {
    final idx = i == maxPoints - 1 ? points.length - 1 : (i * step).round();
    result.add(points[idx]);
  }
  return result;
}

/// Trim oldest points when trail exceeds [maxPoints] (in-place).
void trimTrailInPlace(List<LatLng> trail, {int maxPoints = 800}) {
  while (trail.length > maxPoints) {
    trail.removeAt(0);
  }
}

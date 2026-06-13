import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Moves a virtual driver along a polyline at a configurable speed (km/h).
class DriverRouteSimulator {
  DriverRouteSimulator({this.onTick});

  final void Function(LatLng position, double? heading)? onTick;

  Timer? _timer;
  List<LatLng> _route = [];
  double _segmentProgressM = 0;
  int _segmentIndex = 0;
  double _speedKmh = 40;

  bool get isRunning => _timer?.isActive ?? false;

  void start(List<LatLng> route, {double speedKmh = 40}) {
    if (route.length < 2) return;
    _route = List<LatLng>.from(route);
    _speedKmh = speedKmh.clamp(5, 200);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    pause();
    _segmentIndex = 0;
    _segmentProgressM = 0;
    if (_route.isNotEmpty) {
      onTick?.call(_route.first, _bearing(_route.first, _route.length > 1 ? _route[1] : _route.first));
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (_route.length < 2) return;
    if (_segmentIndex >= _route.length - 1) {
      pause();
      final last = _route.last;
      onTick?.call(last, _bearing(_route[_route.length - 2], last));
      return;
    }

    final stepM = (_speedKmh * 1000 / 3600) * 0.5; // 500 ms tick
    var remaining = stepM;

    while (remaining > 0 && _segmentIndex < _route.length - 1) {
      final a = _route[_segmentIndex];
      final b = _route[_segmentIndex + 1];
      final segLen = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      if (segLen < 0.5) {
        _segmentIndex++;
        _segmentProgressM = 0;
        continue;
      }
      final leftOnSeg = segLen - _segmentProgressM;
      if (remaining >= leftOnSeg) {
        remaining -= leftOnSeg;
        _segmentIndex++;
        _segmentProgressM = 0;
        if (_segmentIndex >= _route.length - 1) {
          onTick?.call(b, _bearing(a, b));
          pause();
          return;
        }
      } else {
        _segmentProgressM += remaining;
        remaining = 0;
        final t = (_segmentProgressM / segLen).clamp(0.0, 1.0);
        final lat = a.latitude + (b.latitude - a.latitude) * t;
        final lng = a.longitude + (b.longitude - a.longitude) * t;
        onTick?.call(LatLng(lat, lng), _bearing(a, b));
      }
    }
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}

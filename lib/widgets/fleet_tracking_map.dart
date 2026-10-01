import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/fleet_tracking_controller.dart';

/// Renders every vehicle in a trip group on one map: route-colored polylines
/// (one per route) + a marker per vehicle, driven by [FleetTrackingController].
class FleetTrackingMap extends StatefulWidget {
  const FleetTrackingMap({super.key, required this.controller});

  final FleetTrackingController controller;

  @override
  State<FleetTrackingMap> createState() => _FleetTrackingMapState();
}

class _FleetTrackingMapState extends State<FleetTrackingMap> {
  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);
  static const double _defaultZoom = 11.0;
  static const double _boundsPadding = 64;
  bool _didInitialFit = false;

  @override
  void initState() {
    super.initState();
    widget.controller.markers.addListener(_onMapDataChanged);
    widget.controller.polylines.addListener(_onMapDataChanged);
  }

  @override
  void dispose() {
    widget.controller.markers.removeListener(_onMapDataChanged);
    widget.controller.polylines.removeListener(_onMapDataChanged);
    _mapController = null;
    super.dispose();
  }

  void _onMapDataChanged() {
    if (!_didInitialFit && _mapController != null) {
      _fitBounds();
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  Future<void> _fitBounds() async {
    final controller = _mapController;
    if (controller == null) return;
    final points = widget.controller.boundsPoints;
    if (points.isEmpty) return;
    _didInitialFit = true;

    if (points.length == 1) {
      await controller
          .animateCamera(CameraUpdate.newLatLngZoom(points.first, 14));
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if ((maxLat - minLat).abs() < 1e-5 && (maxLng - minLng).abs() < 1e-5) {
      await controller
          .animateCamera(CameraUpdate.newLatLngZoom(points.first, 14));
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        _boundsPadding,
      ),
    );
  }

  LatLng _initialTarget() {
    final points = widget.controller.boundsPoints;
    return points.isNotEmpty ? points.first : _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<Polyline>>(
      valueListenable: widget.controller.polylines,
      builder: (context, polylines, _) {
        return ValueListenableBuilder<Set<Marker>>(
          valueListenable: widget.controller.markers,
          builder: (context, markers, __) {
            return Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _initialTarget(),
                    zoom: _defaultZoom,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: FloatingActionButton.small(
                    heroTag: 'fleet_fit',
                    onPressed: _fitBounds,
                    child: const Icon(Icons.center_focus_strong),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

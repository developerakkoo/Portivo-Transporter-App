import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme/app_colors.dart';

/// Trip tracking map showing pickup, drop, and driver location in real time.
class TripTrackingMap extends StatefulWidget {
  final LatLng? pickupLocation;
  final LatLng? dropLocation;
  final LatLng? driverLocation;
  final bool showDriverMarker;
  final double height;

  const TripTrackingMap({
    super.key,
    this.pickupLocation,
    this.dropLocation,
    this.driverLocation,
    this.showDriverMarker = true,
    this.height = 220,
  });

  @override
  State<TripTrackingMap> createState() => _TripTrackingMapState();
}

class _TripTrackingMapState extends State<TripTrackingMap> {
  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);
  static const double _defaultZoom = 12.0;
  static const double _boundsPadding = 64;

  /// When true, new driver positions trigger a smooth refit. User panning disables this.
  bool _followDriver = true;

  /// True while [animateCamera] is driving the map (ignore [onCameraMove] for follow logic).
  bool _programmaticCameraMove = false;

  @override
  void didUpdateWidget(covariant TripTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final driverChanged = widget.driverLocation != oldWidget.driverLocation &&
        widget.driverLocation != null;
    if (driverChanged && _followDriver && _mapController != null) {
      _animateToFitAllPoints();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    if (_programmaticCameraMove) return;
    if (_followDriver) {
      setState(() => _followDriver = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _animateToFitAllPoints();
  }

  List<LatLng> _collectPoints() {
    final points = <LatLng>[];
    if (widget.pickupLocation != null) points.add(widget.pickupLocation!);
    if (widget.dropLocation != null) points.add(widget.dropLocation!);
    if (widget.driverLocation != null) points.add(widget.driverLocation!);
    return points;
  }

  Future<void> _animateToFitAllPoints() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = _collectPoints();
    if (points.isEmpty) {
      _programmaticCameraMove = true;
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_defaultCenter, _defaultZoom),
        );
      } finally {
        _programmaticCameraMove = false;
      }
      return;
    }

    if (points.length == 1) {
      _programmaticCameraMove = true;
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15),
        );
      } finally {
        _programmaticCameraMove = false;
      }
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
      _programmaticCameraMove = true;
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15),
        );
      } finally {
        _programmaticCameraMove = false;
      }
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _programmaticCameraMove = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, _boundsPadding),
      );
    } finally {
      _programmaticCameraMove = false;
    }
  }

  void _onFollowDriverPressed() {
    setState(() => _followDriver = true);
    _animateToFitAllPoints();
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickupLocation!,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    if (widget.dropLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('drop'),
          position: widget.dropLocation!,
          infoWindow: const InfoWindow(title: 'Drop'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (widget.showDriverMarker && widget.driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: widget.driverLocation!,
          infoWindow: const InfoWindow(title: 'Driver'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  LatLng _initialPosition() {
    if (widget.driverLocation != null) return widget.driverLocation!;
    if (widget.pickupLocation != null) return widget.pickupLocation!;
    if (widget.dropLocation != null) return widget.dropLocation!;
    return _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    final showFollowChip =
        widget.driverLocation != null && !_followDriver;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            initialCameraPosition: CameraPosition(
              target: _initialPosition(),
              zoom: _defaultZoom,
            ),
            markers: _buildMarkers(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          if (showFollowChip)
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surface,
                child: InkWell(
                  onTap: _onFollowDriverPressed,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Follow driver',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

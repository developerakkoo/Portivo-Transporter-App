import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/map_marker_bitmap.dart';

/// Trip tracking map: pickup/drop/truck markers, route + trail polylines, optional driver interpolation.
class TripTrackingMap extends StatefulWidget {
  const TripTrackingMap({
    super.key,
    this.pickupLocation,
    this.dropLocation,
    this.driverLocation,
    this.driverHeading,
    this.driverTrailPoints = const [],
    this.routePolylinePoints = const [],
    this.trailLoaded = true,
    this.showDriverMarker = true,
    this.height = 220,
    this.fullScreen = false,
    this.onExpand,
  });

  final LatLng? pickupLocation;
  final LatLng? dropLocation;
  final LatLng? driverLocation;

  /// Driver bearing in degrees (0 = north). When null, bearing is derived from
  /// consecutive positions so the truck still rotates toward travel direction.
  final double? driverHeading;
  final List<LatLng> driverTrailPoints;
  final List<LatLng> routePolylinePoints;
  final bool trailLoaded;
  final bool showDriverMarker;

  /// When null, parent must wrap in [Expanded] or give bounded height.
  final double? height;
  final bool fullScreen;
  final VoidCallback? onExpand;

  @override
  State<TripTrackingMap> createState() => _TripTrackingMapState();
}

class _TripTrackingMapState extends State<TripTrackingMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);
  static const double _defaultZoom = 12.0;
  static const double _boundsPadding = 64;

  bool _followDriver = true;
  bool _programmaticCameraMove = false;

  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropIcon;
  BitmapDescriptor? _truckIcon;

  LatLng? _animatedDriver;
  AnimationController? _driverAnim;
  CurvedAnimation? _driverCurve;
  LatLng? _animFrom;
  LatLng? _animTo;

  /// Marker bearing (degrees) currently rendered + animation endpoints.
  double _animatedBearing = 0;
  double _fromBearing = 0;
  double _toBearing = 0;

  /// When the previous driver update arrived, used to size the next animation
  /// so the marker glides continuously across the ~5s gap (Uber-style) rather
  /// than snapping and waiting.
  DateTime? _lastDriverUpdateAt;
  static const Duration _minAnimDuration = Duration(milliseconds: 300);
  static const Duration _maxAnimDuration = Duration(milliseconds: 6000);
  static const Duration _fallbackAnimDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _animatedDriver = widget.driverLocation;
    if (widget.driverHeading != null && widget.driverHeading! >= 0) {
      _animatedBearing = widget.driverHeading!;
      _toBearing = widget.driverHeading!;
      _fromBearing = widget.driverHeading!;
    }
    _loadMarkerBitmaps();
  }

  Future<void> _loadMarkerBitmaps() async {
    try {
      final m = await MapMarkerBitmap.loadTripMarkers();
      if (mounted) {
        setState(() {
          _pickupIcon = m.pickup;
          _dropIcon = m.drop;
          _truckIcon = m.truck;
        });
      }
    } catch (_) {
      // Defaults used in _buildMarkers
    }
  }

  @override
  void didUpdateWidget(covariant TripTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDriver = widget.driverLocation;
    final oldDriver = oldWidget.driverLocation;
    if (newDriver != null &&
        (oldDriver == null ||
            (oldDriver.latitude != newDriver.latitude ||
                oldDriver.longitude != newDriver.longitude))) {
      // Animate from where the marker currently is (mid-flight) for continuity.
      final from = _animatedDriver ?? oldDriver ?? newDriver;
      _startDriverAnimation(from, newDriver);
    } else if (newDriver == null) {
      _animatedDriver = null;
      _driverCurve?.dispose();
      _driverCurve = null;
      _driverAnim?.dispose();
      _driverAnim = null;
      _lastDriverUpdateAt = null;
    }

    final driverChanged = newDriver != oldDriver && newDriver != null;
    if (driverChanged && _followDriver && _mapController != null) {
      _animateToFitAllPoints();
    }

    if (_polylineContentChanged(
          widget.routePolylinePoints,
          oldWidget.routePolylinePoints,
        ) ||
        _polylineContentChanged(
          widget.driverTrailPoints,
          oldWidget.driverTrailPoints,
        )) {
      if (_mapController != null) {
        _animateToFitAllPoints();
      }
    }
  }

  /// Detects meaningful polyline updates (not only list length changes).
  bool _polylineContentChanged(List<LatLng> next, List<LatLng> prev) {
    if (next.length != prev.length) return true;
    if (next.isEmpty) return false;
    final nFirst = next.first;
    final pFirst = prev.first;
    final nLast = next.last;
    final pLast = prev.last;
    return nFirst.latitude != pFirst.latitude ||
        nFirst.longitude != pFirst.longitude ||
        nLast.latitude != pLast.latitude ||
        nLast.longitude != pLast.longitude;
  }

  void _startDriverAnimation(LatLng? from, LatLng to) {
    _driverAnim?.dispose();
    _driverAnim = null;
    _driverCurve?.dispose();
    _driverCurve = null;

    // Size the animation to the real gap between updates so the marker keeps
    // moving smoothly until the next fix, instead of snapping then idling.
    final now = DateTime.now();
    Duration duration = _fallbackAnimDuration;
    if (_lastDriverUpdateAt != null) {
      final gap = now.difference(_lastDriverUpdateAt!);
      if (gap > _minAnimDuration) {
        duration = gap > _maxAnimDuration ? _maxAnimDuration : gap;
      } else {
        duration = _minAnimDuration;
      }
    }
    _lastDriverUpdateAt = now;

    if (from == null ||
        (from.latitude == to.latitude && from.longitude == to.longitude)) {
      setState(() {
        _animatedDriver = to;
        _applyTargetBearing(from, to);
        _animatedBearing = _toBearing;
        _fromBearing = _toBearing;
      });
      return;
    }

    _animFrom = from;
    _animTo = to;
    _fromBearing = _animatedBearing;
    _applyTargetBearing(from, to);

    _driverAnim = AnimationController(vsync: this, duration: duration);
    _driverCurve = CurvedAnimation(parent: _driverAnim!, curve: Curves.linear);
    _driverCurve!.addListener(() {
      if (_animFrom == null || _animTo == null) return;
      if (!mounted) return;
      final t = _driverCurve!.value;
      setState(() {
        _animatedDriver = _lerpLatLng(_animFrom!, _animTo!, t);
        _animatedBearing = _lerpAngle(_fromBearing, _toBearing, t);
      });
    });
    _driverCurve!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _animatedDriver = _animTo;
            _animatedBearing = _toBearing;
          });
        }
      }
    });
    _driverAnim!.forward();
  }

  /// Choose the bearing to rotate the truck toward: reported heading if valid,
  /// else the direction of travel from [from] to [to].
  void _applyTargetBearing(LatLng? from, LatLng to) {
    final heading = widget.driverHeading;
    if (heading != null && heading >= 0) {
      _toBearing = heading % 360;
      return;
    }
    if (from != null &&
        (from.latitude != to.latitude || from.longitude != to.longitude)) {
      _toBearing = _bearingBetween(from, to);
    }
  }

  static LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Shortest-path angular interpolation (handles 350°→10° wrap).
  static double _lerpAngle(double a, double b, double t) {
    var diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (a + diff * t) % 360;
  }

  static double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  @override
  void dispose() {
    _driverCurve?.dispose();
    _driverCurve = null;
    _driverAnim?.dispose();
    _mapController = null;
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

  List<LatLng> _collectBoundsPoints() {
    final points = <LatLng>[];
    if (widget.pickupLocation != null) points.add(widget.pickupLocation!);
    if (widget.dropLocation != null) points.add(widget.dropLocation!);
    final driver = _animatedDriver ?? widget.driverLocation;
    if (driver != null) points.add(driver);
    for (final p in widget.routePolylinePoints) {
      points.add(p);
    }
    for (final p in widget.driverTrailPoints) {
      points.add(p);
    }
    return points;
  }

  Future<void> _animateToFitAllPoints() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = _collectBoundsPoints();
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

  Set<Polyline> _buildPolylines() {
    final set = <Polyline>{};
    if (widget.routePolylinePoints.length >= 2) {
      final isFallbackSegment = widget.routePolylinePoints.length == 2;
      set.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: widget.routePolylinePoints,
          color: AppColors.primary,
          width: isFallbackSegment ? 5 : 4,
          zIndex: 0,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          patterns: isFallbackSegment
              ? const []
              : [
                  PatternItem.dash(18),
                  PatternItem.gap(10),
                ],
        ),
      );
    }
    if (widget.driverTrailPoints.length >= 2) {
      set.add(
        Polyline(
          polylineId: const PolylineId('trail'),
          points: widget.driverTrailPoints,
          color: AppColors.textSecondary,
          width: 5,
          zIndex: 1,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }
    return set;
  }

  bool get _showLegend =>
      widget.routePolylinePoints.length >= 2 ||
      widget.driverTrailPoints.length >= 2;

  Widget _buildLegendRow() {
    if (!_showLegend) return const SizedBox.shrink();
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          if (widget.routePolylinePoints.length >= 2)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Planned route', style: textStyle),
              ],
            ),
          if (widget.driverTrailPoints.length >= 2)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Driver path', style: textStyle),
              ],
            ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickupLocation!,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          zIndexInt: 1,
        ),
      );
    }

    if (widget.dropLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('drop'),
          position: widget.dropLocation!,
          infoWindow: const InfoWindow(title: 'Drop'),
          icon: _dropIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          zIndexInt: 1,
        ),
      );
    }

    final driverPos = _animatedDriver ?? widget.driverLocation;
    if (widget.showDriverMarker && driverPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          infoWindow: const InfoWindow(title: 'Driver'),
          icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          zIndexInt: 2,
          anchor: const Offset(0.5, 0.5),
          rotation: _animatedBearing,
          flat: true,
        ),
      );
    }

    return markers;
  }

  LatLng _initialPosition() {
    final d = _animatedDriver ?? widget.driverLocation;
    if (d != null) return d;
    if (widget.pickupLocation != null) return widget.pickupLocation!;
    if (widget.dropLocation != null) return widget.dropLocation!;
    return _defaultCenter;
  }

  Widget _buildMapStack() {
    final showFollowChip =
        (widget.driverLocation != null || _animatedDriver != null) && !_followDriver;

    return Stack(
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
          polylines: _buildPolylines(),
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
        if (widget.onExpand != null && !widget.fullScreen)
          Positioned(
            left: 10,
            top: 10,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
              child: InkWell(
                onTap: widget.onExpand,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_full,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Full screen',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!widget.trailLoaded)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.04),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapWithLegend() {
    if (widget.fullScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMapStack()),
          _buildLegendRow(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height ?? 220,
          child: _buildMapStack(),
        ),
        _buildLegendRow(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return SizedBox.expand(child: _buildMapWithLegend());
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildMapWithLegend(),
    );
  }
}

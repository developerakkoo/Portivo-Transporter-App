import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/distance_matrix_service.dart';
import '../../services/driver_route_simulator.dart';
import '../../services/live_tracking_controller.dart';
import '../../services/roads_snap_service.dart';
import '../../services/socket_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/trip_tracking_map.dart';

/// Dev-only live tracking QA screen (no login in simulate mode).
class LiveTrackingSandboxScreen extends StatefulWidget {
  const LiveTrackingSandboxScreen({super.key});

  @override
  State<LiveTrackingSandboxScreen> createState() =>
      _LiveTrackingSandboxScreenState();
}

class _LiveTrackingSandboxScreenState extends State<LiveTrackingSandboxScreen>
    with SingleTickerProviderStateMixin {
  final LiveTrackingController _tracking = LiveTrackingController();
  late final DriverRouteSimulator _simulator;
  final RoadsSnapService _roads = RoadsSnapService();
  final DistanceMatrixService _distanceMatrix = DistanceMatrixService();
  final SocketService _socket = SocketService();
  final StorageService _storage = StorageService();

  late final TabController _tabController;

  double _speedKmh = 40;
  bool _panelExpanded = true;
  int _roadsSnapCounter = 0;

  final _pickupLat = TextEditingController(text: '19.0760');
  final _pickupLng = TextEditingController(text: '72.8777');
  final _dropLat = TextEditingController(text: '19.2183');
  final _dropLng = TextEditingController(text: '72.9781');
  final _tripIdCtrl = TextEditingController();
  final _jwtCtrl = TextEditingController();

  String _socketStatus = 'disconnected';
  void Function(Map<String, dynamic>)? _socketListener;

  @override
  void initState() {
    super.initState();
    _simulator = DriverRouteSimulator(onTick: _onSimTick);
    _tabController = TabController(length: 2, vsync: this);
    _tracking.addListener(_onTrackingChanged);
    _tracking.useDefaultEndpoints();

    _socketListener = (data) {
      if (_tracking.handleDriverLocationSocket(data)) {
        unawaited(_refreshEta());
        if (_tracking.driverTrail.length % 5 == 0) {
          unawaited(_maybeSnapTrail());
        }
      }
    };
    _socket.addDriverLocationUpdatedListener(_socketListener!);
    _updateSocketStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapSimulate());
    });
  }

  void _onTrackingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrapSimulate() async {
    await _tracking.loadRoute();
    _simulator.reset();
    if (_tracking.routePolyline.length >= 2) {
      _tracking.applyDriverUpdate(_tracking.routePolyline.first);
    }
  }

  void _onSimTick(LatLng position, double? heading) {
    _tracking.applyDriverUpdate(position, heading: heading);
    _roadsSnapCounter++;
    if (_roadsSnapCounter % 5 == 0) {
      unawaited(_maybeSnapTrail());
    }
    unawaited(_refreshEta());
  }

  Future<void> _maybeSnapTrail() async {
    if (_tracking.driverTrail.length < 2) return;
    try {
      final snapped = await _roads.snapToRoads(_tracking.driverTrail);
      _tracking.setTrailFromPoints(snapped);
      _tracking.setRoadsStatus('OK (${snapped.length} pts)');
    } catch (e) {
      _tracking.setRoadsStatus('ERR: $e');
    }
  }

  Future<void> _refreshEta() async {
    final driver = _tracking.driverLocation;
    final drop = _tracking.drop;
    if (driver == null || drop == null) return;
    final r = await _distanceMatrix.getDrivingEta(driver, drop);
    _tracking.setEtaDistance(eta: r.durationText, distance: r.distanceText);
  }

  LatLng? _parseLatLng(TextEditingController lat, TextEditingController lng) {
    final la = double.tryParse(lat.text.trim());
    final lo = double.tryParse(lng.text.trim());
    if (la == null || lo == null) return null;
    return LatLng(la, lo);
  }

  Future<void> _applyEndpoints() async {
    final pick = _parseLatLng(_pickupLat, _pickupLng);
    final drop = _parseLatLng(_dropLat, _dropLng);
    if (pick == null || drop == null) {
      _showSnack('Invalid pickup or drop coordinates');
      return;
    }
    _simulator.pause();
    _tracking.resetTracking(clearRoute: true);
    _tracking.setEndpoints(pick, drop);
    await _tracking.loadRoute();
    _simulator.reset();
    if (_tracking.routePolyline.length >= 2) {
      _tracking.applyDriverUpdate(_tracking.routePolyline.first);
    }
  }

  void _useDefaults() {
    _pickupLat.text = LiveTrackingController.defaultPickup.latitude.toString();
    _pickupLng.text = LiveTrackingController.defaultPickup.longitude.toString();
    _dropLat.text = LiveTrackingController.defaultDrop.latitude.toString();
    _dropLng.text = LiveTrackingController.defaultDrop.longitude.toString();
    unawaited(_applyEndpoints());
  }

  void _startSim() {
    if (_tracking.routePolyline.length < 2) {
      _showSnack('Load a route first (Reload route)');
      return;
    }
    _simulator.start(_tracking.routePolyline, speedKmh: _speedKmh);
    setState(() {});
  }

  void _pauseSim() {
    _simulator.pause();
    setState(() {});
  }

  void _resetSim() {
    _simulator.pause();
    _tracking.resetTracking();
    _simulator.reset();
    if (_tracking.routePolyline.length >= 2) {
      _tracking.applyDriverUpdate(_tracking.routePolyline.first);
    }
    setState(() {});
  }

  Future<void> _connectLive() async {
    final tripId = _tripIdCtrl.text.trim();
    final jwt = _jwtCtrl.text.trim();
    if (tripId.isEmpty || jwt.isEmpty) {
      _showSnack('Trip ID and JWT are required for live mode');
      return;
    }

    await _storage.saveAccessToken(jwt);
    _simulator.pause();
    _tracking.resetForTrip(tripId, _socket);
    await _socket.connectUntilReady();
    _updateSocketStatus();
    await _tracking.loadTrail(tripId, AppConstants.tripStatusActive);
    await _tracking.loadRoute();
    await _refreshEta();
    if (mounted) setState(() {});
  }

  void _disconnectLive() {
    _socket.disconnect();
    _updateSocketStatus();
    setState(() {});
  }

  void _updateSocketStatus() {
    if (!_socket.isConnected) {
      _socketStatus = 'disconnected';
    } else if (_tracking.tripId != null) {
      _socketStatus = 'connected · joined ${_tracking.tripId}';
    } else {
      _socketStatus = 'connected';
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_socketListener != null) {
      _socket.removeDriverLocationUpdatedListener(_socketListener!);
    }
    _simulator.dispose();
    _tracking.dispose();
    _pickupLat.dispose();
    _pickupLng.dispose();
    _dropLat.dispose();
    _dropLng.dispose();
    _tripIdCtrl.dispose();
    _jwtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder(
            valueListenable: _tracking.liveMap,
            builder: (context, data, _) {
              return TripTrackingMap(
                fullScreen: true,
                pickupLocation: data.pickup,
                dropLocation: data.drop,
                driverLocation: data.driverTarget,
                driverTrailPoints: data.trail,
                routePolylinePoints: data.routePolyline,
                trailLoaded: data.trailLoaded,
                showDriverMarker: true,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _DebugHud(
                tracking: _tracking,
                socketStatus: _socketStatus,
                simRunning: _simulator.isRunning,
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: _panelExpanded ? 0.38 : 0.12,
            minChildSize: 0.12,
            maxChildSize: 0.72,
            builder: (context, scrollController) {
              return Material(
                elevation: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _panelExpanded = !_panelExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: Theme.of(context).colorScheme.surface,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.dividerGrey,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Simulate'),
                        Tab(text: 'Live'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _SimulatePanel(
                            scrollController: scrollController,
                            pickupLat: _pickupLat,
                            pickupLng: _pickupLng,
                            dropLat: _dropLat,
                            dropLng: _dropLng,
                            speedKmh: _speedKmh,
                            simRunning: _simulator.isRunning,
                            onSpeedChanged: (v) => setState(() => _speedKmh = v),
                            onUseDefaults: _useDefaults,
                            onApplyEndpoints: () => unawaited(_applyEndpoints()),
                            onReloadRoute: () => unawaited(_tracking.loadRoute()),
                            onStart: _startSim,
                            onPause: _pauseSim,
                            onReset: _resetSim,
                            onSnapRoads: () => unawaited(_maybeSnapTrail()),
                            onRefreshEta: () => unawaited(_refreshEta()),
                          ),
                          _LivePanel(
                            scrollController: scrollController,
                            tripIdCtrl: _tripIdCtrl,
                            jwtCtrl: _jwtCtrl,
                            socketStatus: _socketStatus,
                            onConnect: () => unawaited(_connectLive()),
                            onDisconnect: _disconnectLive,
                            onReloadTrail: () {
                              final id = _tripIdCtrl.text.trim();
                              if (id.isEmpty) return;
                              unawaited(_tracking.loadTrail(
                                id,
                                AppConstants.tripStatusActive,
                              ));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DebugHud extends StatelessWidget {
  const _DebugHud({
    required this.tracking,
    required this.socketStatus,
    required this.simRunning,
  });

  final LiveTrackingController tracking;
  final String socketStatus;
  final bool simRunning;

  @override
  Widget build(BuildContext context) {
    final driver = tracking.driverLocation;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        );
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: DefaultTextStyle(
          style: style ?? const TextStyle(color: Colors.white, fontSize: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tracking sandbox · ${simRunning ? "SIM RUN" : "SIM idle"}'),
              Text('Route: ${tracking.routePolyline.length} pts · '
                  'Trail: ${tracking.driverTrail.length} pts'),
              Text('Directions: ${tracking.directionsStatus}'
                  '${tracking.directionsDetail != null ? " (${tracking.directionsDetail})" : ""}'),
              Text('Roads: ${tracking.roadsStatus}'),
              if (driver != null)
                Text(
                  'Driver: ${driver.latitude.toStringAsFixed(5)}, '
                  '${driver.longitude.toStringAsFixed(5)}'
                  '${tracking.driverHeading != null ? " · hdg ${tracking.driverHeading!.toStringAsFixed(0)}°" : ""}',
                ),
              if (tracking.etaText != null || tracking.distanceText != null)
                Text(
                  'ETA: ${tracking.etaText ?? "—"} · '
                  'Dist: ${tracking.distanceText ?? "—"}',
                ),
              Text('Socket: $socketStatus'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulatePanel extends StatelessWidget {
  const _SimulatePanel({
    required this.scrollController,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    required this.speedKmh,
    required this.simRunning,
    required this.onSpeedChanged,
    required this.onUseDefaults,
    required this.onApplyEndpoints,
    required this.onReloadRoute,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onSnapRoads,
    required this.onRefreshEta,
  });

  final ScrollController scrollController;
  final TextEditingController pickupLat;
  final TextEditingController pickupLng;
  final TextEditingController dropLat;
  final TextEditingController dropLng;
  final double speedKmh;
  final bool simRunning;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onUseDefaults;
  final VoidCallback onApplyEndpoints;
  final VoidCallback onReloadRoute;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSnapRoads;
  final VoidCallback onRefreshEta;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text('Pickup / Drop (lat, lng)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: pickupLat, decoration: const InputDecoration(labelText: 'Pickup lat', isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: pickupLng, decoration: const InputDecoration(labelText: 'Pickup lng', isDense: true))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: dropLat, decoration: const InputDecoration(labelText: 'Drop lat', isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: dropLng, decoration: const InputDecoration(labelText: 'Drop lng', isDense: true))),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: onUseDefaults, child: const Text('Use defaults')),
            OutlinedButton(onPressed: onApplyEndpoints, child: const Text('Apply A/B')),
            OutlinedButton(onPressed: onReloadRoute, child: const Text('Reload route')),
          ],
        ),
        const SizedBox(height: 16),
        Text('Speed: ${speedKmh.round()} km/h', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: speedKmh,
          min: 20,
          max: 120,
          divisions: 20,
          label: '${speedKmh.round()}',
          onChanged: onSpeedChanged,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: simRunning ? null : onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
            FilledButton.tonalIcon(
              onPressed: simRunning ? onPause : null,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: onSnapRoads, child: const Text('Snap trail (Roads)')),
            OutlinedButton(onPressed: onRefreshEta, child: const Text('Refresh ETA')),
          ],
        ),
      ],
    );
  }
}

class _LivePanel extends StatelessWidget {
  const _LivePanel({
    required this.scrollController,
    required this.tripIdCtrl,
    required this.jwtCtrl,
    required this.socketStatus,
    required this.onConnect,
    required this.onDisconnect,
    required this.onReloadTrail,
  });

  final ScrollController scrollController;
  final TextEditingController tripIdCtrl;
  final TextEditingController jwtCtrl;
  final String socketStatus;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onReloadTrail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Paste JWT from a logged-in transporter session. Trip must be ACTIVE with a driver sending GPS.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: tripIdCtrl,
          decoration: const InputDecoration(
            labelText: 'Trip ID',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: jwtCtrl,
          decoration: const InputDecoration(
            labelText: 'JWT (access token)',
            isDense: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        Text('Status: $socketStatus', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link),
              label: const Text('Connect'),
            ),
            OutlinedButton.icon(
              onPressed: onDisconnect,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
            OutlinedButton(onPressed: onReloadTrail, child: const Text('Reload trail')),
          ],
        ),
      ],
    );
  }
}

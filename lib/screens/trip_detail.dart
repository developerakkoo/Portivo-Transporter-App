import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/helpers.dart';
import '../core/config/api_config.dart';
import '../core/utils/media_url.dart';
import '../data/models/trip_model.dart';
import '../data/models/vehicle_model.dart';
import '../data/models/driver_model.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/driver_provider.dart';
import '../models/trip_map_live_data.dart';
import '../services/trip_service.dart';
import '../core/utils/vehicle_driver_resolver.dart';
import '../services/live_tracking_controller.dart';
import '../services/socket_service.dart';
import '../widgets/trip_action_confirm_dialog.dart';
import '../widgets/trip_tracking_map.dart';
import 'trip_tracking_fullscreen_page.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  TripModel? _trip;
  String? _tripId;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _timeline = [];
  bool _timelineLoading = false;
  int _lastMilestoneCount = -1;
  int _activeTab = 0;
  final Set<int> _expandedTimelineItems = {};
  String? _lightboxImage;
  String? _lightboxTimestamp;
  late final LiveTrackingController _tracking;
  Timer? _trackingTicker;

  final SocketService _socketService = SocketService();
  TripProvider? _tripProviderListener;

  void _syncTripFromProvider() {
    final id = _tripId;
    if (id == null || !mounted) return;
    final p = _tripProviderListener;
    if (p == null) return;
    final t = p.getTripForDetail(id);
    if (t == null) return;
    final prevMilestones = _trip?.milestones.length ?? 0;
    setState(() => _trip = t);
    _tracking.seedDriverFromTrip(t);
    if (t.milestones.length != prevMilestones) {
      _lastMilestoneCount = t.milestones.length;
      _loadTimeline(id);
    }
  }

  @override
  void initState() {
    super.initState();
    _tracking = LiveTrackingController();
    _tracking.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrip();
      if (!mounted) return;
      final p = context.read<TripProvider>();
      _tripProviderListener = p;
      p.addListener(_syncTripFromProvider);
    });
    _socketService.addDriverLocationUpdatedListener(_onDriverLocationSocket);
    _socketService.addDriverStatusChangedListener(_onDriverStatusSocket);
    // Refresh the "updated Xs ago" label once per second.
    _trackingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _trip?.status == AppConstants.tripStatusActive) {
        setState(() {});
      }
    });
  }

  void _onDriverLocationSocket(Map<String, dynamic> data) {
    if (!mounted || _tripId == null) return;
    _tracking.handleDriverLocationSocket(data);
  }

  void _onDriverStatusSocket(Map<String, dynamic> data) {
    if (!mounted || _tripId == null) return;
    _tracking.handleDriverStatusSocket(data);
  }

  @override
  void dispose() {
    _tripProviderListener?.removeListener(_syncTripFromProvider);
    _tracking.dispose();
    _socketService.removeDriverLocationUpdatedListener(_onDriverLocationSocket);
    _socketService.removeDriverStatusChangedListener(_onDriverStatusSocket);
    _trackingTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverTrail(String tripId, String status) async {
    await _tracking.loadTrail(tripId, status);
  }

  /// Effective driver status: prefer the server-reported status, but fall back
  /// to "signal lost" when no live fix has arrived for a while.
  DriverTrackingStatus _effectiveDriverStatus() {
    final reported = _tracking.driverStatus;
    final last = _tracking.lastLocationAt;
    if (reported == DriverTrackingStatus.loggedOut ||
        reported == DriverTrackingStatus.gpsOff ||
        reported == DriverTrackingStatus.offline) {
      return reported;
    }
    if (last != null &&
        DateTime.now().difference(last) > const Duration(seconds: 30)) {
      return DriverTrackingStatus.stale;
    }
    // We have a live position on the map but no explicit status yet — show it
    // as live rather than "Waiting for GPS".
    if (reported == DriverTrackingStatus.unknown &&
        _tracking.driverLocation != null) {
      return DriverTrackingStatus.online;
    }
    return reported;
  }

  ({Color color, IconData icon, String label, String detail})
      _driverStatusVisual(DriverTrackingStatus status) {
    switch (status) {
      case DriverTrackingStatus.online:
        return (
          color: AppColors.success,
          icon: Icons.gps_fixed,
          label: 'Live',
          detail: 'Driver is sharing location',
        );
      case DriverTrackingStatus.gpsOff:
        return (
          color: AppColors.warning,
          icon: Icons.location_disabled,
          label: 'GPS off',
          detail: 'Driver turned off location services',
        );
      case DriverTrackingStatus.offline:
        return (
          color: AppColors.warning,
          icon: Icons.wifi_off,
          label: 'No internet',
          detail: 'Driver is offline — updates are paused',
        );
      case DriverTrackingStatus.loggedOut:
        return (
          color: AppColors.error,
          icon: Icons.logout,
          label: 'Driver logged out',
          detail: 'Tracking stopped until the driver signs back in',
        );
      case DriverTrackingStatus.stale:
        return (
          color: AppColors.warning,
          icon: Icons.signal_wifi_statusbar_connected_no_internet_4,
          label: 'Signal lost',
          detail: 'No location update received recently',
        );
      case DriverTrackingStatus.unknown:
        return (
          color: AppColors.textSecondary,
          icon: Icons.gps_not_fixed,
          label: 'Waiting for GPS',
          detail: 'Live position appears once the driver shares GPS',
        );
    }
  }

  Widget _buildDriverStatusBanner(TextTheme textTheme) {
    final status = _effectiveDriverStatus();
    final v = _driverStatusVisual(status);
    final lastAt = _tracking.lastLocationAt;
    final updatedAgo = lastAt == null ? null : _shortAgo(DateTime.now().difference(lastAt));

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: v.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: v.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(v.icon, color: v.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      v.label,
                      style: textTheme.labelLarge?.copyWith(
                        color: v.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (updatedAgo != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'updated $updatedAgo',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  v.detail,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfoCard(TextTheme textTheme) {
    final eta = _tracking.etaDisplay;
    final dist = _tracking.distanceRemainingDisplay;
    final progress = _tracking.routeProgress;
    final stage = _movementStageLabel();

    // Nothing useful yet (no route/position) — skip the card.
    if (eta == null && dist == null && progress == null && stage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (eta != null)
                _trackingMetric(textTheme, Icons.schedule, 'ETA', eta),
              if (eta != null && dist != null)
                const SizedBox(width: 20),
              if (dist != null)
                _trackingMetric(textTheme, Icons.route, 'Remaining', dist),
              const Spacer(),
              if (stage != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      stage,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.dividerGrey,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()}% of route complete',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trackingMetric(
    TextTheme textTheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Movement stage: prefer the server-computed value, else derive from
  /// milestone progress locally.
  String? _movementStageLabel() {
    final trip = _trip;
    if (trip == null || trip.status != AppConstants.tripStatusActive) return null;
    final serverStage = _tracking.movementStage;
    if (serverStage != null && serverStage.isNotEmpty) return serverStage;
    final count = trip.milestones.length;
    switch (count) {
      case 0:
        return 'En route to pickup';
      case 1:
        return 'Container picked up';
      case 2:
        return 'En route to destination';
      case 3:
        return 'Loading / unloading';
      default:
        return 'Near destination';
    }
  }

  static String _shortAgo(Duration d) {
    if (d.inSeconds < 5) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  void _openLiveTrackingFullscreen() {
    if (_tripId == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => TripTrackingFullscreenPage(
          tripId: _tripId!,
          live: _tracking.liveMap,
        ),
      ),
    );
  }

  void _joinTripAndResetDriverLocation(String tripId) {
    _tripId = tripId;
    _tracking.resetForTrip(tripId, _socketService);
  }

  Future<void> _loadRouteIfActive(TripModel trip) async {
    await _tracking.loadRouteIfActive(trip);
  }

  Future<void> _loadTimeline(String tripId) async {
    if (_timelineLoading) return;
    setState(() => _timelineLoading = true);
    try {
      final tripService = TripService();
      final data = await tripService.getTripTimeline(tripId);
      if (mounted && data != null && data['timeline'] != null) {
        setState(() {
          _timeline = List<Map<String, dynamic>>.from(data['timeline'] as List);
          _timelineLoading = false;
          final activeIdx = _timeline.indexWhere((t) => t['completed'] != true);
          if (activeIdx >= 0) {
            _expandedTimelineItems.add(activeIdx);
          } else if (_timeline.isNotEmpty) {
            _expandedTimelineItems.add(_timeline.length - 1);
          }
        });
      } else if (mounted) {
        setState(() => _timelineLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _timelineLoading = false);
    }
  }

  Future<void> _loadTrip() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      final tripId = args is String ? args : _tripId;
      if (tripId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Invalid trip ID';
          });
        }
        return;
      }

      final tripProvider = context.read<TripProvider>();
      final cached = tripProvider.getTripForDetail(tripId);
      if (cached != null && mounted) {
        setState(() {
          _trip = cached;
          _tripId = tripId;
          _isLoading = false;
        });
        _tracking.seedDriverFromTrip(cached);
        _loadRouteIfActive(cached);
        unawaited(_loadDriverTrail(tripId, cached.status));
      }

      _socketService.connect();
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user != null) {
        _socketService.joinTransporterRoom(user.transporterId ?? user.id);
      }
      _joinTripAndResetDriverLocation(tripId);

      final trip = await tripProvider.getTripById(tripId, silent: true);
      if (!mounted) return;
      setState(() {
        _trip = trip ?? _trip;
        _tripId = tripId;
        _isLoading = false;
        _error = trip == null ? (tripProvider.error ?? 'Trip not found') : null;
      });
      if (trip != null) {
        _tracking.seedDriverFromTrip(trip);
      }
      if (trip != null) {
        _loadTimeline(tripId);
        _loadRouteIfActive(trip);
        unawaited(_loadDriverTrail(tripId, trip.status));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _handleAction(String action) async {
    if (_trip == null) return;

    final t = _trip!;
    switch (action) {
      case 'start':
        if (!t.canStartTrip) return;
        break;
      case 'complete':
        if (!t.canCompleteTrip) return;
        break;
      case 'closeWithoutPOD':
        if (!t.canCloseWithoutPod) return;
        break;
      case 'approvePOD':
        if (!t.canApprovePod) return;
        break;
      case 'cancel':
        if (!t.canCancelTrip) return;
        break;
    }

    final tripProvider = context.read<TripProvider>();
    bool success = false;
    var userDismissedConfirmation = false;

    switch (action) {
      case 'start':
        success = await tripProvider.startTrip(_trip!.id);
        break;
      case 'complete':
        success = await tripProvider.completeTrip(_trip!.id);
        break;
      case 'closeWithoutPOD':
        final confirmed = await TripActionConfirmDialog.show(
          context: context,
          title: 'Close trip without POD?',
          body:
              'This will close the trip without proof of delivery. '
              'Only continue if you are sure this is correct. This action cannot be undone.',
          cancelLabel: 'Keep open',
          confirmLabel: 'Close without POD',
          icon: Icons.inventory_2_outlined,
          accentColor: AppColors.warning,
        );
        if (confirmed != true) {
          userDismissedConfirmation = true;
          break;
        }
        success = await tripProvider.closeTripWithoutPOD(_trip!.id);
        break;
      case 'approvePOD':
        success = await tripProvider.approvePOD(_trip!.id);
        break;
      case 'cancel':
        final confirmed = await TripActionConfirmDialog.show(
          context: context,
          title: 'Cancel this trip?',
          body:
              'The trip will be marked as cancelled. '
              'You can still view it in your trip history depending on filters.',
          cancelLabel: 'Go back',
          confirmLabel: 'Yes, cancel trip',
          icon: Icons.cancel_outlined,
          accentColor: AppColors.error,
        );
        if (confirmed != true) {
          userDismissedConfirmation = true;
          break;
        }
        success = await tripProvider.cancelTrip(_trip!.id);
        break;
    }

    if (userDismissedConfirmation || !mounted) return;

    if (mounted) {
      if (success) {
        final message = action == 'approvePOD'
            ? 'POD approved. Trip completed successfully.'
            : action == 'cancel'
                ? 'Trip cancelled successfully.'
                : action == 'closeWithoutPOD'
                    ? 'Trip closed without POD.'
                    : 'Trip ${action}ed successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTrip(); // Reload trip data
      } else {
        final errorMsg = action == 'approvePOD'
            ? (tripProvider.error ?? 'Failed to approve POD')
            : (tripProvider.error ?? 'Failed to $action trip');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Trip Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Trip Details'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64.0,
                color: AppColors.error,
              ),
              const SizedBox(height: 16.0),
              Text(
                _error ?? 'Trip not found',
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    _error!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
              const SizedBox(height: 12.0),
              TextButton(
                onPressed: _loadTrip,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<TripProvider>(
      builder: (context, tripProvider, _) {
        final trip = _tripId != null
            ? (tripProvider.getTripForDetail(_tripId!) ?? _trip)!
            : _trip!;
        if (trip.milestones.length != _lastMilestoneCount) {
          _lastMilestoneCount = trip.milestones.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_tripId != null) _loadTimeline(_tripId!);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Trip Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadTrip,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildStickyHeader(trip, textTheme),
                    Expanded(
                      child: _buildActiveTabContent(trip, textTheme),
                    ),
                    _buildStickyActionBar(trip, textTheme),
                  ],
                ),
              ),
              if (_lightboxImage != null)
                Positioned.fill(child: _buildLightboxOverlay()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickyHeader(TripModel trip, TextTheme textTheme) {
    final canEditContainer = trip.status == AppConstants.tripStatusPlanned ||
        trip.status == AppConstants.tripStatusActive ||
        trip.status == AppConstants.tripStatusAccepted;

    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: trip.assignments != null && trip.assignments!.isNotEmpty
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: trip.assignments!
                                        .map((a) => Text(
                                              '${a.containerNumber}${a.vehicleNumber != null ? ' · ${a.vehicleNumber}' : ''}',
                                              style: textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ))
                                        .toList(),
                                  )
                                : trip.containerNumber != null
                                    ? Text(
                                        trip.containerNumber!,
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : Text(
                                        'No container assigned',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textMuted,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                          ),
                          if (canEditContainer)
                            GestureDetector(
                              onTap: () => _showContainerEditDialog(trip),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  trip.containerNumber != null ? Icons.edit_outlined : Icons.add_circle_outline,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (trip.tripId.isNotEmpty)
                        Text(
                          'Trip ID: ${trip.tripId}',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Helpers.getStatusLabel(trip.status),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.dividerGrey, width: 1)),
            ),
            child: Row(
              children: [
                _buildTab(0, 'Overview'),
                _buildTab(1, 'Tracking'),
                _buildTab(2, 'Progress'),
                _buildTab(3, 'Actions'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(TripModel trip, TextTheme textTheme) {
    switch (_activeTab) {
      case 0:
        return _buildOverviewTab(trip, textTheme);
      case 1:
        return _buildTrackingTab(trip, textTheme);
      case 2:
        return _buildProgressTab(trip, textTheme);
      case 3:
        return _buildActionsTab(trip, textTheme);
      default:
        return _buildOverviewTab(trip, textTheme);
    }
  }

  Widget _buildOverviewTab(TripModel trip, TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trip.customerId != null || trip.customerName != null) ...[
            _buildCustomerCard(trip, textTheme),
            const SizedBox(height: 10),
          ],
          if (trip.isMarketplaceBuyerView) ...[
            _buildMarketplaceBanner(trip, textTheme),
            const SizedBox(height: 10),
          ],
          _buildCompactInfoCard(trip, textTheme),
          const SizedBox(height: 10),
          if (trip.pickupLocation != null || trip.dropLocation != null) ...[
            _buildLocationsCard(trip, textTheme),
            const SizedBox(height: 10),
          ],
          if (trip.status == AppConstants.tripStatusPlanned ||
              trip.status == AppConstants.tripStatusAccepted) ...[
            _buildAssignmentCard(trip, textTheme),
            const SizedBox(height: 10),
          ],
          _buildShareCard(trip, textTheme),
        ],
      ),
    );
  }

  Widget _buildMarketplaceBanner(TripModel trip, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are viewing this marketplace trip as the booking party. '
              'Vehicle, driver, and trip actions are managed by the listing owner.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoCard(TripModel trip, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(trip.tripType, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const Spacer(),
                Text(Helpers.formatDateTime(trip.createdAt), style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: _compactMetric(
                    textTheme: textTheme,
                    label: 'Vehicle',
                    value: trip.vehicleNumber ?? trip.vehicleId,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _compactMetric(
                    textTheme: textTheme,
                    label: 'Reference',
                    value: trip.reference ?? '—',
                    icon: Icons.tag_outlined,
                  ),
                ),
              ],
            ),
          ),
          if (trip.driverId != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 16),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      (trip.driverName?.isNotEmpty == true) ? trip.driverName![0].toUpperCase() : 'D',
                      style: textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.driverName ?? '—', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (trip.driverMobile != null)
                          Text(trip.driverMobile!, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (trip.driverMobile != null && trip.driverMobile!.trim().isNotEmpty)
                    IconButton(
                      onPressed: () => _callDriver(trip.driverMobile!),
                      icon: const Icon(Icons.phone),
                      tooltip: 'Call driver',
                      iconSize: 20,
                    ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _compactMetric({
    required TextTheme textTheme,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildShareCard(TripModel trip, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(Icons.share_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Share trip', style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, letterSpacing: 0.3)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (trip.canShareTrip)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => _handleShareTrip(trip),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Generate share link'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Share links can only be created by the listing owner.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackingTab(TripModel trip, TextTheme textTheme) {
    if (trip.status != AppConstants.tripStatusActive ||
        (trip.pickupLocation == null && trip.dropLocation == null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Live tracking is available when the trip is active.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDriverStatusBanner(textTheme),
          _buildTrackingInfoCard(textTheme),
          Hero(
            tag: 'trip_live_map_${trip.id}',
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ValueListenableBuilder<TripMapLiveData>(
                  valueListenable: _tracking.liveMap,
                  builder: (context, data, _) {
                    return TripTrackingMap(
                      pickupLocation: data.pickup,
                      dropLocation: data.drop,
                      driverLocation: data.driverTarget,
                      driverHeading: data.driverHeading,
                      driverTrailPoints: data.trail,
                      routePolylinePoints: data.routePolyline,
                      trailLoaded: data.trailLoaded,
                      showDriverMarker: true,
                      onExpand: _openLiveTrackingFullscreen,
                    );
                  },
                ),
              ),
            ),
          ),
          if (_tracking.driverLocation == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Live position appears when the trip is active, the driver shares GPS, and location updates are received.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressTab(TripModel trip, TextTheme textTheme) {
    final completedCount = _timeline.where((t) => t['completed'] == true).length;
    final total = _timeline.length;

    return _timelineLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (trip.status == AppConstants.tripStatusPodPending &&
                    trip.pod?.photo != null &&
                    (trip.pod!.photo?.isNotEmpty ?? false)) ...[
                  _buildPODSection(trip, textTheme),
                  const SizedBox(height: 12),
                ],
                if (trip.status == AppConstants.tripStatusPodPending &&
                    trip.canCloseWithoutPod &&
                    (trip.pod?.photo == null || (trip.pod!.photo?.isEmpty ?? true)) &&
                    (trip.podDueAt == null || trip.podDueAt!.isBefore(DateTime.now()))) ...[
                  _buildCloseWithoutPODButton(trip, textTheme),
                  const SizedBox(height: 12),
                ],
                if (total > 0) ...[
                  Row(
                    children: [
                      Text(
                        '$completedCount of $total milestones complete',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_timeline.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.offWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No milestones yet.',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...List.generate(_timeline.length, (i) {
                  final item = _timeline[i];
                  final isLast = i == _timeline.length - 1;
                  return _buildTimelineAccordionItem(item, i, isLast, textTheme);
                }),
              ],
            ),
          );
  }

  Widget _buildTimelineAccordionItem(
    Map<String, dynamic> item,
    int index,
    bool isLast,
    TextTheme textTheme,
  ) {
    final completed = item['completed'] == true;
    final photos = _getTimelinePhotos(item);
    final label = (item['driverLabel'] ?? item['milestoneType'] ?? '').toString();
    final timestamp = item['timestamp'];

    final isActive = !completed &&
        _timeline.indexWhere((t) => t['completed'] != true) == index;
    final isExpanded = _expandedTimelineItems.contains(index);

    final dotColor = completed
        ? AppColors.success
        : isActive
            ? AppColors.primary
            : AppColors.textMuted;

    final labelColor = completed
        ? AppColors.success
        : isActive
            ? AppColors.primary
            : AppColors.textSecondary;

    final canTap = completed || isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withOpacity(0.5)
                  : completed
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.dividerGrey,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: canTap
                    ? () => setState(() {
                          if (_expandedTimelineItems.contains(index)) {
                            _expandedTimelineItems.remove(index);
                          } else {
                            _expandedTimelineItems.add(index);
                          }
                        })
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor.withOpacity(0.12),
                          border: Border.all(color: dotColor.withOpacity(0.5)),
                        ),
                        child: Center(
                          child: Icon(
                            completed
                                ? Icons.check
                                : isActive
                                    ? Icons.navigation_outlined
                                    : Icons.circle_outlined,
                            size: 12,
                            color: dotColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: labelColor,
                              ),
                            ),
                            if (completed && timestamp != null)
                              Text(
                                _formatTimelineDate(timestamp),
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                              )
                            else if (isActive)
                              Text(
                                'In progress',
                                style: textTheme.bodySmall?.copyWith(color: AppColors.primary),
                              )
                            else
                              Text(
                                'Pending',
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                      if (canTap)
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Divider(height: 1, color: AppColors.dividerGrey),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: photos.isEmpty
                      ? Text(
                          'No photos attached to this milestone.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${photos.length} photo${photos.length > 1 ? 's' : ''}',
                              style: textTheme.labelSmall?.copyWith(
                                color: isActive ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: photos.map((p) {
                                final url = _getTimelineImageUrl(p);
                                return SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Stack(
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _lightboxImage = url;
                                            _lightboxTimestamp = _formatTimelineDate(item['timestamp']);
                                          }),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              url,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: AppColors.dividerGrey,
                                                child: Icon(Icons.broken_image, color: AppColors.textMuted),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Material(
                                          color: Colors.black45,
                                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
                                          child: InkWell(
                                            onTap: () => _downloadTimelineImage(url),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.download, color: Colors.white, size: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
        if (!isLast)
          Container(
            width: 1,
            height: 10,
            margin: const EdgeInsets.only(left: 22),
            color: AppColors.dividerGrey,
          ),
      ],
    );
  }

  Widget _buildActionsTab(TripModel trip, TextTheme textTheme) {
    final hasActions = trip.canStartTrip || trip.canCompleteTrip ||
        trip.canCancelTrip || trip.canCloseWithoutPod || trip.canApprovePod;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trip.status == AppConstants.tripStatusPlanned ||
              trip.status == AppConstants.tripStatusAccepted) ...[
            _buildAssignmentCard(trip, textTheme),
            const SizedBox(height: 12),
          ],
          if (hasActions) ...[
            _buildActionButtons(trip, textTheme),
          ] else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No actions available for this trip at the moment.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(TripModel trip, TextTheme textTheme) {
    if (trip.status == AppConstants.tripStatusCompleted ||
        trip.status == AppConstants.tripStatusCancelled) {
      return const SizedBox.shrink();
    }

    Widget? primaryBtn;
    Widget? secondaryBtn;

    if (trip.status == AppConstants.tripStatusPlanned &&
        trip.canStartTrip &&
        !trip.isQueuedBlocked) {
      primaryBtn = Expanded(
        flex: 2,
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _handleAction('start'),
            icon: const Icon(Icons.play_arrow),
            label: const Text(AppCopy.beginTrip),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    } else if (trip.status == AppConstants.tripStatusActive && trip.canCompleteTrip) {
      primaryBtn = Expanded(
        flex: 2,
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _handleAction('complete'),
            icon: const Icon(Icons.check_circle),
            label: const Text('Complete trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    } else if (trip.status == AppConstants.tripStatusPodPending && trip.canApprovePod) {
      primaryBtn = Expanded(
        flex: 2,
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _handleAction('approvePOD'),
            icon: const Icon(Icons.check_circle),
            label: const Text('Approve POD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    }

    if ((trip.status == AppConstants.tripStatusPlanned ||
            trip.status == AppConstants.tripStatusAccepted ||
            trip.status == AppConstants.tripStatusActive) &&
        trip.canCancelTrip) {
      secondaryBtn = Expanded(
        flex: 2,
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _handleAction('cancel'),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancel', maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.error),
              foregroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    }

    if (primaryBtn == null && secondaryBtn == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.dividerGrey)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (primaryBtn != null) primaryBtn,
            if (primaryBtn != null && secondaryBtn != null) const SizedBox(width: 10),
            if (secondaryBtn != null) secondaryBtn,
          ],
        ),
      ),
    );
  }

  List<String> _getTimelinePhotos(Map<String, dynamic> item) {
    final photosRaw = item['photos'];
    if (photosRaw is List && photosRaw.isNotEmpty) {
      return photosRaw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final photo = item['photo']?.toString();
    if (photo != null && photo.trim().isNotEmpty) {
      return [photo.trim()];
    }
    return [];
  }

  String _getTimelineImageUrl(String path) {
    return resolveUploadUrl(ApiConfig.baseUrl, path);
  }

  String _formatTimelineDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = d is DateTime ? d : DateTime.parse(d.toString());
      return Helpers.formatDateTime(dt);
    } catch (_) {
      return d.toString();
    }
  }

  Future<void> _callDriver(String raw) async {
    if (raw.trim().isEmpty) return;
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    final uri = Uri.parse('tel:$digits');
    try {
      final ok = await canLaunchUrl(uri);
      if (ok) {
        await launchUrl(uri);
      } else if (mounted) {
        await Clipboard.setData(ClipboardData(text: raw));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open dialer — number copied')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start call')),
        );
      }
    }
  }

  Future<void> _downloadTimelineImage(String absoluteUrl) async {
    try {
      var allowed = await Gal.hasAccess(toAlbum: true);
      if (!mounted) return;
      if (!allowed) {
        allowed = await Gal.requestAccess(toAlbum: true);
      }
      if (!mounted) return;
      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo library permission is required to save'),
          ),
        );
        return;
      }
      final dio = Dio();
      final resp = await dio.get<List<int>>(
        absoluteUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      final data = resp.data;
      if (data == null) {
        throw Exception('Empty image response');
      }
      final bytes = Uint8List.fromList(data);
      final name = 'milestone_${DateTime.now().millisecondsSinceEpoch}';
      await Gal.putImageBytes(bytes, name: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to gallery')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save image${e is GalException ? ': ${e.type}' : ''}',
          ),
        ),
      );
    }
  }

  Widget _buildLightboxOverlay() {
    return GestureDetector(
      onTap: () => setState(() {
        _lightboxImage = null;
        _lightboxTimestamp = null;
      }),
      child: Container(
        color: Colors.black87,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_lightboxImage != null)
                  Image.network(
                    _lightboxImage!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 64, color: Colors.white70),
                  ),
                if (_lightboxTimestamp != null)
                  Positioned(
                    top: 8.0,
                    right: 8.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        _lightboxTimestamp!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: -48.0,
                  right: 0.0,
                  child: IconButton(
                    onPressed: () => setState(() {
                      _lightboxImage = null;
                      _lightboxTimestamp = null;
                    }),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28.0),
                  ),
                ),
                if (_lightboxImage != null)
                  Positioned(
                    left: 16.0,
                    right: 16.0,
                    bottom: 24.0,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _downloadTimelineImage(_lightboxImage!),
                        icon: const Icon(Icons.download),
                        label: const Text('Save to gallery'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContainerEditDialog(TripModel trip) async {
    final controller = TextEditingController(text: trip.containerNumber ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Container Number'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Container Number',
            hintText: 'Enter container number',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim().toUpperCase()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final tripProvider = context.read<TripProvider>();
      final success = await tripProvider.updateTrip(trip.id, {'containerNumber': result.isEmpty ? null : result});
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Container number updated'), backgroundColor: Colors.green),
          );
          _loadTrip();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tripProvider.error ?? 'Failed to update container'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildCustomerCard(TripModel trip, TextTheme textTheme) {
    final name = trip.customerName ?? 'Customer';
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.dividerGrey, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: AppColors.primary, size: 24.0),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              name,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsCard(TripModel trip, TextTheme textTheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (trip.pickupLocation != null)
              _buildLocationRow(
                icon: Icons.location_on_outlined,
                label: 'Pickup',
                address: trip.pickupLocation!.address ?? 'Location',
                textTheme: textTheme,
              ),
            if (trip.pickupLocation != null && trip.dropLocation != null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Icon(
                  Icons.arrow_downward,
                  color: AppColors.primary,
                ),
              ),
            if (trip.dropLocation != null)
              _buildLocationRow(
                icon: Icons.location_on,
                label: 'Drop',
                address: trip.dropLocation!.address ?? 'Location',
                textTheme: textTheme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String address,
    required TextTheme textTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.0, color: AppColors.primary),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                address,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(TripModel trip, TextTheme textTheme) {
    return Column(
      children: [
        if (trip.status == AppConstants.tripStatusPlanned &&
            trip.canStartTrip &&
            !trip.isQueuedBlocked)
          SizedBox(
            width: double.infinity,
            height: 52.0,
            child: ElevatedButton.icon(
              onPressed: () => _handleAction('start'),
              icon: const Icon(Icons.play_arrow),
              label: const Text(AppCopy.beginTrip),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
              ),
            ),
          ),
        if (trip.status == AppConstants.tripStatusPlanned &&
            trip.canStartTrip &&
            !trip.isQueuedBlocked) const SizedBox(height: 12.0),
        if (trip.status == AppConstants.tripStatusActive && trip.canCompleteTrip)
          SizedBox(
            width: double.infinity,
            height: 52.0,
            child: ElevatedButton.icon(
              onPressed: () => _handleAction('complete'),
              icon: const Icon(Icons.check_circle),
              label: const Text('Complete Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.background,
              ),
            ),
          ),
        if (trip.status == AppConstants.tripStatusActive && trip.canCompleteTrip) const SizedBox(height: 12.0),
        if ((trip.status == AppConstants.tripStatusPlanned ||
                trip.status == AppConstants.tripStatusAccepted ||
                trip.status == AppConstants.tripStatusActive) &&
            trip.canCancelTrip)
          SizedBox(
            width: double.infinity,
            height: 52.0,
            child: OutlinedButton.icon(
              onPressed: () => _handleAction('cancel'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Trip'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAssignmentCard(TripModel trip, TextTheme textTheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Vehicle Assignment
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 20.0, color: AppColors.textSecondary),
                          const SizedBox(width: 8.0),
                          Text(
                            'Vehicle',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        (trip.vehicleNumber ?? trip.vehicleId).isNotEmpty ? (trip.vehicleNumber ?? trip.vehicleId) : 'Not assigned',
                        style: textTheme.bodyMedium?.copyWith(
                          color: (trip.vehicleNumber ?? trip.vehicleId).isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: trip.canAssignVehicle ? () => _showVehicleAssignmentDialog(trip) : null,
                  icon: Icon(
                    trip.vehicleId.isNotEmpty ? Icons.edit : Icons.add,
                    size: 18.0,
                  ),
                  label: Text(trip.vehicleId.isNotEmpty ? 'Change' : 'Assign'),
                ),
              ],
            ),
            const Divider(),
            // Driver Assignment
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outlined, size: 20.0, color: AppColors.textSecondary),
                          const SizedBox(width: 8.0),
                          Text(
                            'Driver',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        (trip.driverName ?? trip.driverId ?? '').isNotEmpty ? (trip.driverName ?? trip.driverId ?? '') : 'Not assigned',
                        style: textTheme.bodyMedium?.copyWith(
                          color: (trip.driverName ?? trip.driverId ?? '').isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: trip.canAssignDriver ? () => _showDriverAssignmentDialog(trip) : null,
                  icon: Icon(
                    trip.driverId != null && trip.driverId!.isNotEmpty ? Icons.edit : Icons.add,
                    size: 18.0,
                  ),
                  label: Text(trip.driverId != null && trip.driverId!.isNotEmpty ? 'Change' : 'Assign'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVehicleAssignmentDialog(TripModel trip) async {
    if (!trip.canAssignVehicle) return;
    final vehicleProvider = context.read<VehicleProvider>();
    await vehicleProvider.loadVehicles(status: 'active', refresh: true);
    final vehicles = vehicleProvider.vehicles;

    if (!mounted) return;

    final selectedVehicle = await showDialog<VehicleModel?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Vehicle'),
        content: SizedBox(
          width: double.maxFinite,
          child: vehicles.isEmpty
              ? const Text('No active vehicles available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: vehicles.length + 1, // +1 for "Unassign" option
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        title: const Text('Unassign Vehicle', style: TextStyle(color: AppColors.error)),
                        onTap: () => Navigator.of(context).pop<VehicleModel?>(null),
                      );
                    }
                    final vehicle = vehicles[index - 1];
                    final isSelected = trip.vehicleId == vehicle.id;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.inventory_2_outlined,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                      title: Text(vehicle.vehicleNumber),
                      subtitle: Text('${vehicle.ownerType}${vehicle.trailerType != null ? ' • ${vehicle.trailerType}' : ''}'),
                      selected: isSelected,
                      onTap: () => Navigator.of(context).pop(vehicle),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedVehicle != null || (selectedVehicle == null && trip.vehicleId.isNotEmpty)) {
      final tripProvider = context.read<TripProvider>();
      final bool success;
      if (selectedVehicle != null) {
        success = await tripProvider.assignVehicle(trip.id, selectedVehicle.id);
      } else {
        success = await tripProvider.updateTrip(trip.id, {'vehicleId': null});
      }

      if (mounted) {
        if (success) {
          var message = selectedVehicle == null
              ? 'Vehicle unassigned'
              : 'Vehicle assigned successfully';

          if (selectedVehicle != null && trip.canAssignDriver) {
            final driverProvider = context.read<DriverProvider>();
            await driverProvider.loadDrivers(refresh: true);
            if (!mounted) return;
            final linked = resolveDriverForVehicle(
              selectedVehicle,
              driverProvider.drivers,
            );
            if (linked != null) {
              final driverSuccess =
                  await tripProvider.assignDriver(trip.id, linked.id);
              if (!mounted) return;
              if (driverSuccess) {
                message = 'Vehicle and driver assigned';
              } else {
                final driverErr =
                    tripProvider.error ?? 'Failed to assign linked driver';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Vehicle assigned. $driverErr'),
                    backgroundColor: AppColors.error,
                  ),
                );
                await _loadTrip();
                return;
              }
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadTrip();
        } else {
          final errMsg = tripProvider.error ?? 'Failed to assign vehicle';
          final isAlreadyAssigned = errMsg.toLowerCase().contains('already assigned');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isAlreadyAssigned
                    ? 'This vehicle is already on another active trip. Please select a different vehicle.'
                    : errMsg,
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDriverAssignmentDialog(TripModel trip) async {
    if (!trip.canAssignDriver) return;
    final driverProvider = context.read<DriverProvider>();
    await driverProvider.loadDrivers(refresh: true);
    final drivers = driverProvider.drivers
        .where((d) => d.status == AppConstants.driverStatusActive)
        .toList();

    if (!mounted) return;

    final selectedDriver = await showDialog<DriverModel?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Driver'),
        content: SizedBox(
          width: double.maxFinite,
          child: drivers.isEmpty
              ? const Text('No drivers available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: drivers.length + 1, // +1 for "Unassign" option
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        title: const Text('Unassign Driver', style: TextStyle(color: AppColors.error)),
                        onTap: () => Navigator.of(context).pop<DriverModel?>(null),
                      );
                    }
                    final driver = drivers[index - 1];
                    final isSelected = trip.driverId == driver.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.offWhite,
                        child: Text(
                          (driver.name?.isNotEmpty == true) ? driver.name![0].toUpperCase() : 'D',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(driver.name ?? 'Driver'),
                      subtitle: Text(driver.mobile),
                      selected: isSelected,
                      onTap: () => Navigator.of(context).pop(driver),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedDriver != null || (selectedDriver == null && trip.driverId != null && trip.driverId!.isNotEmpty)) {
      final tripProvider = context.read<TripProvider>();
      final bool success;
      if (selectedDriver != null) {
        success = await tripProvider.assignDriver(trip.id, selectedDriver.id);
      } else {
        success = await tripProvider.updateTrip(trip.id, {'driverId': null});
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(selectedDriver == null ? 'Driver unassigned' : 'Driver assigned successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadTrip(); // Reload trip
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tripProvider.error ?? 'Failed to assign driver'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildPODSection(TripModel trip, TextTheme textTheme) {
    final podPhotoUrl = trip.pod?.photo != null && (trip.pod!.photo?.isNotEmpty ?? false)
        ? resolveUploadUrl(ApiConfig.baseUrl, trip.pod!.photo)
        : null;
    final safePodUrl = (podPhotoUrl != null && podPhotoUrl.isNotEmpty) ? podPhotoUrl : null;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.dividerGrey, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (safePodUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                safePodUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.dividerGrey,
                  child: Center(
                    child: Icon(Icons.broken_image, size: 48, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          if (trip.canApprovePod)
            SizedBox(
              width: double.infinity,
              height: 52.0,
              child: ElevatedButton.icon(
                onPressed: () => _handleAction('approvePOD'),
                icon: const Icon(Icons.check_circle),
                label: const Text('Approve POD & Complete Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            Text(
              'POD approval is done by the listing owner.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildCloseWithoutPODButton(TripModel trip, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 52.0,
      child: OutlinedButton.icon(
        onPressed: () => _handleAction('closeWithoutPOD'),
        icon: const Icon(Icons.close),
        label: const Text('Close Trip Without POD'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.warning),
          foregroundColor: AppColors.warning,
        ),
      ),
    );
  }

  Future<void> _handleShareTrip(TripModel trip) async {
    if (!trip.canShareTrip) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the trip owner can generate a share link for this trip.'),
          ),
        );
      }
      return;
    }
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate share link
      final tripService = TripService();
      final shareData = await tripService.shareTrip(trip.id, expiryHours: 168); // 7 days

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (shareData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate share link'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get share URL from response (backend provides full URL)
      final shareUrl = shareData['shareUrl'] as String? ?? 
                       shareData['shareLink'] as String? ?? 
                       (() {
                         final baseUrl = ApiConfig.restOrigin;
                         final shareToken = shareData['shareToken'] as String;
                         return '$baseUrl/api/trips/shared/$shareToken/view';
                       })();

      // Parse expiry date
      String? expiryDateStr;
      if (shareData['expiryDate'] != null) {
        try {
          final expiryDate = DateTime.parse(shareData['expiryDate'] as String);
          expiryDateStr = Helpers.formatDateTime(expiryDate);
        } catch (e) {
          // If parsing fails, use the string as-is
          expiryDateStr = shareData['expiryDate'].toString();
        }
      }

      // Show share dialog
      if (!mounted) return;
      await _showShareDialog(shareUrl, expiryDateStr);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showShareDialog(String shareUrl, String? expiryDate) async {
    final textTheme = Theme.of(context).textTheme;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Trip Link'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this link to allow others to view trip details:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12.0),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppColors.dividerGrey),
                ),
                child: SelectableText(
                  shareUrl,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (expiryDate != null) ...[
                const SizedBox(height: 12.0),
                Text(
                  'Link expires: $expiryDate',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareUrl));
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Link'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Share.share(
                shareUrl,
                subject: 'Trip Tracking Link - ${_trip?.containerNumber ?? _trip?.tripId ?? "Trip"}',
              );
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }
}

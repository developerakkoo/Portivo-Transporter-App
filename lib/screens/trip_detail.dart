import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import '../services/trip_service.dart';
import '../services/socket_service.dart';
import '../widgets/trip_tracking_map.dart';

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
  String? _lightboxImage;
  String? _lightboxTimestamp;
  LatLng? _driverLocation;

  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTrip());
    _socketService.onDriverLocationUpdated = (data) {
      if (!mounted || _tripId == null) return;
      final tripId = data['tripId']?.toString();
      if (tripId != _tripId) return;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() => _driverLocation = LatLng(lat, lng));
      }
    };
  }

  @override
  void dispose() {
    _socketService.onDriverLocationUpdated = null;
    super.dispose();
  }

  void _joinTripAndResetDriverLocation(String tripId) {
    _tripId = tripId;
    _driverLocation = null;
    _socketService.joinTripRoom(tripId);
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
        _error = trip == null ? 'Trip not found' : null;
      });
      if (trip != null) {
        _loadTimeline(tripId);
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

    final tripProvider = context.read<TripProvider>();
    bool success = false;

    switch (action) {
      case 'start':
        success = await tripProvider.startTrip(_trip!.id);
        break;
      case 'complete':
        success = await tripProvider.completeTrip(_trip!.id);
        break;
      case 'closeWithoutPOD':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Close Trip Without POD'),
            content: const Text(
              'Are you sure you want to close this trip without POD? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, Close'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          success = await tripProvider.closeTripWithoutPOD(_trip!.id);
        }
        break;
      case 'approvePOD':
        success = await tripProvider.approvePOD(_trip!.id);
        break;
      case 'cancel':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Trip'),
            content: const Text('Are you sure you want to cancel this trip?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          success = await tripProvider.cancelTrip(_trip!.id);
        }
        break;
    }

    if (mounted) {
      if (success) {
        final message = action == 'approvePOD'
            ? 'POD approved. Trip completed successfully.'
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer (for customer-booked trips)
              if (trip.customerId != null || trip.customerName != null) ...[
                _buildSectionHeader('Customer', textTheme),
                const SizedBox(height: 16.0),
                _buildCustomerCard(trip, textTheme),
                const SizedBox(height: 24.0),
              ],

              // Trip Status Card
              _buildStatusCard(trip, textTheme),
              const SizedBox(height: 24.0),

              // Trip Information
              _buildSectionHeader('Trip Information', textTheme),
              const SizedBox(height: 16.0),
              _buildInfoCard(trip, textTheme),
              const SizedBox(height: 24.0),

              // Locations
              if (trip.pickupLocation != null || trip.dropLocation != null) ...[
                _buildSectionHeader('Locations', textTheme),
                const SizedBox(height: 16.0),
                _buildLocationsCard(trip, textTheme),
                const SizedBox(height: 24.0),
              ],

              // Live driver tracking (when trip is ACTIVE)
              if (trip.status == AppConstants.tripStatusActive &&
                  (trip.pickupLocation != null || trip.dropLocation != null)) ...[
                _buildSectionHeader('Live Tracking', textTheme),
                const SizedBox(height: 8.0),
                TripTrackingMap(
                  pickupLocation: trip.pickupLocation?.coordinates != null
                      ? LatLng(
                          trip.pickupLocation!.coordinates.latitude,
                          trip.pickupLocation!.coordinates.longitude,
                        )
                      : null,
                  dropLocation: trip.dropLocation?.coordinates != null
                      ? LatLng(
                          trip.dropLocation!.coordinates.latitude,
                          trip.dropLocation!.coordinates.longitude,
                        )
                      : null,
                  driverLocation: _driverLocation,
                  showDriverMarker: true,
                ),
                if (_driverLocation == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Waiting for driver location...',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 24.0),
              ],

              // Assignment Section (for PLANNED and ACCEPTED trips)
              if (trip.status == AppConstants.tripStatusPlanned ||
                  trip.status == AppConstants.tripStatusAccepted) ...[
                _buildSectionHeader('Assignments', textTheme),
                const SizedBox(height: 16.0),
                _buildAssignmentCard(trip, textTheme),
                const SizedBox(height: 24.0),
              ],

              // Actions (for PLANNED, ACCEPTED, and ACTIVE trips)
              if (trip.status == AppConstants.tripStatusPlanned ||
                  trip.status == AppConstants.tripStatusAccepted ||
                  trip.status == AppConstants.tripStatusActive) ...[
                _buildSectionHeader('Actions', textTheme),
                const SizedBox(height: 16.0),
                _buildActionButtons(trip, textTheme),
              ],

              // Timeline / Milestones section
              if (_tripId != null) ...[
                _buildSectionHeader('Timeline', textTheme),
                const SizedBox(height: 16.0),
                _buildTimelineSection(trip, textTheme),
                const SizedBox(height: 24.0),
              ],

              // POD section when uploaded - view image and approve
              if (trip.status == AppConstants.tripStatusPodPending &&
                  trip.pod?.photo != null &&
                  (trip.pod!.photo?.isNotEmpty ?? false)) ...[
                _buildSectionHeader('Proof of Delivery', textTheme),
                const SizedBox(height: 16.0),
                _buildPODSection(trip, textTheme),
              ],

              // Close Without POD (for POD_PENDING when 72h window expired, no POD uploaded)
              if (trip.status == AppConstants.tripStatusPodPending &&
                  (trip.pod?.photo == null || (trip.pod!.photo?.isEmpty ?? true)) &&
                  (trip.podDueAt == null || trip.podDueAt!.isBefore(DateTime.now()))) ...[
                _buildSectionHeader('POD Pending', textTheme),
                const SizedBox(height: 16.0),
                _buildCloseWithoutPODButton(trip, textTheme),
              ],

              // Share Trip Section (always visible)
              _buildSectionHeader('Share Trip', textTheme),
              const SizedBox(height: 16.0),
              _buildShareButton(trip, textTheme),
            ],
              ),
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

  Widget _buildTimelineSection(TripModel trip, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.dividerGrey, width: 1.0),
      ),
      child: _timelineLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _timeline.isEmpty && !_timelineLoading
                  ? [
                      Text(
                        'No milestones yet',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ]
                  : _timeline.map((item) {
                final completed = item['completed'] == true;
                final photos = _getTimelinePhotos(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        completed ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20.0,
                        color: completed ? AppColors.success : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['driverLabel'] ?? item['milestoneType'] ?? '').toString(),
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (completed && item['timestamp'] != null)
                              Text(
                                _formatTimelineDate(item['timestamp']),
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (photos.isNotEmpty) ...[
                              const SizedBox(height: 8.0),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: photos.map((p) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _lightboxImage = _getTimelineImageUrl(p);
                                        _lightboxTimestamp = _formatTimelineDate(item['timestamp']);
                                      });
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.network(
                                        _getTimelineImageUrl(p),
                                        width: 64.0,
                                        height: 64.0,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 64.0,
                                          height: 64.0,
                                          color: AppColors.dividerGrey,
                                          child: Icon(Icons.broken_image, color: AppColors.textMuted),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
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

  Widget _buildStatusCard(TripModel trip, TextTheme textTheme) {
    final canEditContainer = trip.status == AppConstants.tripStatusPlanned ||
        trip.status == AppConstants.tripStatusActive ||
        trip.status == AppConstants.tripStatusAccepted;
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.primary,
          width: 2.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      .map((a) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: Text(
                                              '${a.containerNumber}${a.vehicleNumber != null ? ' • ${a.vehicleNumber}' : ''}',
                                              style: textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                )
                              : trip.containerNumber != null
                                  ? Text(
                                      trip.containerNumber!,
                                      style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Text(
                                      'No container',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textMuted,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                        ),
                        if (canEditContainer)
                          IconButton(
                            icon: Icon(
                              trip.containerNumber != null ? Icons.edit_outlined : Icons.add_circle_outline,
                              size: 20.0,
                              color: AppColors.primary,
                            ),
                            onPressed: () => _showContainerEditDialog(trip),
                            tooltip: trip.containerNumber != null ? 'Edit container' : 'Add container',
                          ),
                      ],
                    ),
                    if (trip.tripId.isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        'Trip ID: ${trip.tripId}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.0),
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInfoCard(TripModel trip, TextTheme textTheme) {
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
            if (trip.reference != null)
              _buildInfoRow(
                icon: Icons.tag_outlined,
                label: 'Reference',
                value: trip.reference!,
                textTheme: textTheme,
              ),
            if (trip.reference != null) const SizedBox(height: 12.0),
            _buildInfoRow(
              icon: Icons.category_outlined,
              label: 'Trip Type',
              value: trip.tripType,
              textTheme: textTheme,
            ),
            const SizedBox(height: 12.0),
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Created',
              value: Helpers.formatDateTime(trip.createdAt),
              textTheme: textTheme,
            ),
            const SizedBox(height: 12.0),
            _buildInfoRow(
              icon: Icons.inventory_2_outlined,
              label: 'Vehicle',
              value: trip.vehicleId,
              textTheme: textTheme,
            ),
            if (trip.driverId != null) ...[
              const SizedBox(height: 12.0),
              _buildInfoRow(
                icon: Icons.person_outlined,
                label: 'Driver',
                value: trip.driverId!,
                textTheme: textTheme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20.0, color: AppColors.textSecondary),
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
                value,
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
        if (trip.status == AppConstants.tripStatusPlanned)
          SizedBox(
            width: double.infinity,
            height: 52.0,
            child: ElevatedButton.icon(
              onPressed: () => _handleAction('start'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
              ),
            ),
          ),
        if (trip.status == AppConstants.tripStatusPlanned) const SizedBox(height: 12.0),
        if (trip.status == AppConstants.tripStatusActive)
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
        if (trip.status == AppConstants.tripStatusActive) const SizedBox(height: 12.0),
        if (trip.status == AppConstants.tripStatusPlanned ||
            trip.status == AppConstants.tripStatusAccepted ||
            trip.status == AppConstants.tripStatusActive)
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
                  onPressed: () => _showVehicleAssignmentDialog(trip),
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
                  onPressed: () => _showDriverAssignmentDialog(trip),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(selectedVehicle == null ? 'Vehicle unassigned' : 'Vehicle assigned successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadTrip(); // Reload trip
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

  Widget _buildShareButton(TripModel trip, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 52.0,
      child: OutlinedButton.icon(
        onPressed: () => _handleShareTrip(trip),
        icon: const Icon(Icons.share),
        label: const Text('Share Trip Link'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          foregroundColor: AppColors.primary,
        ),
      ),
    );
  }

  Future<void> _handleShareTrip(TripModel trip) async {
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
                         final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
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

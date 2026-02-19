import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/helpers.dart';
import '../core/config/api_config.dart';
import '../data/models/trip_model.dart';
import '../data/models/vehicle_model.dart';
import '../data/models/driver_model.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/driver_provider.dart';
import '../services/trip_service.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  TripModel? _trip;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use postFrameCallback to ensure context is fully built before accessing ModalRoute
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrip();
    });
  }

  Future<void> _loadTrip() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        final tripId = args;
        final tripProvider = context.read<TripProvider>();
        final trip = await tripProvider.getTripById(tripId);
        if (mounted) {
          setState(() {
            _trip = trip;
            _isLoading = false;
            _error = trip == null ? 'Trip not found' : null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Invalid trip ID';
          });
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip ${action}ed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTrip(); // Reload trip data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tripProvider.error ?? 'Failed to $action trip'),
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

    final trip = _trip!;

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

              // Assignment Section (only for PLANNED trips)
              if (trip.status == AppConstants.tripStatusPlanned) ...[
                _buildSectionHeader('Assignments', textTheme),
                const SizedBox(height: 16.0),
                _buildAssignmentCard(trip, textTheme),
                const SizedBox(height: 24.0),
              ],

              // Actions
              if (trip.status == AppConstants.tripStatusPlanned ||
                  trip.status == AppConstants.tripStatusActive) ...[
                _buildSectionHeader('Actions', textTheme),
                const SizedBox(height: 16.0),
                _buildActionButtons(trip, textTheme),
              ],

              // Share Trip Section (always visible)
              _buildSectionHeader('Share Trip', textTheme),
              const SizedBox(height: 16.0),
              _buildShareButton(trip, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(TripModel trip, TextTheme textTheme) {
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
                    if (trip.containerNumber != null)
                      Text(
                        trip.containerNumber!,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
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
              icon: Icons.directions_car_outlined,
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
                          Icon(Icons.directions_car_outlined, size: 20.0, color: AppColors.textSecondary),
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
                        trip.vehicleId.isNotEmpty ? trip.vehicleId : 'Not assigned',
                        style: textTheme.bodyMedium?.copyWith(
                          color: trip.vehicleId.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
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
                        trip.driverId != null && trip.driverId!.isNotEmpty ? trip.driverId! : 'Not assigned',
                        style: textTheme.bodyMedium?.copyWith(
                          color: trip.driverId != null && trip.driverId!.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
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
                        isSelected ? Icons.check_circle : Icons.directions_car_outlined,
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
      // Update trip
      final tripProvider = context.read<TripProvider>();
      final success = await tripProvider.updateTrip(
        trip.id,
        {'vehicleId': selectedVehicle?.id ?? null},
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(selectedVehicle == null ? 'Vehicle unassigned' : 'Vehicle assigned successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadTrip(); // Reload trip
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tripProvider.error ?? 'Failed to assign vehicle'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDriverAssignmentDialog(TripModel trip) async {
    final driverProvider = context.read<DriverProvider>();
    await driverProvider.loadDrivers(refresh: true);
    final drivers = driverProvider.drivers;

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
      // Update trip
      final tripProvider = context.read<TripProvider>();
      final success = await tripProvider.updateTrip(
        trip.id,
        {'driverId': selectedDriver?.id ?? null},
      );

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

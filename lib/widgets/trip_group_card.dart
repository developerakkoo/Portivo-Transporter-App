import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/tracking_format.dart';
import '../core/utils/vehicle_overflow.dart';
import '../data/models/trip_group.dart';
import '../data/models/trip_model.dart';

/// Summary card for one trip group (a multi-route / multi-vehicle trip) in the
/// Active sub-tab: customer, representative id, vehicle & container counts, the
/// earliest live ETA, and a status pill. Tapping "View Trip" opens the
/// group-detail screen.
class TripGroupCard extends StatelessWidget {
  const TripGroupCard({
    super.key,
    required this.group,
    required this.textTheme,
    required this.onViewTrip,
  });

  final TripGroup group;
  final TextTheme textTheme;
  final VoidCallback onViewTrip;

  @override
  Widget build(BuildContext context) {
    final customer = (group.customerName ?? '').trim();
    final title = (customer.isNotEmpty ? customer : group.displayTripId).toUpperCase();
    final etaText = TrackingFormat.eta(group.earliestEtaSeconds);
    final status = _statusFor(group);
    final assignment = _primaryAssignment(group);
    final extraVehicles = group.vehicleCount - 1;

    return Container(
      key: Key('trip_group_${group.groupId}'),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        _subtitle(group),
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 11.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                _statusPill(status),
              ],
            ),
            const SizedBox(height: 14.0),
            Row(
              children: [
                _stat(
                  icon: Icons.local_shipping_outlined,
                  label: group.vehicleCount == 1 ? 'Vehicle' : 'Vehicles',
                  value: '${group.vehicleCount}',
                ),
                _divider(),
                _stat(
                  icon: Icons.inventory_2_outlined,
                  label: group.containerCount == 1 ? 'Container' : 'Containers',
                  value: '${group.containerCount}',
                ),
                _divider(),
                _stat(
                  icon: Icons.schedule_outlined,
                  label: 'ETA',
                  value: etaText ?? '—',
                ),
              ],
            ),
            if (assignment != null) ...[
              const SizedBox(height: 12.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1.0),
                    child: Icon(
                      Icons.person_outline,
                      size: 18.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (extraVehicles > 0)
                          Text(
                            extraVehiclesLabel(extraVehicles),
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 11.0,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12.0),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewTrip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.dividerGrey),
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 18.0),
                    SizedBox(width: 8.0),
                    Text(
                      'View Trip',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 2.0),
                    Icon(Icons.chevron_right, size: 18.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(TripGroup group) {
    final ref = group.reference?.trim();
    if (ref != null && ref.isNotEmpty) {
      return '${group.displayTripId} · Ref: $ref';
    }
    return group.displayTripId;
  }

  /// First assigned vehicle and driver, e.g. "MH01EF9990 · Shubham".
  String? _primaryAssignment(TripGroup group) {
    for (final trip in group.trips) {
      final vehicle = trip.vehicleNumber?.trim() ?? '';
      final driver = trip.driverName?.trim() ?? '';
      if (vehicle.isEmpty && driver.isEmpty) continue;
      if (vehicle.isNotEmpty && driver.isNotEmpty) return '$vehicle · $driver';
      return vehicle.isNotEmpty ? vehicle : driver;
    }
    return null;
  }

  _CardStatus _statusFor(TripGroup group) {
    if (group.trips.isNotEmpty && group.trips.every(_isAwaitingPod)) {
      return _CardStatus.awaitingPod;
    }
    if (group.trips.isNotEmpty && group.trips.every(_isCompleted)) {
      return _CardStatus.completed;
    }
    return _CardStatus.inProgress;
  }

  bool _isAwaitingPod(TripModel trip) =>
      trip.status.toUpperCase() == AppConstants.tripStatusPodPending;

  bool _isCompleted(TripModel trip) {
    final status = trip.status.toUpperCase();
    return status == AppConstants.tripStatusCompleted ||
        status == AppConstants.tripStatusClosedWithPOD ||
        status == AppConstants.tripStatusClosedWithoutPOD;
  }

  Widget _statusPill(_CardStatus status) {
    final color = switch (status) {
      _CardStatus.inProgress => AppColors.info,
      _CardStatus.awaitingPod => AppColors.warning,
      _CardStatus.completed => AppColors.success,
    };
    final label = switch (status) {
      _CardStatus.inProgress => 'In Progress',
      _CardStatus.awaitingPod => 'Awaiting POD',
      _CardStatus.completed => 'Completed',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.0,
            height: 7.0,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11.0,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20.0, color: AppColors.primary),
          const SizedBox(width: 8.0),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 11.0,
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1.0,
        height: 28.0,
        color: AppColors.dividerGrey,
      );
}

enum _CardStatus { inProgress, awaitingPod, completed }

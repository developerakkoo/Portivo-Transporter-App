import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/helpers.dart';
import '../data/models/trip_model.dart';

/// Accordion trip card: summary in header; locations, date, and optional actions when expanded.
/// Detail navigation is via [onOpenDetail] only (not the whole card).
class TripExpansionCard extends StatelessWidget {
  const TripExpansionCard({
    super.key,
    required this.trip,
    required this.textTheme,
    required this.onOpenDetail,
    this.showAcceptButton = false,
    this.showPinButton = true,
    this.isPinned = false,
    this.isHighlighted = false,
    this.onPinTap,
    this.onAcceptTrip,
    this.onRejectTrip,
  });

  final TripModel trip;
  final TextTheme textTheme;
  final VoidCallback onOpenDetail;
  final bool showAcceptButton;
  final bool showPinButton;
  final bool isPinned;
  final bool isHighlighted;
  final VoidCallback? onPinTap;
  final Future<void> Function()? onAcceptTrip;
  final Future<void> Function()? onRejectTrip;

  @override
  Widget build(BuildContext context) {
    final titleText = trip.containerNumber?.isNotEmpty == true
        ? trip.containerNumber!
        : (trip.tripId.isNotEmpty ? trip.tripId : 'Trip');

    return Container(
      key: Key('trip_expansion_${trip.id}'),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isHighlighted ? AppColors.success : AppColors.dividerGrey,
          width: isHighlighted ? 3.0 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          childrenPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
          title: Column(
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
                          titleText,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trip.tripId.isNotEmpty &&
                            trip.containerNumber != null &&
                            trip.containerNumber!.isNotEmpty) ...[
                          const SizedBox(height: 4.0),
                          Text(
                            trip.tripId,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (trip.reference != null && trip.reference!.isNotEmpty) ...[
                          const SizedBox(height: 4.0),
                          Text(
                            trip.reference!,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showPinButton && onPinTap != null)
                    IconButton(
                      icon: Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: isPinned ? AppColors.primary : AppColors.textSecondary,
                      ),
                      tooltip: isPinned ? 'Unpin' : 'Pin to home',
                      onPressed: onPinTap,
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'View details',
                    onPressed: onOpenDetail,
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(trip.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      Helpers.getStatusLabel(trip.status),
                      style: textTheme.labelSmall?.copyWith(
                        color: _getStatusColor(trip.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Helpers.getTripTypeLabel(trip.tripType),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            if (trip.pickupLocation != null || trip.dropLocation != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trip.pickupLocation != null)
                    Expanded(
                      child: _buildTripInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Origin',
                        value: trip.pickupLocation!.address ?? 'Location',
                        textTheme: textTheme,
                      ),
                    ),
                  if (trip.pickupLocation != null && trip.dropLocation != null) ...[
                    const SizedBox(width: 12.0),
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Icon(
                        Icons.arrow_forward,
                        color: AppColors.textSecondary,
                        size: 20.0,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                  ],
                  if (trip.dropLocation != null)
                    Expanded(
                      child: _buildTripInfoRow(
                        icon: Icons.location_on,
                        label: 'Destination',
                        value: trip.dropLocation!.address ?? 'Location',
                        textTheme: textTheme,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Created: ${Helpers.formatDateTime(trip.createdAt)}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showAcceptButton &&
                onAcceptTrip != null &&
                onRejectTrip != null) ...[
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onAcceptTrip!(),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onRejectTrip!(),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.0, color: AppColors.textSecondary),
        const SizedBox(width: 8.0),
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case AppConstants.tripStatusBooked:
        return AppColors.primary;
      case AppConstants.tripStatusAccepted:
        return AppColors.primary;
      case AppConstants.tripStatusActive:
        return AppColors.info;
      case AppConstants.tripStatusCompleted:
        return AppColors.success;
      case AppConstants.tripStatusPodPending:
        return AppColors.warning;
      case AppConstants.tripStatusPlanned:
        return AppColors.textSecondary;
      case AppConstants.tripStatusCancelled:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

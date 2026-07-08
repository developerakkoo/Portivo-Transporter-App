import 'package:flutter/material.dart';
import '../core/constants/app_copy.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/helpers.dart';
import '../core/utils/trip_operational_locations.dart';
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
    this.onStartTrip,
    this.driverTrackingStatus,
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
  final Future<void> Function()? onStartTrip;

  /// Live driver tracking status (online, gps_off, offline, logged_out, stale)
  /// shown as a small badge on ACTIVE trips.
  final String? driverTrackingStatus;

  @override
  Widget build(BuildContext context) {
    final titleText = trip.containerNumber?.isNotEmpty == true
        ? trip.containerNumber!
        : (trip.tripId.isNotEmpty ? trip.tripId : 'Trip');

    // Pre-build subtitle string (trip ID · reference)
    final subtitleParts = <String>[];
    if (trip.tripId.isNotEmpty &&
        trip.containerNumber != null &&
        trip.containerNumber!.isNotEmpty) {
      subtitleParts.add(trip.tripId);
    }
    if (trip.reference != null && trip.reference!.isNotEmpty) {
      subtitleParts.add(trip.reference!);
    }
    final subtitleText =
        subtitleParts.isEmpty ? null : subtitleParts.join(' · ');

    return Container(
      key: Key('trip_expansion_${trip.id}'),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isHighlighted ? AppColors.success : AppColors.dividerGrey,
          width: isHighlighted ? 2.0 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top accent bar ──────────────────────────────────
          Container(
            height: 3.0,
            color: isHighlighted ? AppColors.success : AppColors.primary,
          ),

          // ── ExpansionTile ───────────────────────────────────
          Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              maintainState: true,
              tilePadding:
                  const EdgeInsets.fromLTRB(14.0, 6.0, 8.0, 6.0),
              childrenPadding:
                  const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 12.0),
              title: _buildHeader(titleText, subtitleText),
              trailing: _buildExpandIcon(),
              children: _buildExpandedBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String titleText, String? subtitleText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title row ───────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title block
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        subtitleText,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 6.0),

            // ── Trailing controls ──────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pin button
                if (showPinButton && onPinTap != null) ...[
                  _buildIconBtn(
                    icon: isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: isPinned
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    tooltip: isPinned ? 'Unpin' : 'Pin to home',
                    onTap: onPinTap!,
                    primary: false,
                  ),
                  const SizedBox(width: 2.0),
                ],

                // Begin Trip button (PLANNED only)
                if (trip.status == AppConstants.tripStatusPlanned &&
                    trip.canStartTrip &&
                    !trip.isQueuedBlocked &&
                    onStartTrip != null) ...[
                  FilledButton.icon(
                    onPressed: () => onStartTrip!(),
                    icon: const Icon(Icons.play_arrow, size: 14.0),
                    label: const Text(AppCopy.beginTrip),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 6.0,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2.0),
                ],

                // Detail chevron
                _buildIconBtn(
                  icon: Icons.chevron_right,
                  color: AppColors.primary,
                  tooltip: 'View details',
                  onTap: onOpenDetail,
                  primary: true,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8.0),

        // ── Badge row ─────────────────────────────────────
        Wrap(
          spacing: 6.0,
          runSpacing: 4.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Marketplace pill
            if (trip.isMarketplaceBookingTrip)
              _buildPill(
                label: 'Marketplace',
                color: AppColors.primary,
                icon: Icons.storefront_outlined,
              ),

            // Queued pill
            if (trip.isQueued)
              _buildPill(
                label: trip.queuePosition != null &&
                        trip.queuePosition! > 1
                    ? 'Queued #${trip.queuePosition}'
                    : 'Queued',
                color: AppColors.warning,
              ),

            // Status pill (always)
            _buildStatusPill(trip.status),

            // Trip type tag (always)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7.0,
                vertical: 3.0,
              ),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: AppColors.dividerGrey),
              ),
              child: Text(
                Helpers.getTripTypeLabel(trip.tripType),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10.0,
                ),
              ),
            ),

            // Live status badge (ACTIVE only)
            if (trip.status == AppConstants.tripStatusActive)
              _buildLiveStatusBadge(),
          ],
        ),
        if (trip.isQueuedBlocked) ...[
          const SizedBox(height: 6.0),
          Text(
            'Waiting for active trip to complete',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.warning,
              fontSize: 10.0,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandIcon() {
    return Padding(
      padding: const EdgeInsets.only(right: 2.0),
      child: Icon(
        Icons.keyboard_arrow_down,
        color: AppColors.textSecondary,
        size: 20.0,
      ),
    );
  }

  List<Widget> _buildExpandedBody() {
    return [
      // ── Route row ──────────────────────────────────────────
      if (TripOperationalLocations.visiblePoints(trip.tripType)
          .any((p) => TripOperationalLocations.readPoint(trip, p) != null)) ...[
        ..._buildOperationalRouteCards().map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: card,
          ),
        ),
        const SizedBox(height: 10.0),
      ],

      // ── Footer row: created date ───────────────────────────
      Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: AppColors.primary,
            size: 13.0,
          ),
          const SizedBox(width: 5.0),
          Expanded(
            child: Text(
              'Created: ${Helpers.formatDateTime(trip.createdAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),

      // ── Accept / Reject (Marketplace only) ─────────────────
      if (showAcceptButton &&
          onAcceptTrip != null &&
          onRejectTrip != null) ...[
        const SizedBox(height: 12.0),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 10.0),
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onRejectTrip!(),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10.0),
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildOperationalRouteCards() {
    final points = TripOperationalLocations.visiblePoints(trip.tripType);
    final cards = <Widget>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final location = TripOperationalLocations.readPoint(trip, point);
      if (location == null) continue;
      cards.add(
        _buildRouteCard(
          label: TripOperationalLocations.labelForPoint(trip.tripType, point),
          address: location.address ?? 'Location',
          isOrigin: i == 0,
        ),
      );
    }
    return cards;
  }

  Widget _buildRouteCard({
    required String label,
    required String address,
    required bool isOrigin,
  }) {
    final dotColor = isOrigin ? AppColors.primary : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 8.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label row with dot
          Row(
            children: [
              Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4.0),
              Text(
                label.toUpperCase(),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5.0),
          // Address
          Text(
            address,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 11.0,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return SizedBox(
      width: 30.0,
      height: 30.0,
      child: Material(
        color: primary
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(7.0),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 15.0, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.0,
            height: 5.0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4.0),
          Text(
            Helpers.getStatusLabel(status),
            style: textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.0, color: color),
            const SizedBox(width: 3.0),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusBadge() {
    final ({Color color, IconData icon, String label}) v;
    switch (driverTrackingStatus) {
      case 'online':
        v = (color: AppColors.success, icon: Icons.gps_fixed, label: 'Live');
        break;
      case 'gps_off':
        v = (color: AppColors.warning, icon: Icons.location_disabled, label: 'GPS off');
        break;
      case 'offline':
        v = (color: AppColors.warning, icon: Icons.wifi_off, label: 'Offline');
        break;
      case 'logged_out':
        v = (color: AppColors.error, icon: Icons.logout, label: 'Logged out');
        break;
      case 'stale':
        v = (color: AppColors.warning, icon: Icons.gps_not_fixed, label: 'Signal lost');
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: v.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: v.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(v.icon, size: 11, color: v.color),
          const SizedBox(width: 4),
          Text(
            v.label,
            style: textTheme.labelSmall?.copyWith(
              color: v.color,
              fontWeight: FontWeight.w600,
              fontSize: 10.0,
            ),
          ),
        ],
      ),
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

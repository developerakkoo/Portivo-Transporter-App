import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/helpers.dart';
import '../core/utils/trip_operational_locations.dart';
import '../data/models/trip_model.dart';
import '../providers/trip_provider.dart';

/// Bottom sheet to pick a saved draft or start a blank new trip.
/// Returns draft id for resume, empty string for blank trip, or null if dismissed.
class QuickTripStartSheet extends StatefulWidget {
  const QuickTripStartSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const QuickTripStartSheet(),
    );
  }

  @override
  State<QuickTripStartSheet> createState() => _QuickTripStartSheetState();
}

class _QuickTripStartSheetState extends State<QuickTripStartSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TripProvider>().loadDrafts(refresh: true);
    });
  }

  String _draftTitle(TripModel draft) {
    if (draft.customerName != null && draft.customerName!.isNotEmpty) {
      return draft.customerName!;
    }
    if (draft.reference != null && draft.reference!.isNotEmpty) {
      return draft.reference!;
    }
    if (draft.tripId.isNotEmpty) {
      return draft.tripId;
    }
    return 'Draft trip';
  }

  String _draftSubtitle(TripModel draft) {
    final parts = <String>[];
    final route = TripOperationalLocations.routeSummary(
      tripType: draft.tripType,
      pickup: draft.pickupLocation,
      intermediate: draft.intermediateLocation,
      drop: draft.dropLocation,
    );
    if (route != null && route.isNotEmpty) {
      parts.add(route);
    }
    if (draft.reference != null &&
        draft.reference!.isNotEmpty &&
        draft.customerName != null &&
        draft.customerName!.isNotEmpty) {
      parts.add(draft.reference!);
    }
    parts.add(Helpers.getTripTypeLabel(draft.tripType));
    parts.add(Helpers.formatDateTime(draft.updatedAt));
    return parts.join(' · ');
  }

  Future<void> _confirmDeleteDraft(
    BuildContext context,
    TripModel draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppCopy.deleteDraft),
        content: const Text(AppCopy.deleteDraftConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final tripProvider = context.read<TripProvider>();
    final success = await tripProvider.deleteDraft(draft.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Draft deleted'
              : (tripProvider.error ?? 'Failed to delete draft'),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              AppCopy.quickTripStart,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Pick a saved draft to auto-fill trip details, or start from scratch.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(''),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(AppCopy.startBlankTrip),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              AppCopy.savedDrafts,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: Consumer<TripProvider>(
              builder: (context, tripProvider, _) {
                if (tripProvider.isLoadingDrafts && tripProvider.draftTrips.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (tripProvider.draftTrips.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Text(
                      AppCopy.noDraftsYet,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  itemCount: tripProvider.draftTrips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final draft = tripProvider.draftTrips[index];
                    return Material(
                      color: AppColors.offWhite,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(draft.id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.drafts_outlined,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _draftTitle(draft),
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _draftSubtitle(draft),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.error,
                                tooltip: AppCopy.deleteDraft,
                                onPressed: () => _confirmDeleteDraft(context, draft),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

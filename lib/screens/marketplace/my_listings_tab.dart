import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../core/utils/vehicle_type_visual.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../services/vehicle_post_service.dart';
import '../../utils/error_utils.dart';
import 'my_listing_detail_screen.dart';
import 'post_availability_stepper_screen.dart';

/// My Listings tab: the transporter's availability posts filtered by
/// All / Active / Paused / Fully Booked, with Edit / Pause / Resume / View
/// Details per row.
class MarketplaceMyListingsTab extends StatefulWidget {
  const MarketplaceMyListingsTab({super.key});

  @override
  State<MarketplaceMyListingsTab> createState() =>
      _MarketplaceMyListingsTabState();
}

enum _ListingBucket { all, active, paused, fullyBooked }

class _MarketplaceMyListingsTabState extends State<MarketplaceMyListingsTab> {
  final _service = VehiclePostService();
  static final DateFormat _dateFmt = DateFormat.yMMMd();

  bool _loading = true;
  String? _error;
  List<VehiclePostModel> _items = [];
  _ListingBucket _bucket = _ListingBucket.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_items.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.userMessage(e);
        _loading = false;
      });
    }
  }

  /// Assignment bucket for a listing, or null when it belongs only under the
  /// catch-all `all` filter (cancelled or expired listings). Fully Booked
  /// takes precedence, then Paused, else Active (active/draft).
  _ListingBucket? _bucketOf(VehiclePostModel p) {
    final s = p.status?.toLowerCase().trim() ?? '';
    if (s == 'cancelled' || p.isExpired) return null;
    if (p.isFullyBooked) return _ListingBucket.fullyBooked;
    if (p.isPaused) return _ListingBucket.paused;
    return _ListingBucket.active;
  }

  bool _matchesFilter(VehiclePostModel p, _ListingBucket bucket) {
    if (bucket == _ListingBucket.all) return true;
    return _bucketOf(p) == bucket;
  }

  Future<void> _edit(VehiclePostModel p) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => PostAvailabilityStepperScreen(
          vehicleType: (p.vehicleType ?? '').trim(),
          existingPost: p,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _togglePause(VehiclePostModel p) async {
    try {
      if (p.isPaused) {
        await _service.resume(p.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post resumed — visible in search again')),
          );
        }
      } else {
        await _service.pause(p.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post paused — hidden from search')),
          );
        }
      }
      if (mounted) _load();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    }
  }

  Future<void> _openDetail(VehiclePostModel p) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (ctx) => MyListingDetailScreen(
          postId: p.id,
          initialPost: p,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading && _items.isEmpty) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final counts = {
      for (final b in _ListingBucket.values)
        b: _items.where((p) => _matchesFilter(p, b)).length,
    };
    final visible =
        _items.where((p) => _matchesFilter(p, _bucket)).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final b in _ListingBucket.values) ...[
                    _FilterChip(
                      label: '${_bucketLabel(b)} (${counts[b] ?? 0})',
                      selected: _bucket == b,
                      onTap: () => setState(() => _bucket = b),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 12),
            ],
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  switch (_bucket) {
                    _ListingBucket.all =>
                      'No listings yet. Use "Add Vehicle Type / Post Availability" below to add one.',
                    _ListingBucket.active => 'No active listings.',
                    _ListingBucket.paused => 'No paused listings.',
                    _ListingBucket.fullyBooked => 'No fully booked listings.',
                  },
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...visible.map((p) => _listingCard(context, p)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => DefaultTabController.of(context).animateTo(1),
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle Type / Post Availability'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _bucketLabel(_ListingBucket b) => switch (b) {
        _ListingBucket.all => 'All',
        _ListingBucket.active => 'Active',
        _ListingBucket.paused => 'Paused',
        _ListingBucket.fullyBooked => 'Fully Booked',
      };

  Widget _listingCard(BuildContext context, VehiclePostModel p) {
    final textTheme = Theme.of(context).textTheme;
    final visual = VehicleTypeVisual.forType(p.vehicleType);
    final canEdit = p.isEditableMarketplacePost && !p.isExpired;
    final available = p.slotsLeft ?? p.quantity ?? p.availableVehicles.length;
    final routeCount = p.routes.length;
    final lastUpdated = p.lastEdited ?? p.updatedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    visual.badge(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.vehicleType ?? '—',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusChip(context, p),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.routeDisplayLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AvailableBadge(count: available),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$routeCount route${routeCount == 1 ? '' : 's'}'
                  '${p.createdAt != null ? ' · Posted on ${_dateFmt.format(p.createdAt!)}' : ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                if (p.availableFrom != null)
                  _cardMetaRow(
                    context,
                    Icons.event_available_outlined,
                    'Available From',
                    _dateFmt.format(p.availableFrom!),
                  ),
                if (lastUpdated != null)
                  _cardMetaRow(
                    context,
                    Icons.update,
                    'Last Updated',
                    _dateFmt.format(lastUpdated),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
            child: Row(
              children: [
                if (canEdit)
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    onPressed: () => _edit(p),
                  ),
                if (canEdit && !p.isDraftListing)
                  TextButton.icon(
                    icon: Icon(
                      p.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 18,
                      color:
                          p.isPaused ? AppColors.success : AppColors.warning,
                    ),
                    label: Text(
                      p.isPaused ? 'Resume' : 'Pause',
                      style: TextStyle(
                        color:
                            p.isPaused ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    onPressed: () => _togglePause(p),
                  ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View Details'),
                  onPressed: () => _openDetail(p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMetaRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, VehiclePostModel p) {
    final textTheme = Theme.of(context).textTheme;
    final s = p.status?.toLowerCase().trim() ?? '';
    final String label;
    final Color color;
    if (p.isPaused) {
      label = 'PAUSED';
      color = AppColors.warning;
    } else if (p.isDraftListing) {
      label = 'DRAFT';
      color = AppColors.textSecondary;
    } else if (p.isExpired) {
      label = 'EXPIRED';
      color = AppColors.textMuted;
    } else if (p.isFullyBooked) {
      label = 'FULLY BOOKED';
      color = AppColors.info;
    } else if (s == 'cancelled') {
      label = 'CANCELLED';
      color = AppColors.textMuted;
    } else {
      label = 'ACTIVE';
      color = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Pill-style filter used for the All / Active / Paused / Fully Booked tabs.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.offWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.dividerGrey,
          ),
        ),
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Top-right "Available: N" badge on a listing card.
class _AvailableBadge extends StatelessWidget {
  const _AvailableBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Available',
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        Text(
          '$count',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

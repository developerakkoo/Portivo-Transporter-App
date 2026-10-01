import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../core/utils/vehicle_type_visual.dart';
import '../../data/models/vehicle_post_activity_model.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../services/vehicle_post_service.dart';
import '../../utils/error_utils.dart';
import 'marketplace_route_rate_tile.dart';
import 'post_availability_stepper_screen.dart';
import 'route_rate_editor.dart';

/// Owner-only listing detail with Overview / Routes & Rates / Activity tabs.
/// Opened from the My Listings tab "View Details" action.
class MyListingDetailScreen extends StatefulWidget {
  const MyListingDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  final String postId;
  final VehiclePostModel? initialPost;

  @override
  State<MyListingDetailScreen> createState() => _MyListingDetailScreenState();
}

class _MyListingDetailScreenState extends State<MyListingDetailScreen> {
  final _service = VehiclePostService();
  static final DateFormat _dateFmt = DateFormat.yMMMd();
  static final DateFormat _dateTimeFmt = DateFormat('d MMM yyyy, h:mm a');

  VehiclePostModel? _post;
  List<VehiclePostActivity> _activities = [];

  bool _loading = true;
  bool _activityLoading = true;
  String? _error;
  String? _activityError;

  /// True while an owner action (pause/resume/route edit) is in flight.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_post == null) _loading = true;
      _error = null;
    });
    try {
      final post = await _service.fetchById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.userMessage(e);
        _loading = false;
      });
    }
    await _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() {
      _activityLoading = true;
      _activityError = null;
    });
    try {
      final acts = await _service.fetchActivity(widget.postId);
      if (!mounted) return;
      setState(() {
        _activities = acts;
        _activityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activityError = ErrorUtils.userMessage(e);
        _activityLoading = false;
      });
    }
  }

  // ---- Owner actions -------------------------------------------------------

  Future<void> _edit() async {
    final p = _post;
    if (p == null) return;
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

  Future<void> _togglePause() async {
    final p = _post;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = p.isPaused
          ? await _service.resume(p.id)
          : await _service.pause(p.id);
      if (!mounted) return;
      setState(() => _post = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isPaused
                ? 'Listing paused — hidden from search'
                : 'Listing resumed — visible in search again',
          ),
        ),
      );
      await _loadActivity();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final p = _post;
    if (p == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel listing?'),
        content: const Text(
          'This listing will be removed from the marketplace. '
          'Other transporters will no longer see or book it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Listing',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.cancel(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing removed from marketplace')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    }
  }

  /// Persist a modified routes list via update() using the current post's
  /// required fields. Used by Add Route / per-route Edit.
  Future<void> _saveRoutes(List<MarketplaceRouteRate> routes) async {
    final p = _post;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _service.update(
        p.id,
        vehicleType: (p.vehicleType ?? '').trim(),
        originAddress: p.origin,
        originLocation: p.originLocation,
        availableFrom: p.availableFrom ?? DateTime.now(),
        availableTo: p.availableTo,
        routes: routes,
        acceptsOtherDestinations: p.acceptsOtherDestinations,
      );
      if (!mounted) return;
      setState(() => _post = updated);
      await _loadActivity();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addRoute() async {
    final p = _post;
    if (p == null) return;
    final draft = await showRouteRateEditor(context);
    if (draft == null || !mounted) return;
    final routes = List<MarketplaceRouteRate>.from(p.routes)
      ..add(MarketplaceRouteRate(
        destination: draft.destination,
        destinationLocation: draft.destinationLocation,
        exportRate: draft.exportRate,
        importRate: draft.importRate,
      ));
    await _saveRoutes(routes);
  }

  Future<void> _editRoute(int index) async {
    final p = _post;
    if (p == null || index < 0 || index >= p.routes.length) return;
    final existing = p.routes[index];
    final draft = await showRouteRateEditor(
      context,
      initial: RouteDraft(
        destination: existing.destination,
        destinationLocation: existing.destinationLocation,
        exportRate: existing.exportRate,
        importRate: existing.importRate,
      ),
    );
    if (draft == null || !mounted) return;
    final routes = List<MarketplaceRouteRate>.from(p.routes);
    routes[index] = MarketplaceRouteRate(
      destination: draft.destination,
      destinationLocation: draft.destinationLocation,
      exportRate: draft.exportRate,
      importRate: draft.importRate,
    );
    await _saveRoutes(routes);
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = _post;

    if (_loading && p == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Listing not found'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final routeCount = p.routes.length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          title: Row(
            children: [
              Flexible(
                child: Text(
                  p.vehicleType ?? 'Listing',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(post: p),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _edit();
                    break;
                  case 'pause':
                    _togglePause();
                    break;
                  case 'cancel':
                    _cancel();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (p.isEditableMarketplacePost)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!p.isDraftListing &&
                    (p.isPaused || p.isActiveListing) &&
                    !p.isExpired)
                  PopupMenuItem(
                    value: 'pause',
                    child: Text(p.isPaused ? 'Resume' : 'Pause'),
                  ),
                if (p.isEditableMarketplacePost)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel Listing'),
                  ),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'Overview'),
              Tab(text: 'Routes & Rates ($routeCount)'),
              const Tab(text: 'Activity'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(
              post: p,
              busy: _busy,
              dateFmt: _dateFmt,
              onEdit: _edit,
              onTogglePause: _togglePause,
            ),
            _RoutesTab(
              post: p,
              busy: _busy,
              onAddRoute: _addRoute,
              onEditRoute: _editRoute,
            ),
            _ActivityTab(
              activities: _activities,
              loading: _activityLoading,
              error: _activityError,
              dateTimeFmt: _dateTimeFmt,
              onRetry: _loadActivity,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.post});

  final VehiclePostModel post;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (post.isPaused) {
      label = 'PAUSED';
      color = AppColors.warning;
    } else if (post.isDraftListing) {
      label = 'DRAFT';
      color = AppColors.textSecondary;
    } else if (post.isExpired) {
      label = 'EXPIRED';
      color = AppColors.textMuted;
    } else if (post.isFullyBooked) {
      label = 'FULLY BOOKED';
      color = AppColors.info;
    } else if ((post.status?.toLowerCase().trim() ?? '') == 'cancelled') {
      label = 'CANCELLED';
      color = AppColors.textMuted;
    } else {
      label = 'ACTIVE';
      color = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: child,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview tab
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.post,
    required this.busy,
    required this.dateFmt,
    required this.onEdit,
    required this.onTogglePause,
  });

  final VehiclePostModel post;
  final bool busy;
  final DateFormat dateFmt;
  final VoidCallback onEdit;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visual = VehicleTypeVisual.forType(post.vehicleType);
    final available = post.slotsLeft ?? post.quantity ?? 0;
    final vehiclesAttached = post.availableVehicles.length;
    final routeCount = post.routes.length;
    final lastUpdated = post.lastEdited ?? post.updatedAt;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Available quantity highlight
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Quantity (Common Pool)',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$available',
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    available == 1 ? 'vehicle available' : 'vehicles available',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Movement + details
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  visual.badge(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.vehicleType ?? '—',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.routeDisplayLine,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _MetaRow(
                icon: Icons.local_shipping_outlined,
                label: 'Vehicles Attached',
                value:
                    '$vehiclesAttached vehicle${vehiclesAttached == 1 ? '' : 's'}',
              ),
              _MetaRow(
                icon: Icons.alt_route_outlined,
                label: 'Routes',
                value: '$routeCount route${routeCount == 1 ? '' : 's'}',
              ),
              if (post.availableFrom != null)
                _MetaRow(
                  icon: Icons.event_available_outlined,
                  label: 'Available From',
                  value: dateFmt.format(post.availableFrom!),
                ),
              if (post.availableTo != null)
                _MetaRow(
                  icon: Icons.event_busy_outlined,
                  label: 'Available Until',
                  value: dateFmt.format(post.availableTo!),
                ),
              if (lastUpdated != null)
                _MetaRow(
                  icon: Icons.update,
                  label: 'Last Updated',
                  value: dateFmt.format(lastUpdated),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Actions
        if (post.isEditableMarketplacePost)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              if (!post.isDraftListing && !post.isExpired) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onTogglePause,
                    icon: Icon(
                      post.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 18,
                    ),
                    label: Text(post.isPaused ? 'Resume' : 'Pause'),
                    style: FilledButton.styleFrom(
                      backgroundColor: post.isPaused
                          ? AppColors.success
                          : AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 12),
        const _InfoNote(
          'This is your common vehicle pool. Vehicles are shared across all '
          'routes on this listing until booked.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Routes & Rates tab
// ---------------------------------------------------------------------------

class _RoutesTab extends StatelessWidget {
  const _RoutesTab({
    required this.post,
    required this.busy,
    required this.onAddRoute,
    required this.onEditRoute,
  });

  final VehiclePostModel post;
  final bool busy;
  final VoidCallback onAddRoute;
  final ValueChanged<int> onEditRoute;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'All rates are per container',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (post.isEditableMarketplacePost)
              TextButton.icon(
                onPressed: busy ? null : onAddRoute,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Route'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (post.routes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No routes added yet. Use "Add Route" to define destinations and rates.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (var i = 0; i < post.routes.length; i++)
            MarketplaceRouteRateTile(
              destination: post.routes[i].destination,
              exportRate: post.routes[i].exportRate,
              importRate: post.routes[i].importRate,
              onEdit: post.isEditableMarketplacePost && !busy
                  ? () => onEditRoute(i)
                  : null,
            ),
        if (post.acceptsOtherDestinations)
          const MarketplaceRouteRateTile(
            destination: 'Any Other Destination',
            exportRate: null,
            importRate: null,
            alwaysNegotiable: true,
          ),
        const SizedBox(height: 12),
        const _InfoNote(
          'Rates shown are indicative. Buyers can negotiate before booking.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Activity tab
// ---------------------------------------------------------------------------

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.activities,
    required this.loading,
    required this.error,
    required this.dateTimeFmt,
    required this.onRetry,
  });

  final List<VehiclePostActivity> activities;
  final bool loading;
  final String? error;
  final DateFormat dateTimeFmt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (loading && activities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No activity yet. Changes to this listing will appear here.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < activities.length; i++)
          _TimelineRow(
            activity: activities[i],
            isFirst: i == 0,
            isLast: i == activities.length - 1,
            dateTimeFmt: dateTimeFmt,
          ),
        const SizedBox(height: 12),
        const _InfoNote(
          'Activity is recorded from the time this feature was enabled. Older '
          'changes may not be shown.',
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.activity,
    required this.isFirst,
    required this.isLast,
    required this.dateTimeFmt,
  });

  final VehiclePostActivity activity;
  final bool isFirst;
  final bool isLast;
  final DateFormat dateTimeFmt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = activity.subtitle;
    final actor = activity.actorName;
    final created = activity.createdAt;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          Column(
            children: [
              Container(
                width: 2,
                height: 6,
                color: isFirst ? Colors.transparent : AppColors.dividerGrey,
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(activity.icon,
                    size: 18, color: AppColors.success),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : AppColors.dividerGrey,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (actor != null && actor.trim().isNotEmpty)
                        'By $actor',
                      if (created != null) dateTimeFmt.format(created.toLocal()),
                    ].join('  ·  '),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

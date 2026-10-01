import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../core/utils/vehicle_type_visual.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/vehicle_post_service.dart';
import '../../utils/error_utils.dart';
import 'post_availability_stepper_screen.dart';

/// "Your Fleet" tab: fleet vehicles grouped by type, one availability post per
/// type. Types without an open post get a Post Availability button; types with
/// one get Edit Availability plus Pause/Resume and Delete.
class MarketplaceFleetPostTab extends StatefulWidget {
  const MarketplaceFleetPostTab({super.key});

  @override
  State<MarketplaceFleetPostTab> createState() =>
      _MarketplaceFleetPostTabState();
}

class _MarketplaceFleetPostTabState extends State<MarketplaceFleetPostTab> {
  final _service = VehiclePostService();
  bool _loading = true;
  String? _error;
  List<VehiclePostModel> _posts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VehicleProvider>().loadVehicles();
      _loadPosts();
    });
  }

  Future<void> _loadPosts() async {
    setState(() {
      if (_posts.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _posts = list;
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

  Future<void> _refresh() async {
    await Future.wait([
      context.read<VehicleProvider>().loadVehicles(refresh: true),
      _loadPosts(),
    ]);
  }

  /// The open (draft/active/paused, non-expired) post for a type, if any —
  /// the "one post per vehicle type" rule keys off this.
  VehiclePostModel? _openPostForType(String type) {
    for (final p in _posts) {
      if ((p.vehicleType ?? '').trim() != type) continue;
      if (p.isEditableMarketplacePost && !p.isExpired) return p;
    }
    return null;
  }

  Future<void> _openStepper(String type, {VehiclePostModel? existing}) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => PostAvailabilityStepperScreen(
          vehicleType: type,
          existingPost: existing,
        ),
      ),
    );
    if (!mounted) return;
    await _loadPosts();
    if (!mounted) return;
    if (result == PostAvailabilityStepperScreen.resultViewListings) {
      DefaultTabController.of(context).animateTo(2);
    }
  }

  Future<void> _togglePause(VehiclePostModel post) async {
    try {
      if (post.isPaused) {
        await _service.resume(post.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post resumed — visible in search again')),
          );
        }
      } else {
        await _service.pause(post.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post paused — hidden from search')),
          );
        }
      }
      if (mounted) await _loadPosts();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    }
  }

  Future<void> _deletePost(VehiclePostModel post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text(
          'The ${post.vehicleType ?? ''} availability post will be removed from '
          'the marketplace. You can post this vehicle type again afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.cancel(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted')),
      );
      await _loadPosts();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Consumer<VehicleProvider>(
        builder: (context, vp, _) {
          // Fleet count per vehicle type (active owned vehicles).
          final counts = <String, int>{};
          for (final v in vp.vehicles) {
            if (v.status.toLowerCase() != 'active' || v.ownerType != 'OWN') {
              continue;
            }
            final t = v.vehicleType?.trim() ?? '';
            if (t.isEmpty) continue;
            counts[t] = (counts[t] ?? 0) + 1;
          }
          // Types with an open post but no (remaining) fleet vehicles still
          // need a card so the post stays manageable.
          for (final p in _posts) {
            final t = (p.vehicleType ?? '').trim();
            if (t.isEmpty) continue;
            if (p.isEditableMarketplacePost && !p.isExpired) {
              counts.putIfAbsent(t, () => 0);
            }
          }
          final types = counts.keys.toList()..sort();

          if ((_loading && _posts.isEmpty) ||
              (vp.isLoading && vp.vehicles.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Your Fleet',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Post availability per vehicle type. Buyers see your routes and rates.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 20, color: AppColors.info),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Create a separate post for each vehicle type. One post per type — edit, pause or delete it anytime.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                ],
                if (types.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Icon(Icons.local_shipping_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No active owned vehicles in your fleet yet.\nAdd vehicles first, then post their availability here.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...types.map((t) => _typeCard(context, t, counts[t] ?? 0)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _typeCard(BuildContext context, String type, int fleetCount) {
    final textTheme = Theme.of(context).textTheme;
    final visual = VehicleTypeVisual.forType(type);
    final post = _openPostForType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              visual.badge(size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Available in Fleet: $fleetCount',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (post != null) _statusChip(context, post),
            ],
          ),
          const SizedBox(height: 14),
          if (post == null)
            FilledButton.icon(
              onPressed: () => _openStepper(type),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Post Availability'),
              style: FilledButton.styleFrom(
                backgroundColor: visual.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openStepper(type, existing: post),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Availability'),
                  ),
                ),
                if (!post.isDraftListing) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: post.isPaused ? 'Resume' : 'Pause',
                    onPressed: () => _togglePause(post),
                    icon: Icon(
                      post.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: post.isPaused
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Delete',
                  onPressed: () => _deletePost(post),
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, VehiclePostModel post) {
    final textTheme = Theme.of(context).textTheme;
    final String label;
    final Color color;
    if (post.isPaused) {
      label = 'PAUSED';
      color = AppColors.warning;
    } else if (post.isDraftListing) {
      label = 'DRAFT';
      color = AppColors.textSecondary;
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

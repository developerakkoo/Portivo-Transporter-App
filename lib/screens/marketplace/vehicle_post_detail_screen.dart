import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../utils/error_utils.dart';
import '../../providers/auth_provider.dart';
import '../../services/vehicle_post_service.dart';
import 'edit_vehicle_post_screen.dart';
import 'marketplace_booking_actions.dart';
import 'marketplace_route_rate_tile.dart';

class VehiclePostDetailScreen extends StatefulWidget {
  const VehiclePostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.searchedOrigin,
    this.searchedDestination,
  });

  final String postId;
  final VehiclePostModel? initialPost;

  /// Optional origin/destination the user searched for. When present, the
  /// matching route is highlighted as the "Searched Route".
  final String? searchedOrigin;
  final String? searchedDestination;

  @override
  State<VehiclePostDetailScreen> createState() => _VehiclePostDetailScreenState();
}

class _VehiclePostDetailScreenState extends State<VehiclePostDetailScreen> {
  final _service = VehiclePostService();
  VehiclePostModel? _post;
  bool _loading = false;
  String? _error;
  bool _cancelling = false;

  /// Whether the full "All Routes" list is expanded (vs. first few + "more").
  bool _showAllRoutes = false;

  static const int _routesPreviewCount = 3;

  /// Finds the route index best matching the searched destination, or -1.
  int _searchedRouteIndex(VehiclePostModel p) {
    final q = widget.searchedDestination?.trim().toLowerCase();
    if (q == null || q.isEmpty) return -1;
    for (var i = 0; i < p.routes.length; i++) {
      if (p.routes[i].destination.toLowerCase().contains(q)) return i;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _service.fetchById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.userMessage(
          e,
          fallback: 'This listing is no longer available',
        );
        _loading = false;
      });
    }
  }

  bool _isOwner(AuthProvider auth) {
    final u = auth.user;
    if (u == null || _post?.transporterId == null) return false;
    final self = u.transporterId ?? u.id;
    return _post!.transporterId == self;
  }

  Future<void> _callMobile(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return;
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: raw));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number copied to clipboard')),
        );
      }
    }
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel listing?'),
        content: const Text(
          'This availability post will be marked as cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await _service.cancel(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = updated;
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing cancelled')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  String _transporterInitials(VehiclePostModel p) {
    final source =
        (p.transporterCompany ?? p.transporterName ?? '').trim();
    if (source.isEmpty) return '?';
    final parts =
        source.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd();
    final p = _post;
    final searchedIdx = p == null ? -1 : _searchedRouteIndex(p);
    final showSearchedRoute = (widget.searchedOrigin != null &&
            widget.searchedOrigin!.trim().isNotEmpty) ||
        (widget.searchedDestination != null &&
            widget.searchedDestination!.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Availability details'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final post = _post;
              if (post == null) return const SizedBox.shrink();
              if (!_isOwner(auth) || !post.isActiveListing) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: _loading
                    ? null
                    : () async {
                        final updated =
                            await Navigator.push<VehiclePostModel>(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => EditVehiclePostScreen(
                              postId: widget.postId,
                              initialPost: post,
                            ),
                          ),
                        );
                        if (updated != null && mounted) {
                          setState(() => _post = updated);
                        }
                      },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && p == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This listing may have been booked or removed.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to marketplace'),
                        ),
                      ],
                    ),
                  ),
                )
              : p == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (_loading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (p.status != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Chip(
                              label: Text(
                                p.status!.toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: p.isPublishedOnMarketplace
                                  ? Colors.green.shade50
                                  : p.isDraftListing
                                      ? Colors.orange.shade50
                                      : Colors.grey.shade200,
                            ),
                          ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            final owner = _isOwner(auth);
                            if (!owner) return const SizedBox.shrink();
                            if (!p.isDraftListing &&
                                p.availableVehicles.isNotEmpty) {
                              return const SizedBox.shrink();
                            }
                            if (!p.isDraftListing &&
                                p.availableVehicles.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'No fleet vehicles on this listing. Add vehicles so buyers can chat or negotiate.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Draft: not visible in marketplace search until you add at least one fleet vehicle.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Transporter header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.12),
                              child: Text(
                                _transporterInitials(p),
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          p.transporterCompany ??
                                              p.transporterName ??
                                              'Transporter',
                                          style:
                                              textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (kMarketplacePlaceholderVerified) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified,
                                            size: 18, color: AppColors.success),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          size: 16, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$kMarketplacePlaceholderRating '
                                        '($kMarketplacePlaceholderReviews)',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          kMarketplacePlaceholderYears,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (p.transporterMobile != null &&
                                p.transporterMobile!.trim().isNotEmpty)
                              IconButton(
                                tooltip: 'Call transporter',
                                icon: const Icon(Icons.call_outlined),
                                color: AppColors.primary,
                                onPressed: () =>
                                    _callMobile(p.transporterMobile),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Fleet Size',
                          value: '$kMarketplacePlaceholderFleetSize Vehicles',
                        ),
                        _DetailRow(
                          label: 'Base Location',
                          value: kMarketplacePlaceholderBaseLocation,
                        ),
                        _DetailRow(
                          label: 'Responds in',
                          value: kMarketplacePlaceholderResponse,
                        ),
                        const Divider(height: 32),
                        // Vehicle + availability
                        Text(
                          p.routeDisplayLine,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Vehicle type',
                          value: p.vehicleType ?? '—',
                        ),
                        if (p.vehicleNumber != null ||
                            p.vehicleTrailerType != null)
                          _DetailRow(
                            label: 'Fleet vehicle',
                            value: [
                              if (p.vehicleNumber != null) p.vehicleNumber,
                              if (p.vehicleTrailerType != null)
                                p.vehicleTrailerType,
                            ].join(' · '),
                          ),
                        _DetailRow(
                          label: 'Available',
                          value: '${p.availableVehicles.length} '
                              '${p.availableVehicles.length == 1 ? 'Vehicle' : 'Vehicles'}',
                        ),
                        if (p.quantity != null)
                          _DetailRow(
                            label: 'Quantity (total)',
                            value: '${p.quantity}',
                          ),
                        if (p.destinationQuantities.isNotEmpty)
                          _DetailRow(
                            label: 'Per-stop quotas',
                            value: p.destinationStops.isEmpty
                                ? p.destinationQuantities.join(', ')
                                : List.generate(
                                    math.min(
                                      p.destinationStops.length,
                                      p.destinationQuantities.length,
                                    ),
                                    (i) =>
                                        '${p.destinationStops[i]}: ${p.destinationQuantities[i]}',
                                  ).join('; '),
                          ),
                        _DetailRow(
                          label: 'Available From',
                          value: [
                            if (p.availableFrom != null)
                              dateFmt.format(p.availableFrom!),
                            if (p.availableTo != null)
                              dateFmt.format(p.availableTo!),
                          ].join(' – '),
                        ),
                        // Searched route highlight
                        if (showSearchedRoute) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.my_location,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Searched Route',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${widget.searchedOrigin ?? p.origin} \u2192 '
                                  '${widget.searchedDestination ?? (p.destination ?? '—')}',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (searchedIdx >= 0)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Export: ${marketplaceRateText(p.routes[searchedIdx].exportRate)}',
                                          style: textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Import: ${marketplaceRateText(p.routes[searchedIdx].importRate)}',
                                          style: textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    'See all routes below for rates.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (p.note != null && p.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _DetailRow(label: 'Note', value: p.note!),
                        ],
                        // All routes
                        if (p.routes.isNotEmpty ||
                            p.acceptsOtherDestinations) ...[
                          const Divider(height: 32),
                          Text(
                            'All Routes (${p.routes.length}'
                            '${p.acceptsOtherDestinations ? '+' : ''})',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (var i = 0;
                              i <
                                  (_showAllRoutes
                                      ? p.routes.length
                                      : math.min(_routesPreviewCount,
                                          p.routes.length));
                              i++)
                            MarketplaceRouteRateTile(
                              destination: p.routes[i].destination,
                              exportRate: p.routes[i].exportRate,
                              importRate: p.routes[i].importRate,
                              highlight: i == searchedIdx,
                            ),
                          if (!_showAllRoutes &&
                              p.routes.length > _routesPreviewCount)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _showAllRoutes = true),
                                child: Text(
                                  '+${p.routes.length - _routesPreviewCount} more routes',
                                ),
                              ),
                            ),
                          if (_showAllRoutes &&
                              p.routes.length > _routesPreviewCount)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _showAllRoutes = false),
                                child: const Text('Show less'),
                              ),
                            ),
                          if (p.acceptsOtherDestinations)
                            const MarketplaceRouteRateTile(
                              destination: 'Any Other Destination',
                              exportRate: null,
                              importRate: null,
                              alwaysNegotiable: true,
                            ),
                        ],
                        if (p.createdAt != null || p.lastEdited != null) ...[
                          const Divider(height: 32),
                          if (p.createdAt != null)
                            _DetailRow(
                              label: 'Listed',
                              value: Helpers.formatDateTime(p.createdAt!),
                            ),
                          if (p.lastEdited != null)
                            _DetailRow(
                              label: 'Last updated',
                              value: Helpers.formatDateTime(p.lastEdited!),
                            ),
                        ],
                        const SizedBox(height: 20),
                        // Owner: cancel listing
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            final owner = _isOwner(auth);
                            if (!owner || !p.isActiveListing) {
                              return const SizedBox.shrink();
                            }
                            return OutlinedButton.icon(
                              onPressed: _cancelling ? null : _confirmCancel,
                              icon: _cancelling
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel my listing'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                            );
                          },
                        ),
                        // Buyer: Chat / Offer
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (marketplaceIsOwnPost(p, auth)) {
                              return const SizedBox.shrink();
                            }
                            final noVehicles = p.availableVehicles.isEmpty;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (noVehicles)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      'This listing has no fleet vehicles yet.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: noVehicles
                                            ? null
                                            : () => startMarketplaceChat(
                                                  context,
                                                  p,
                                                ),
                                        icon: const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 18),
                                        label: const Text('Chat'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: noVehicles
                                            ? null
                                            : () => openMarketplaceNegotiate(
                                                  context,
                                                  p,
                                                ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(
                                            Icons.payments_outlined,
                                            size: 18),
                                        label: const Text('Offer'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

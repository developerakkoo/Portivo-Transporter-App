import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/vehicle_post_service.dart';
import 'edit_vehicle_post_screen.dart';

class VehiclePostDetailScreen extends StatefulWidget {
  const VehiclePostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  final String postId;
  final VehiclePostModel? initialPost;

  @override
  State<VehiclePostDetailScreen> createState() => _VehiclePostDetailScreenState();
}

class _VehiclePostDetailScreenState extends State<VehiclePostDetailScreen> {
  final _service = VehiclePostService();
  VehiclePostModel? _post;
  bool _loading = false;
  String? _error;
  bool _cancelling = false;

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
        _error = e.toString().replaceFirst('Exception: ', '');
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd();
    final p = _post;

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
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
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
                        Text(
                          p.routeDisplayLine,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
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
                          label: 'Available',
                          value: [
                            if (p.availableFrom != null)
                              dateFmt.format(p.availableFrom!),
                            if (p.availableTo != null)
                              dateFmt.format(p.availableTo!),
                          ].join(' – '),
                        ),
                        if (p.note != null && p.note!.isNotEmpty)
                          _DetailRow(label: 'Note', value: p.note!),
                        const Divider(height: 32),
                        Text(
                          'Transporter',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (p.transporterCompany != null)
                          _DetailRow(
                            label: 'Company',
                            value: p.transporterCompany!,
                          ),
                        if (p.transporterName != null)
                          _DetailRow(
                            label: 'Name',
                            value: p.transporterName!,
                          ),
                        
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
                        const SizedBox(height: 24),
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

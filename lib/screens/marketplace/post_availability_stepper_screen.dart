import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../core/utils/vehicle_type_visual.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/vehicle_post_service.dart';
import '../location_picker_screen.dart';
import 'route_rate_editor.dart';

/// Post / Edit Availability wizard for a single (locked) vehicle type.
///
/// Step 1 — Basic Details: available-vehicles counter (capped at fleet count)
/// and Available From date. Step 2 — Routes & Rates. Submitting creates the
/// post (or updates it in edit mode) and auto-attaches fleet vehicles of the
/// type so the listing publishes immediately. Step 3 is the success screen.
///
/// Pops with [resultViewListings] or [resultPostAnother] so the caller can
/// switch to My Listings or stay on the fleet list.
class PostAvailabilityStepperScreen extends StatefulWidget {
  const PostAvailabilityStepperScreen({
    super.key,
    required this.vehicleType,
    this.existingPost,
  });

  final String vehicleType;

  /// When set, the wizard edits this post instead of creating a new one.
  final VehiclePostModel? existingPost;

  static const String resultViewListings = 'view_listings';
  static const String resultPostAnother = 'post_another';

  @override
  State<PostAvailabilityStepperScreen> createState() =>
      _PostAvailabilityStepperScreenState();
}

class _PostAvailabilityStepperScreenState
    extends State<PostAvailabilityStepperScreen> {
  static const int _kDefaultDurationDays = 30;

  final _service = VehiclePostService();
  final _originCtrl = TextEditingController();
  TripLocation? _originLocation;

  static final NumberFormat _inrFmt = NumberFormat.decimalPattern('en_IN');
  static final DateFormat _dateFmt = DateFormat.yMMMd();

  /// 0 = Basic Details, 1 = Routes & Rates, 2 = Posted Successfully.
  int _step = 0;
  int _qty = 1;
  DateTime _availableFrom = DateTime.now();
  final List<RouteDraft> _routes = [];
  bool _acceptsOtherDestinations = false;
  bool _submitting = false;

  /// Vehicle ids already attached to the post (edit mode).
  late final Set<String> _initialAttachedIds;

  /// The created/updated post shown on the success step.
  VehiclePostModel? _result;

  bool get _isEdit => widget.existingPost != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPost;
    _initialAttachedIds = p == null
        ? <String>{}
        : p.availableVehicles
            .map((a) => a.vehicleId)
            .whereType<String>()
            .toSet();
    if (p != null) {
      _originCtrl.text = p.origin;
      _originLocation = p.originLocation;
      _qty = (p.quantity ?? 1).clamp(1, 9999);
      _availableFrom = p.availableFrom ?? DateTime.now();
      _acceptsOtherDestinations = p.acceptsOtherDestinations;
      for (final r in p.routes) {
        _routes.add(
          RouteDraft(
            destination: r.destination,
            destinationLocation: r.destinationLocation,
            exportRate: r.exportRate,
            importRate: r.importRate,
          ),
        );
      }
      // Legacy post without routes: seed a route from its destination.
      if (_routes.isEmpty) {
        final legacyDest = (p.destination ?? '').trim();
        if (legacyDest.isNotEmpty) {
          _routes.add(
            RouteDraft(
              destination: legacyDest,
              destinationLocation: p.destinationLocation,
              exportRate: p.pricePerVehicle,
            ),
          );
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VehicleProvider>().loadVehicles();
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    super.dispose();
  }

  /// Active owned fleet vehicles usable on this post: exact type match first,
  /// then untyped vehicles (assignable to any listing type).
  List<VehicleModel> _eligibleFleetVehicles(VehicleProvider vp) {
    final type = widget.vehicleType.trim();
    final typed = <VehicleModel>[];
    final untyped = <VehicleModel>[];
    for (final v in vp.vehicles) {
      if (v.status.toLowerCase() != 'active' || v.ownerType != 'OWN') continue;
      final vt = v.vehicleType?.trim() ?? '';
      if (vt == type) {
        typed.add(v);
      } else if (vt.isEmpty) {
        untyped.add(v);
      }
    }
    return [...typed, ...untyped];
  }

  int _maxQty(VehicleProvider vp) {
    final fleet = _eligibleFleetVehicles(vp).length;
    // In edit mode never cap below the already-posted quantity.
    final floor = _isEdit ? (widget.existingPost!.quantity ?? 1) : 1;
    final max = fleet > floor ? fleet : floor;
    return max < 1 ? 1 : max;
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _availableFrom = picked);
  }

  Future<void> _addOrEditRoute({int? index}) async {
    final existing = index == null ? null : _routes[index];
    final result = await showRouteRateEditor(context, initial: existing);
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _routes.add(result);
      } else {
        _routes[index] = result;
      }
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _hasOriginCoordinates() {
    final loc = _originLocation;
    if (loc == null) return false;
    final lat = loc.coordinates.latitude;
    final lng = loc.coordinates.longitude;
    return !(lat == 0 && lng == 0);
  }

  Future<void> _pickOriginLocation() async {
    final result = await Navigator.push<TripLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          isPickup: true,
          appBarTitle: 'Current Location',
          initialQuery:
              _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _originLocation = result;
      _originCtrl.text = result.address ?? '';
    });
  }

  void _onNext() {
    if (_originCtrl.text.trim().isEmpty || !_hasOriginCoordinates()) {
      _snack('Pick your current location on the map');
      return;
    }
    if (_qty < 1) {
      _snack('Available vehicles must be at least 1');
      return;
    }
    setState(() => _step = 1);
  }

  bool _allRoutesHaveCoordinates() {
    if (_routes.isEmpty) return true;
    return _routes.every((r) => r.hasDestinationCoordinates);
  }

  Future<void> _submit() async {
    if (_routes.isEmpty && !_acceptsOtherDestinations) {
      _snack('Add at least one route or enable "Any Other Destination"');
      return;
    }
    if (!_allRoutesHaveCoordinates()) {
      _snack('Each route needs a map-picked destination');
      return;
    }

    final routes = _routes
        .map(
          (r) => MarketplaceRouteRate(
            destination: r.destination,
            destinationLocation: r.destinationLocation,
            exportRate: r.exportRate,
            importRate: r.importRate,
          ),
        )
        .toList();

    final vp = context.read<VehicleProvider>();
    final eligible = _eligibleFleetVehicles(vp);

    setState(() => _submitting = true);
    try {
      VehiclePostModel? post;
      if (_isEdit) {
        post = await _service.update(
          widget.existingPost!.id,
          vehicleType: widget.vehicleType,
          originAddress: _originCtrl.text.trim(),
          originLocation: _originLocation,
          availableFrom: _availableFrom,
          durationDays: _kDefaultDurationDays,
          quantity: _qty,
          routes: routes,
          acceptsOtherDestinations: _acceptsOtherDestinations,
        );
      } else {
        post = await _service.create(
          vehicleType: widget.vehicleType,
          originAddress: _originCtrl.text.trim(),
          originLocation: _originLocation,
          availableFrom: _availableFrom,
          durationDays: _kDefaultDurationDays,
          quantity: _qty,
          routes: routes,
          acceptsOtherDestinations: _acceptsOtherDestinations,
        );
      }
      if (post == null) {
        throw Exception('Could not save the post');
      }

      // Auto-attach fleet vehicles of this type (up to the chosen quantity)
      // so the listing publishes to the marketplace as active.
      final attachedCount = _isEdit ? _initialAttachedIds.length : 0;
      final slotsToFill = _qty - attachedCount;
      if (slotsToFill > 0) {
        final toAttach = eligible
            .where((v) => !_initialAttachedIds.contains(v.id))
            .take(slotsToFill)
            .map((v) => v.id)
            .toList();
        if (toAttach.isNotEmpty) {
          final n = post.destinationStopCount;
          final allStops = List<int>.generate(n, (i) => i);
          await _service.addVehicles(
            post.id,
            vehicleIds: toAttach,
            servedStopIndexes: allStops,
          );
          try {
            post = await _service.fetchById(post.id);
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _result = post;
        _submitting = false;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showUserErrorSnackBar(
        context,
        e,
        fallback: _isEdit ? 'Failed to update listing' : 'Failed to create listing',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = VehicleTypeVisual.forType(widget.vehicleType);
    return PopScope(
      // From the success step, back returns to the fleet list.
      canPop: _step != 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) {
          setState(() => _step = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
                title: Text(_isEdit ? 'Edit Availability' : 'Post Availability'),
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                automaticallyImplyLeading: true,
                leading: const BackButton(),
              ),
        body: SafeArea(
          child: switch (_step) {
            0 => _buildBasicDetailsStep(context, visual),
            1 => _buildRoutesStep(context, visual),
            _ => _buildSuccessStep(context, visual),
          },
        ),
        bottomNavigationBar: _step == 2 ? null : _buildBottomBar(context, visual),
      ),
    );
  }

  // ---------------------------------------------------------------- chrome

  Widget _buildStepHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget segment(int index, String label) {
      final active = _step >= index;
      return Expanded(
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.dividerGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${_step + 1} of 2',
          style: textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            segment(0, 'Basic Details'),
            const SizedBox(width: 8),
            segment(1, 'Routes & Rates'),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeHeader(BuildContext context, VehicleTypeVisual visual) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: visual.accentColor.withValues(alpha: 0.06),
        border: Border.all(color: visual.accentColor.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          visual.badge(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Type',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  widget.vehicleType,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, VehicleTypeVisual visual) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.dividerGrey)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        if (_step == 0) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() => _step = 0);
                        }
                      },
                child: Text(_step == 0 ? 'Cancel' : 'Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _submitting
                    ? null
                    : (_step == 0 ? _onNext : _submit),
                style: FilledButton.styleFrom(
                  backgroundColor: visual.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _step == 0
                            ? 'Next'
                            : (_isEdit ? 'Review & Save' : 'Review & Post'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------- step 1: basics

  Widget _buildBasicDetailsStep(BuildContext context, VehicleTypeVisual visual) {
    final textTheme = Theme.of(context).textTheme;
    return Consumer<VehicleProvider>(
      builder: (context, vp, _) {
        final fleetCount = _eligibleFleetVehicles(vp).length;
        final maxQty = _maxQty(vp);
        if (_qty > maxQty) _qty = maxQty;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildStepHeader(context),
            const SizedBox(height: 20),
            _buildTypeHeader(context, visual),
            const SizedBox(height: 24),

            Text('Available Vehicles', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  onPressed:
                      _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '$_qty',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed:
                      _qty < maxQty ? () => setState(() => _qty++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'These $_qty vehicle${_qty == 1 ? '' : 's'} will be available across all selected routes.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'Available in Fleet: $fleetCount',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickOriginLocation,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Current Location *',
                    hintText: 'Tap to pick on map',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.my_location_outlined),
                    suffixIcon: const Icon(Icons.chevron_right),
                    helperText: _hasOriginCoordinates()
                        ? '${_originLocation!.coordinates.latitude.toStringAsFixed(5)}, '
                            '${_originLocation!.coordinates.longitude.toStringAsFixed(5)}'
                        : 'Search or drop a pin to set coordinates',
                  ),
                  child: Text(
                    _originCtrl.text.trim().isEmpty
                        ? 'Tap to pick on map'
                        : _originCtrl.text.trim(),
                    style: TextStyle(
                      color: _originCtrl.text.trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Available From', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFromDate,
              icon: const Icon(Icons.event, size: 18),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(_dateFmt.format(_availableFrom)),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------- step 2: routes

  String _rateLabel(num? rate) =>
      rate == null ? 'Negotiable' : '₹ ${_inrFmt.format(rate)}';

  Widget _buildRoutesStep(BuildContext context, VehicleTypeVisual visual) {
    final textTheme = Theme.of(context).textTheme;
    final origin = _originCtrl.text.trim();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildStepHeader(context),
        const SizedBox(height: 20),
        _buildTypeHeader(context, visual),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: Text(
                'Routes & Rates',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addOrEditRoute(),
              icon: const Icon(Icons.add),
              label: const Text('Add Route'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_routes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.dividerGrey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No routes yet. Tap "Add Route" to set a destination with Export / Import rates.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...List.generate(
            _routes.length,
            (i) => _routeRow(context, i, origin),
          ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.dividerGrey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            value: _acceptsOtherDestinations,
            onChanged: (v) => setState(() => _acceptsOtherDestinations = v),
            title: const Text('Any Other Destination'),
            subtitle: Text(
              'Rate on Request — accept inquiries for unlisted routes (Negotiable).',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buyers pick a route and direction (Export/Import) when they contact you. Rates left as "Negotiable" are shown as Rate on Request.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _routeRow(BuildContext context, int index, String origin) {
    final textTheme = Theme.of(context).textTheme;
    final r = _routes[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              '${index + 1}',
              style: textTheme.labelSmall?.copyWith(
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
                Text(
                  origin.isEmpty
                      ? r.destination
                      : '$origin → ${r.destination}',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Export: ${_rateLabel(r.exportRate)} · Import: ${_rateLabel(r.importRate)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _addOrEditRoute(index: index),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.error),
            onPressed: () => setState(() => _routes.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- step 3: success

  Widget _buildSuccessStep(BuildContext context, VehicleTypeVisual visual) {
    final textTheme = Theme.of(context).textTheme;
    final p = _result;
    final qty = p?.quantity ?? _qty;
    final routeCount = p?.routes.length ?? _routes.length;
    final from = p?.availableFrom ?? _availableFrom;
    final isDraft = p?.isDraftListing ?? false;
    final isPaused = p?.isPaused ?? false;

    Widget summaryRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            _isEdit ? 'Availability Updated!' : 'Posted Successfully!',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            isDraft
                ? 'Saved as draft. Add an active fleet vehicle of this type to publish it to the marketplace.'
                : isPaused
                    ? 'Changes saved. This post is paused — resume it to make it visible in search again.'
                    : 'Your availability is live on the marketplace. Verified transporters can now find and book your vehicles.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.dividerGrey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  visual.badge(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.vehicleType,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.dividerGrey),
              const SizedBox(height: 6),
              summaryRow('Available Vehicles', '$qty'),
              summaryRow('Routes Added', '$routeCount'),
              summaryRow('Available From', _dateFmt.format(from)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .pop(PostAvailabilityStepperScreen.resultViewListings),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('View My Listings'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context)
              .pop(PostAvailabilityStepperScreen.resultPostAnother),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Post Another Vehicle Type'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../services/vehicle_post_service.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';
import 'route_rate_editor.dart';

class EditVehiclePostScreen extends StatefulWidget {
  const EditVehiclePostScreen({
    super.key,
    required this.postId,
    required this.initialPost,
  });

  final String postId;
  final VehiclePostModel initialPost;

  @override
  State<EditVehiclePostScreen> createState() => _EditVehiclePostScreenState();
}

class _EditVehiclePostScreenState extends State<EditVehiclePostScreen> {
  static const int _kDefaultDurationDays = 30;

  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _service = VehiclePostService();

  String? _vehicleType;
  late DateTime _availableFrom;
  DateTime? _availableTo;
  late bool _useEndDate;
  int _availableVehicles = 1;
  final List<RouteDraft> _routes = [];
  bool _acceptsOtherDestinations = false;
  late final Set<String> _initialLinkedVehicleIds;
  Set<String> _selectedFleetVehicleIds = {};
  bool _submitting = false;

  static final NumberFormat _inrFmt = NumberFormat.decimalPattern('en_IN');

  @override
  void initState() {
    super.initState();
    final p = widget.initialPost;

    if (!p.isActiveListing) {
      _vehicleType = null;
      _availableFrom = DateTime.now();
      _useEndDate = false;
      _initialLinkedVehicleIds = {};
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This listing cannot be edited (cancelled or inactive).',
            ),
          ),
        );
        Navigator.of(context).pop();
      });
      return;
    }

    _vehicleType = p.vehicleType;
    _originCtrl.text = p.origin;
    _availableVehicles = (p.quantity ?? 1).clamp(1, 9999);
    _acceptsOtherDestinations = p.acceptsOtherDestinations;

    for (final r in p.routes) {
      _routes.add(
        RouteDraft(
          destination: r.destination,
          exportRate: r.exportRate,
          importRate: r.importRate,
        ),
      );
    }
    // Legacy post without routes: seed a single route from its destination.
    if (_routes.isEmpty) {
      final legacyDest = (p.destination ?? '').trim();
      if (legacyDest.isNotEmpty) {
        _routes.add(
          RouteDraft(destination: legacyDest, exportRate: p.pricePerVehicle),
        );
      }
    }

    _availableFrom = p.availableFrom ?? DateTime.now();
    _availableTo = p.availableTo;
    _useEndDate = p.availableTo != null;
    _initialLinkedVehicleIds = p.availableVehicles
        .map((a) => a.vehicleId)
        .whereType<String>()
        .toSet();
    _selectedFleetVehicleIds = {..._initialLinkedVehicleIds};

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<VehicleProvider>().loadVehicles(refresh: true);
      final typeProvider = context.read<VehicleTypeProvider>();
      await typeProvider.ensureLoaded(refresh: true);
      if (!mounted) return;
      final names = typeProvider.typeNames;
      final pending = typeProvider.pendingTypeNames;
      bool isKnownType(String? value) =>
          value != null && (names.contains(value) || pending.contains(value));

      if (isKnownType(_vehicleType)) {
        return;
      }
      if (isKnownType(p.vehicleType)) {
        setState(() => _vehicleType = p.vehicleType);
      } else if (names.isNotEmpty) {
        setState(() => _vehicleType = names.first);
      }
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _availableFrom = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableTo ?? _availableFrom.add(const Duration(days: 7)),
      firstDate: _availableFrom,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _availableTo = picked);
  }

  String _rateLabel(num? rate) =>
      rate == null ? 'Negotiable' : '₹ ${_inrFmt.format(rate)}';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vehicleType == null || _vehicleType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle type')),
      );
      return;
    }

    int? durationDays;
    DateTime? to = _availableTo;
    if (_useEndDate) {
      if (to == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an end date')),
        );
        return;
      }
    } else {
      durationDays = _kDefaultDurationDays;
      to = null;
    }

    if (_routes.isEmpty && !_acceptsOtherDestinations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one route or enable "Any Other Destination"',
          ),
        ),
      );
      return;
    }

    final fleetCount = _selectedFleetVehicleIds.length;
    if (fleetCount > _availableVehicles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Available vehicles ($_availableVehicles) must be at least the fleet vehicles ($fleetCount).',
          ),
        ),
      );
      return;
    }

    final routes = _routes
        .map(
          (r) => MarketplaceRouteRate(
            destination: r.destination,
            exportRate: r.exportRate,
            importRate: r.importRate,
          ),
        )
        .toList();

    setState(() => _submitting = true);
    try {
      var updated = await _service.update(
        widget.postId,
        vehicleType: _vehicleType!,
        originAddress: _originCtrl.text.trim(),
        availableFrom: _availableFrom,
        availableTo: _useEndDate ? to : null,
        durationDays: _useEndDate ? null : durationDays,
        quantity: _availableVehicles,
        routes: routes,
        acceptsOtherDestinations: _acceptsOtherDestinations,
      );

      final newlyAdded = _selectedFleetVehicleIds
          .where((id) => !_initialLinkedVehicleIds.contains(id))
          .toList();
      if (newlyAdded.isNotEmpty) {
        final n = updated.destinationStopCount;
        final allStops = List<int>.generate(n, (i) => i);
        await _service.addVehicles(
          widget.postId,
          vehicleIds: newlyAdded,
          servedStopIndexes: allStops,
        );
        updated = await _service.fetchById(widget.postId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing updated')),
      );
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showUserErrorSnackBar(context, e, fallback: 'Failed to update listing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit listing'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SearchableVehicleTypePicker(
                value: _vehicleType,
                onChanged: (value) {
                  setState(() {
                    _vehicleType = value;
                    _selectedFleetVehicleIds.removeWhere(
                      (id) => !_initialLinkedVehicleIds.contains(id),
                    );
                  });
                },
              ),
              const SizedBox(height: 20),

              // Basic details
              Text('Available Vehicles', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              _availableVehiclesStepper(context),
              const SizedBox(height: 16),
              TextFormField(
                controller: _originCtrl,
                decoration: const InputDecoration(
                  labelText: 'Current Location *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.my_location_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your current location'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickFrom,
                icon: const Icon(Icons.event, size: 18),
                label:
                    Text('Available from: ${dateFmt.format(_availableFrom)}'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use specific end date'),
                value: _useEndDate,
                onChanged: (v) => setState(() => _useEndDate = v),
              ),
              if (_useEndDate)
                OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(
                    _availableTo == null
                        ? 'Select end date *'
                        : 'Until: ${dateFmt.format(_availableTo!)}',
                  ),
                ),
              const SizedBox(height: 20),

              // Routes & rates
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Preferred Routes & Rates',
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
                ...List.generate(_routes.length, (i) => _routeCard(context, i)),
              const SizedBox(height: 12),

              _otherDestinationRow(context),
              const SizedBox(height: 20),

              // Fleet vehicles
              Consumer<VehicleProvider>(
                builder: (context, vp, _) {
                  final selectedType = _vehicleType?.trim();
                  bool matchesType(String? vt) {
                    if (selectedType == null || selectedType.isEmpty) {
                      return true;
                    }
                    final t = vt?.trim();
                    if (t == null || t.isEmpty) return true;
                    return t == selectedType;
                  }

                  final vehicles = vp.vehicles
                      .where((v) =>
                          v.status.toLowerCase() == 'active' &&
                          v.ownerType == 'OWN' &&
                          (matchesType(v.vehicleType) ||
                              _initialLinkedVehicleIds.contains(v.id)))
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fleet vehicles', style: textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: vehicles.map((v) {
                          final sel = _selectedFleetVehicleIds.contains(v.id);
                          return FilterChip(
                            label: Text(
                              '${v.vehicleNumber}${v.vehicleType != null ? ' · ${v.vehicleType}' : ''}',
                            ),
                            selected: sel,
                            onSelected: (_) {
                              setState(() {
                                if (sel) {
                                  if (_initialLinkedVehicleIds
                                      .contains(v.id)) {
                                    return;
                                  }
                                  _selectedFleetVehicleIds.remove(v.id);
                                } else {
                                  _selectedFleetVehicleIds.add(v.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _availableVehiclesStepper(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton.outlined(
          onPressed: _availableVehicles > 1
              ? () => setState(() => _availableVehicles--)
              : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '$_availableVehicles',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.outlined(
          onPressed: () => setState(() => _availableVehicles++),
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'vehicles available in this pool',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeCard(BuildContext context, int index) {
    final textTheme = Theme.of(context).textTheme;
    final r = _routes[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.destination,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _addOrEditRoute(index: index);
                  } else if (value == 'remove') {
                    setState(() => _routes.removeAt(index));
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _rateChip(
                  context,
                  label: 'Export',
                  value: _rateLabel(r.exportRate),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _rateChip(
                  context,
                  label: 'Import',
                  value: _rateLabel(r.importRate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _otherDestinationRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
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
    );
  }
}

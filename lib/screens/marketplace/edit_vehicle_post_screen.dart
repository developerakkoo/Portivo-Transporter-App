import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../services/vehicle_post_service.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';

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
  static const int _kMaxDestinations = 10;

  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  late final TextEditingController _durationDaysCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _pricePerVehicleCtrl;
  final _service = VehiclePostService();

  final List<TextEditingController> _destControllers = [];
  final List<TextEditingController> _destQtyControllers = [];

  String? _vehicleType;
  late DateTime _availableFrom;
  DateTime? _availableTo;
  late bool _useEndDate;
  late final Set<String> _initialLinkedVehicleIds;
  Set<String> _selectedFleetVehicleIds = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPost;

    if (!p.isActiveListing) {
      _vehicleType = null;
      _durationDaysCtrl = TextEditingController(text: '7');
      _quantityCtrl = TextEditingController(text: '1');
      _noteCtrl = TextEditingController();
      _pricePerVehicleCtrl = TextEditingController();
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
    final dq = p.destinationQuantities;
    for (var i = 0; i < p.destinationStops.length; i++) {
      _destControllers.add(TextEditingController(text: p.destinationStops[i]));
      final q = i < dq.length ? dq[i] : (i == 0 ? (p.quantity ?? 1) : 0);
      _destQtyControllers.add(TextEditingController(text: '$q'));
    }
    if (_destControllers.isEmpty) {
      _destControllers.add(TextEditingController(text: p.destination ?? ''));
      _destQtyControllers.add(TextEditingController(text: '${p.quantity ?? 1}'));
    }

    _durationDaysCtrl = TextEditingController(
      text: p.availableTo == null && p.availableFrom != null
          ? '${DateTime.now().difference(p.availableFrom!).inDays.abs().clamp(1, 365)}'
          : '7',
    );
    _quantityCtrl = TextEditingController(text: '${p.quantity ?? 1}');
    _noteCtrl = TextEditingController(text: p.note ?? '');
    _pricePerVehicleCtrl = TextEditingController(
      text: p.pricePerVehicle != null ? '${p.pricePerVehicle}' : '',
    );
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
    for (final c in _destControllers) {
      c.dispose();
    }
    for (final c in _destQtyControllers) {
      c.dispose();
    }
    _durationDaysCtrl.dispose();
    _quantityCtrl.dispose();
    _noteCtrl.dispose();
    _pricePerVehicleCtrl.dispose();
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

  void _addDestField() {
    if (_destControllers.length >= _kMaxDestinations) return;
    setState(() {
      _destControllers.add(TextEditingController());
      _destQtyControllers.add(TextEditingController(text: '1'));
    });
  }

  void _removeDestField(int i) {
    if (i < 0 || i >= _destControllers.length) return;
    setState(() {
      _destControllers[i].dispose();
      _destQtyControllers[i].dispose();
      _destControllers.removeAt(i);
      _destQtyControllers.removeAt(i);
    });
  }

  List<String> _destinationAddresses() {
    return _destControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  int _destinationSlotsTotalPreview() {
    var t = 0;
    for (var i = 0; i < _destControllers.length; i++) {
      if (_destControllers[i].text.trim().isEmpty) continue;
      t += int.tryParse(_destQtyControllers[i].text.trim()) ?? 0;
    }
    return t;
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
      durationDays = int.tryParse(_durationDaysCtrl.text.trim());
      if (durationDays == null || durationDays < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter duration in days (1 or more)')),
        );
        return;
      }
      to = null;
    }

    final destLines = _destinationAddresses();
    if (destLines.length > _kMaxDestinations) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('At most $_kMaxDestinations destinations')),
      );
      return;
    }

    final fleetCount = _selectedFleetVehicleIds.length;
    late final List<int> destinationQuantities;
    if (destLines.isEmpty) {
      final base = int.tryParse(_quantityCtrl.text.trim());
      if (base == null || base < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter vehicle slots (1 or more)')),
        );
        return;
      }
      destinationQuantities = [math.max(fleetCount, base)];
    } else {
      destinationQuantities = [];
      for (var i = 0; i < _destControllers.length; i++) {
        if (_destControllers[i].text.trim().isEmpty) continue;
        final q = int.tryParse(_destQtyControllers[i].text.trim()) ?? 0;
        destinationQuantities.add(q);
      }
      if (destinationQuantities.length != destLines.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each destination needs a quantity')),
        );
        return;
      }
      final sumSlots = destinationQuantities.fold<int>(0, (a, b) => a + b);
      if (sumSlots < 1 || fleetCount > sumSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check destination quantities and fleet count')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      var updated = await _service.update(
        widget.postId,
        vehicleType: _vehicleType!,
        originAddress: _originCtrl.text.trim(),
        destinationAddresses: destLines,
        destinationQuantities: destinationQuantities,
        availableFrom: _availableFrom,
        availableTo: _useEndDate ? to : null,
        durationDays: _useEndDate ? null : durationDays,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        pricePerVehicle:
            Validators.parseOptionalListingPriceInr(_pricePerVehicleCtrl.text),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _originCtrl,
                decoration: const InputDecoration(
                  labelText: 'Origin *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter origin' : null,
              ),
              const SizedBox(height: 16),
              ...List.generate(_destControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _destControllers[i],
                          decoration: InputDecoration(
                            labelText: 'Destination ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _destQtyControllers[i],
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeDestField(i),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _destControllers.length >= _kMaxDestinations
                      ? null
                      : _addDestField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add destination'),
                ),
              ),
              if (_destControllers.isNotEmpty)
                Text(
                  'Total vehicle slots: ${_destinationSlotsTotalPreview()}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 16),
              Consumer<VehicleProvider>(
                builder: (context, vp, _) {
                  final vehicles = vp.vehicles
                      .where((v) =>
                          v.status.toLowerCase() == 'active' && v.ownerType == 'OWN')
                      .toList();
                  return Wrap(
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
                              if (_initialLinkedVehicleIds.contains(v.id)) return;
                              _selectedFleetVehicleIds.remove(v.id);
                            } else {
                              _selectedFleetVehicleIds.add(v.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickFrom,
                icon: const Icon(Icons.event, size: 18),
                label: Text('Available from: ${dateFmt.format(_availableFrom)}'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
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
                )
              else
                TextFormField(
                  controller: _durationDaysCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duration (days) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 16),
              if (_destControllers.isEmpty)
                TextFormField(
                  controller: _quantityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle slots (total)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pricePerVehicleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Asking price per vehicle (₹, optional)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.validateOptionalListingPriceInr,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
}

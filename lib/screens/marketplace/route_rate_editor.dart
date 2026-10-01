import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/trip_model.dart';
import '../location_picker_screen.dart';

/// Editable route row on the Post/Edit Availability forms. A null rate with its
/// negotiable flag set means "Rate on Request" for that direction.
class RouteDraft {
  RouteDraft({
    required this.destination,
    this.destinationLocation,
    this.exportRate,
    this.importRate,
  });

  String destination;
  TripLocation? destinationLocation;
  num? exportRate;
  num? importRate;

  bool get exportNegotiable => exportRate == null;
  bool get importNegotiable => importRate == null;

  bool get hasDestinationCoordinates {
    final loc = destinationLocation;
    if (loc == null) return false;
    final lat = loc.coordinates.latitude;
    final lng = loc.coordinates.longitude;
    return !(lat == 0 && lng == 0);
  }
}

/// Shows the add/edit route bottom sheet. Returns null if dismissed.
Future<RouteDraft?> showRouteRateEditor(
  BuildContext context, {
  RouteDraft? initial,
}) {
  return showModalBottomSheet<RouteDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => RouteRateEditorSheet(initial: initial),
  );
}

/// Bottom sheet to add or edit a route with per-direction (Export/Import) rates.
class RouteRateEditorSheet extends StatefulWidget {
  const RouteRateEditorSheet({super.key, this.initial});

  final RouteDraft? initial;

  @override
  State<RouteRateEditorSheet> createState() => _RouteRateEditorSheetState();
}

class _RouteRateEditorSheetState extends State<RouteRateEditorSheet> {
  final _sheetFormKey = GlobalKey<FormState>();
  late final TextEditingController _destCtrl;
  late final TextEditingController _exportCtrl;
  late final TextEditingController _importCtrl;
  late bool _exportNegotiable;
  late bool _importNegotiable;
  TripLocation? _destinationLocation;
  String? _destinationError;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _destCtrl = TextEditingController(text: init?.destination ?? '');
    _destinationLocation = init?.destinationLocation;
    _exportNegotiable = init?.exportNegotiable ?? false;
    _importNegotiable = init?.importNegotiable ?? false;
    _exportCtrl = TextEditingController(
      text: init?.exportRate?.toString() ?? '',
    );
    _importCtrl = TextEditingController(
      text: init?.importRate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _exportCtrl.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push<TripLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          isPickup: false,
          appBarTitle: 'Destination',
          initialQuery:
              _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _destinationLocation = result;
      _destCtrl.text = result.address ?? '';
      _destinationError = null;
    });
  }

  void _save() {
    if (!_sheetFormKey.currentState!.validate()) return;
    final dest = _destCtrl.text.trim();
    if (dest.isEmpty) return;
    if (!_destinationLocationHasCoords()) {
      setState(() {
        _destinationError = 'Pick destination on map';
      });
      return;
    }
    num? exportRate;
    num? importRate;
    if (!_exportNegotiable) {
      exportRate = Validators.parseOptionalListingPriceInr(_exportCtrl.text);
    }
    if (!_importNegotiable) {
      importRate = Validators.parseOptionalListingPriceInr(_importCtrl.text);
    }
    Navigator.pop(
      context,
      RouteDraft(
        destination: dest,
        destinationLocation: _destinationLocation,
        exportRate: exportRate,
        importRate: importRate,
      ),
    );
  }

  bool _destinationLocationHasCoords() {
    final loc = _destinationLocation;
    if (loc == null) return false;
    final lat = loc.coordinates.latitude;
    final lng = loc.coordinates.longitude;
    return !(lat == 0 && lng == 0);
  }

  Widget _rateField({
    required String label,
    required TextEditingController controller,
    required bool negotiable,
    required ValueChanged<bool> onNegotiableChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g. 45000',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.validateOptionalListingPriceInr,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Negotiable'),
                Switch(
                  value: negotiable,
                  onChanged: onNegotiableChanged,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + bottomInset,
      ),
      child: Form(
        key: _sheetFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initial == null ? 'Add Route' : 'Edit Route',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickDestination,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Destination *',
                    hintText: 'Tap to pick on map',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: const Icon(Icons.chevron_right),
                    errorText: _destinationError,
                    helperText: _destinationLocationHasCoords()
                        ? '${_destinationLocation!.coordinates.latitude.toStringAsFixed(5)}, '
                            '${_destinationLocation!.coordinates.longitude.toStringAsFixed(5)}'
                        : 'Search or drop a pin to set coordinates',
                  ),
                  child: Text(
                    _destCtrl.text.trim().isEmpty
                        ? 'Tap to pick on map'
                        : _destCtrl.text.trim(),
                    style: TextStyle(
                      color: _destCtrl.text.trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _rateField(
              label: 'Export Rate',
              controller: _exportCtrl,
              negotiable: _exportNegotiable,
              onNegotiableChanged: (v) => setState(() => _exportNegotiable = v),
            ),
            const SizedBox(height: 16),
            _rateField(
              label: 'Import Rate',
              controller: _importCtrl,
              negotiable: _importNegotiable,
              onNegotiableChanged: (v) => setState(() => _importNegotiable = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Route'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/app_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/trip_operational_locations.dart';
import '../data/models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../screens/location_picker_screen.dart';
import 'trip_operational_location_fields.dart';

class EditTripLocationsSheet extends StatefulWidget {
  const EditTripLocationsSheet({super.key, required this.trip});

  final TripModel trip;

  static Future<bool?> show(BuildContext context, TripModel trip) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditTripLocationsSheet(trip: trip),
    );
  }

  @override
  State<EditTripLocationsSheet> createState() => _EditTripLocationsSheetState();
}

class _EditTripLocationsSheetState extends State<EditTripLocationsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final OperationalLocationDraft _draft;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _draft = OperationalLocationDraft();
    _draft.loadFromTrip(widget.trip);
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _pick(OperationalPoint point) async {
    final current = _draft.locationForPoint(point);
    final result = await Navigator.push<TripLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          isPickup: point == OperationalPoint.a,
          appBarTitle: TripOperationalLocations.pickerTitle(_draft.tripType, point),
          initialQuery: current?.address,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _draft.setLocation(point, result));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_draft.isComplete) {
      return;
    }

    final needsConfirm = widget.trip.status == AppConstants.tripStatusActive ||
        widget.trip.status == 'PAUSED';
    if (needsConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update operational locations?'),
          content: const Text(AppCopy.editLocationsActiveConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<TripProvider>();
    final success = await provider.updateTrip(
      widget.trip.id,
      _draft.buildPayload(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to update locations'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit operational locations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TripOperationalLocationFields(
              tripType: _draft.tripType,
              controllers: _draft.controllers,
              onPick: _pick,
              validator: (point) {
                if (_draft.locationForPoint(point) == null) {
                  return '${TripOperationalLocations.labelForPoint(_draft.tripType, point)} is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save locations'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/trip_operational_locations.dart';
import '../data/models/trip_model.dart';

class TripOperationalLocationFields extends StatelessWidget {
  const TripOperationalLocationFields({
    super.key,
    required this.tripType,
    required this.controllers,
    required this.onPick,
    this.validator,
  });

  final String? tripType;
  final Map<OperationalPoint, TextEditingController> controllers;
  final Future<void> Function(OperationalPoint point) onPick;
  final String? Function(OperationalPoint point)? validator;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final points = TripOperationalLocations.visiblePoints(tripType);

    return Column(
      children: [
        for (var i = 0; i < points.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _LocationField(
            label: TripOperationalLocations.labelForPoint(tripType, points[i]),
            controller: controllers[points[i]]!,
            onTap: () => onPick(points[i]),
            validator: validator == null ? null : () => validator!(points[i]),
            textTheme: textTheme,
          ),
        ],
        if (tripType == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Select trip type to configure operational locations',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.controller,
    required this.onTap,
    required this.textTheme,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;
  final TextTheme textTheme;
  final String? Function()? validator;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        validator: (_) => validator?.call(),
        decoration: InputDecoration(
          labelText: label,
          hintText: TripOperationalLocations.fieldHint(OperationalPoint.a),
          suffixIcon: const Icon(Icons.map_outlined),
        ),
      ),
    );
  }
}

/// Draft/create state holder for operational points before persistence.
class OperationalLocationDraft {
  OperationalLocationDraft({String? tripType}) : tripType = tripType;

  String? tripType;
  TripLocation? pickup;
  TripLocation? intermediate;
  TripLocation? drop;

  final Map<OperationalPoint, TextEditingController> controllers = {
    OperationalPoint.a: TextEditingController(),
    OperationalPoint.b: TextEditingController(),
    OperationalPoint.c: TextEditingController(),
  };

  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  void syncControllersFromState() {
    controllers[OperationalPoint.a]?.text = pickup?.address ?? '';
    if (TripOperationalLocations.isLocalTripType(tripType)) {
      controllers[OperationalPoint.b]?.text = drop?.address ?? '';
      controllers[OperationalPoint.c]?.text = '';
    } else {
      controllers[OperationalPoint.b]?.text = intermediate?.address ?? '';
      controllers[OperationalPoint.c]?.text = drop?.address ?? '';
    }
  }

  void loadFromTrip(TripModel trip) {
    tripType = trip.tripType;
    pickup = trip.pickupLocation;
    intermediate = trip.intermediateLocation;
    drop = trip.dropLocation;
    syncControllersFromState();
  }

  void setLocation(OperationalPoint point, TripLocation location) {
    switch (point) {
      case OperationalPoint.a:
        pickup = location;
        controllers[OperationalPoint.a]?.text = location.address ?? '';
      case OperationalPoint.b:
        if (TripOperationalLocations.isLocalTripType(tripType)) {
          drop = location;
          controllers[OperationalPoint.b]?.text = location.address ?? '';
        } else {
          intermediate = location;
          controllers[OperationalPoint.b]?.text = location.address ?? '';
        }
      case OperationalPoint.c:
        drop = location;
        controllers[OperationalPoint.c]?.text = location.address ?? '';
    }
  }

  TripLocation? locationForPoint(OperationalPoint point) {
    return TripOperationalLocations.readDraftPoint(
      tripType: tripType,
      point: point,
      pickup: pickup,
      intermediate: intermediate,
      drop: drop,
    );
  }

  void onTripTypeChanged(String? newType) {
    if (newType == tripType) return;
    final previousDrop = drop;
    tripType = newType;
    if (TripOperationalLocations.isLocalTripType(newType)) {
      intermediate = null;
      if (drop == null && previousDrop != null) {
        drop = previousDrop;
      }
    }
    syncControllersFromState();
  }

  bool get isComplete => TripOperationalLocations.isLocationsComplete(
        tripType: tripType,
        pickup: pickup,
        intermediate: intermediate,
        drop: drop,
      );

  Map<String, dynamic> buildPayload() {
    return TripOperationalLocations.buildLocationPayload(
      tripType: tripType,
      pickup: pickup,
      intermediate: intermediate,
      drop: drop,
    );
  }
}

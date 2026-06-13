import 'package:flutter/material.dart';

import '../../providers/trip_provider.dart';
import '../../widgets/quick_trip_start_sheet.dart';
import 'package:provider/provider.dart';

/// Opens quick trip start sheet, then navigates to create-trip with optional draft id.
Future<void> openCreateTripFlow(BuildContext context) async {
  final selectedDraftId = await QuickTripStartSheet.show(context);
  if (!context.mounted || selectedDraftId == null) return;

  await Navigator.of(context).pushNamed(
    '/create-trip',
    arguments: selectedDraftId.isEmpty ? null : selectedDraftId,
  );

  if (!context.mounted) return;
  await context.read<TripProvider>().loadDrafts(refresh: true);
}

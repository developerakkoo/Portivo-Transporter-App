import 'package:flutter/foundation.dart';

import '../services/pinned_trips_service.dart';
import 'trip_provider.dart';

class PinnedTripsProvider extends ChangeNotifier {
  final PinnedTripsService _service = PinnedTripsService();

  Set<String> _pinnedIds = {};

  Set<String> get pinnedIds => Set.unmodifiable(_pinnedIds);

  bool isPinned(String tripId) => _pinnedIds.contains(tripId);

  Future<void> load() async {
    _pinnedIds = await _service.getPinnedIds();
    notifyListeners();
  }

  Future<void> togglePin(String tripId) async {
    await _service.togglePin(tripId);
    _pinnedIds = await _service.getPinnedIds();
    notifyListeners();
  }

  Future<void> refreshFromStorage() async {
    _pinnedIds = await _service.getPinnedIds();
    notifyListeners();
  }

  /// Drops pin IDs that are not present in loaded trip lists (after refresh).
  Future<void> reconcileWithTripProvider(TripProvider tripProvider) async {
    final valid = <String>{
      ...tripProvider.trips.map((t) => t.id),
      ...tripProvider.availableTrips.map((t) => t.id),
    };
    await _service.removeStaleIds(valid);
    _pinnedIds = await _service.getPinnedIds();
    notifyListeners();
  }
}

import '../../core/constants/app_constants.dart';
import 'trip_model.dart';

/// Coarse "what is this vehicle doing right now" bucket, derived from a trip's
/// status + live movementStage. Kept in sync with the API's
/// deriveTripMovementCategory. Drives the fleet-map filter chips and the
/// Vehicle-view category chips.
enum VehicleMovementCategory { inTransit, loading, delivered }

extension VehicleMovementCategoryX on VehicleMovementCategory {
  String get label {
    switch (this) {
      case VehicleMovementCategory.inTransit:
        return 'In Transit';
      case VehicleMovementCategory.loading:
        return 'Loading';
      case VehicleMovementCategory.delivered:
        return 'Delivered';
    }
  }
}

/// Map a single trip to a movement category.
///
/// Delivered = reached destination / POD stage; Loading = loading/unloading
/// (from the live movementStage); everything else = In Transit.
VehicleMovementCategory movementCategoryForTrip(TripModel trip) {
  const delivered = {
    AppConstants.tripStatusPodPending,
    AppConstants.tripStatusCompleted,
    AppConstants.tripStatusClosedWithPOD,
    AppConstants.tripStatusClosedWithoutPOD,
  };
  if (delivered.contains(trip.status)) {
    return VehicleMovementCategory.delivered;
  }

  final stage = (trip.tracking?.movementStage ?? '').toLowerCase();
  if (stage.contains('loading') || stage.contains('unloading')) {
    return VehicleMovementCategory.loading;
  }

  return VehicleMovementCategory.inTransit;
}

/// One route within a trip group (all vehicle-trips sharing a routeIndex).
class TripGroupRoute {
  final int routeIndex;
  final String tripType;
  final TripLocation? pickup;
  final TripLocation? intermediate;
  final TripLocation? drop;

  const TripGroupRoute({
    required this.routeIndex,
    required this.tripType,
    this.pickup,
    this.intermediate,
    this.drop,
  });
}

/// Aggregate view over the vehicle-trips created together in one multi-route
/// batch (sharing a [tripGroupId]). Legacy/ungrouped trips form a group of one
/// keyed by the trip's own id.
class TripGroup {
  final String groupId;
  final String? customerName;
  final String? reference;
  final List<TripModel> trips;

  TripGroup({
    required this.groupId,
    required this.trips,
    this.customerName,
    this.reference,
  });

  /// Build a group from its constituent trips (used both by the group-detail
  /// endpoint response and by client-side grouping of the active list).
  factory TripGroup.fromTrips(String groupId, List<TripModel> trips) {
    String? customerName;
    String? reference;
    for (final t in trips) {
      customerName ??= t.customerName;
      reference ??= t.reference;
    }
    final sorted = [...trips]
      ..sort((a, b) {
        final byRoute = a.routeIndex.compareTo(b.routeIndex);
        if (byRoute != 0) return byRoute;
        return a.createdAt.compareTo(b.createdAt);
      });
    return TripGroup(
      groupId: groupId,
      trips: sorted,
      customerName: customerName,
      reference: reference,
    );
  }

  int get vehicleCount => trips.length;

  int get containerCount => trips
      .map((t) => t.containerNumber)
      .where((c) => c != null && c.isNotEmpty)
      .toSet()
      .length;

  /// A representative public trip id for the card header.
  String get displayTripId {
    if (trips.isEmpty) return groupId;
    return trips.first.tripId.isNotEmpty ? trips.first.tripId : groupId;
  }

  int categoryCount(VehicleMovementCategory category) =>
      trips.where((t) => movementCategoryForTrip(t) == category).length;

  int get inTransitCount => categoryCount(VehicleMovementCategory.inTransit);
  int get loadingCount => categoryCount(VehicleMovementCategory.loading);
  int get deliveredCount => categoryCount(VehicleMovementCategory.delivered);

  /// Earliest (soonest) live ETA across all vehicles still en route, in seconds.
  int? get earliestEtaSeconds {
    int? best;
    for (final t in trips) {
      final eta = t.tracking?.etaSeconds;
      if (eta == null) continue;
      if (movementCategoryForTrip(t) == VehicleMovementCategory.delivered) {
        continue;
      }
      if (best == null || eta < best) best = eta;
    }
    return best;
  }

  /// True when every vehicle in the group has reached the delivered stage.
  bool get isAllDelivered =>
      trips.isNotEmpty && deliveredCount == trips.length;

  /// Distinct routes in the group, ordered by routeIndex.
  List<TripGroupRoute> get routes {
    final byIndex = <int, TripGroupRoute>{};
    for (final t in trips) {
      byIndex.putIfAbsent(
        t.routeIndex,
        () => TripGroupRoute(
          routeIndex: t.routeIndex,
          tripType: t.tripType,
          pickup: t.pickupLocation,
          intermediate: t.intermediateLocation,
          drop: t.dropLocation,
        ),
      );
    }
    final list = byIndex.values.toList()
      ..sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
    return list;
  }
}

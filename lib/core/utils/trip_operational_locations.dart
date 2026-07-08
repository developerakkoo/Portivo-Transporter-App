import '../constants/app_constants.dart';
import '../../data/models/trip_model.dart';

enum OperationalPoint { a, b, c }

class TripOperationalLocations {
  TripOperationalLocations._();

  static bool isLocalTripType(String? tripType) {
    return tripType?.toUpperCase() == AppConstants.tripTypeLocal;
  }

  static bool isImportExportTripType(String? tripType) {
    final t = tripType?.toUpperCase();
    return t == AppConstants.tripTypeImport || t == AppConstants.tripTypeExport;
  }

  static List<OperationalPoint> visiblePoints(String? tripType) {
    if (isLocalTripType(tripType)) {
      return const [OperationalPoint.a, OperationalPoint.b];
    }
    return const [OperationalPoint.a, OperationalPoint.b, OperationalPoint.c];
  }

  static String labelForPoint(String? tripType, OperationalPoint point) {
    switch (point) {
      case OperationalPoint.a:
        return 'Point A';
      case OperationalPoint.b:
        return isLocalTripType(tripType) ? 'Point B' : 'Point B';
      case OperationalPoint.c:
        return 'Point C';
    }
  }

  static String pickerTitle(String? tripType, OperationalPoint point) {
    return 'Select ${labelForPoint(tripType, point)}';
  }

  static String fieldHint(OperationalPoint point) {
    return 'Tap to search and select location';
  }

  static TripLocation? readPoint(TripModel trip, OperationalPoint point) {
    switch (point) {
      case OperationalPoint.a:
        return trip.pickupLocation;
      case OperationalPoint.b:
        return isLocalTripType(trip.tripType)
            ? trip.dropLocation
            : trip.intermediateLocation;
      case OperationalPoint.c:
        return trip.dropLocation;
    }
  }

  static TripLocation? readDraftPoint({
    required String? tripType,
    required OperationalPoint point,
    TripLocation? pickup,
    TripLocation? intermediate,
    TripLocation? drop,
  }) {
    switch (point) {
      case OperationalPoint.a:
        return pickup;
      case OperationalPoint.b:
        return isLocalTripType(tripType) ? drop : intermediate;
      case OperationalPoint.c:
        return drop;
    }
  }

  static bool isLocationsComplete({
    required String? tripType,
    TripLocation? pickup,
    TripLocation? intermediate,
    TripLocation? drop,
  }) {
    if (isLocalTripType(tripType)) {
      return pickup != null && drop != null;
    }
    if (isImportExportTripType(tripType)) {
      return pickup != null && intermediate != null && drop != null;
    }
    return pickup != null && drop != null;
  }

  static String? routeSummary({
    required String? tripType,
    TripLocation? pickup,
    TripLocation? intermediate,
    TripLocation? drop,
  }) {
    String addr(TripLocation? loc) => loc?.address?.trim() ?? '';
    if (isLocalTripType(tripType)) {
      final a = addr(pickup);
      final b = addr(drop);
      if (a.isEmpty && b.isEmpty) return null;
      if (a.isEmpty) return 'To $b';
      if (b.isEmpty) return 'From $a';
      return '$a → $b';
    }
    final a = addr(pickup);
    final b = addr(intermediate);
    final c = addr(drop);
    final parts = [a, b, c].where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' → ');
  }

  static Map<String, dynamic> buildLocationPayload({
    required String? tripType,
    TripLocation? pickup,
    TripLocation? intermediate,
    TripLocation? drop,
  }) {
    if (isLocalTripType(tripType)) {
      return {
        if (pickup != null) 'pickupLocation': pickup.toJson(),
        if (drop != null) 'dropLocation': drop.toJson(),
      };
    }
    return {
      if (pickup != null) 'pickupLocation': pickup.toJson(),
      if (intermediate != null) 'intermediateLocation': intermediate.toJson(),
      if (drop != null) 'dropLocation': drop.toJson(),
    };
  }
}

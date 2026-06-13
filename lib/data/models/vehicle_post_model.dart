import 'trip_model.dart';

/// Vehicle slot on a marketplace post (VehicleRouteAssignment); [id] is assignment id for bookings.
class VehiclePostAssignment {
  const VehiclePostAssignment({
    required this.id,
    this.vehicleId,
    this.vehicleNumber,
    this.price,
    this.servedStopIndexes = const [],
  });

  final String id;
  final String? vehicleId;
  final String? vehicleNumber;
  final num? price;
  /// Destination stop indices (0 = primary) this vehicle serves; empty => all stops (legacy).
  final List<int> servedStopIndexes;

  static VehiclePostAssignment? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? json['_id']?.toString();
    if (id == null || id.isEmpty) return null;
    List<int> stops = [];
    final raw = json['servedStopIndexes'];
    if (raw is List) {
      for (final e in raw) {
        final n = e is num ? e.toInt() : int.tryParse('$e');
        if (n != null) stops.add(n);
      }
    }
    return VehiclePostAssignment(
      id: id,
      vehicleId: json['vehicleId']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      price: json['price'] is num ? json['price'] as num : num.tryParse('${json['price']}'),
      servedStopIndexes: stops,
    );
  }
}

/// Availability post from GET /vehicle-posts (search, mine, by id) or POST create response.
class VehiclePostModel {
  VehiclePostModel({
    required this.id,
    this.transporterId,
    this.transporterName,
    this.transporterCompany,
    this.transporterMobile,
    this.vehicleId,
    this.vehicleNumber,
    this.vehicleType,
    this.vehicleTrailerType,
    required this.origin,
    this.destination,
    this.destinationStops = const [],
    this.originLocation,
    this.destinationLocation,
    this.destinationQuantities = const [],
    this.quantity,
    this.availableFrom,
    this.availableTo,
    this.note,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.lastEdited,
    this.pricePerVehicle,
    this.slotsLeft,
    this.availableVehicles = const [],
  });

  final String id;
  /// Poster transporter id (for owner checks).
  final String? transporterId;
  final String? transporterName;
  final String? transporterCompany;
  final String? transporterMobile;
  final String? vehicleId;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? vehicleTrailerType;
  final String origin;
  final String? destination;
  /// Ordered destination labels (primary first, then extra stops). From API `destinationsAll` or legacy `destination`.
  final List<String> destinationStops;
  /// Parsed GeoJSON origin from API when present (for edit / maps).
  final TripLocation? originLocation;
  final TripLocation? destinationLocation;
  /// Per-stop vehicle quotas (same order as [destinationStops]; API `destinationQuantities`).
  final List<int> destinationQuantities;
  final int? quantity;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final String? note;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastEdited;
  final num? pricePerVehicle;
  final int? slotsLeft;
  final List<VehiclePostAssignment> availableVehicles;

  /// Count of canonical destination stops on the listing (for `servedStopIndexes` / add vehicles).
  int get destinationStopCount {
    if (destinationQuantities.isNotEmpty) return destinationQuantities.length;
    final s = destinationStops.length;
    if (s > 0) return s;
    return 1;
  }

  /// Buyer-visible in marketplace search (`active` only).
  bool get isPublishedOnMarketplace {
    final s = status?.toLowerCase().trim();
    if (s == null || s.isEmpty) return true;
    return s == 'active';
  }

  /// Unpublished listing until seller attaches fleet vehicles (`draft`).
  bool get isDraftListing {
    final s = status?.toLowerCase().trim();
    return s == 'draft';
  }

  /// Seller can edit or attach vehicles (`draft` or `active`).
  bool get isEditableMarketplacePost {
    final s = status?.toLowerCase().trim();
    if (s == null || s.isEmpty) return true;
    return s == 'active' || s == 'draft';
  }

  /// Same as [isEditableMarketplacePost] (used across marketplace screens).
  bool get isActiveListing => isEditableMarketplacePost;

  /// One-line route for list/detail subtitles.
  String get routeDisplayLine {
    if (destinationStops.isEmpty) return '$origin → Open';
    return '$origin → ${destinationStops.join(', ')}';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String? _stringId(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  static String _locationDisplayLabel(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is Map) {
      return (v['formattedAddress'] ?? v['address'] ?? '').toString().trim();
    }
    return '';
  }

  static List<String> _destinationsAllLabels(dynamic v) {
    if (v is! List || v.isEmpty) return [];
    final out = <String>[];
    for (final e in v) {
      final s = _locationDisplayLabel(e);
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  static TripLocation? _locationDetailFromApi(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      try {
        return TripLocation.fromJson(Map<String, dynamic>.from(v));
      } catch (_) {
        return null;
      }
    }
    if (v is String && v.trim().isNotEmpty) {
      return TripLocation(
        address: v.trim(),
        coordinates: LocationCoordinates(latitude: 0, longitude: 0),
      );
    }
    return null;
  }

  static VehiclePostModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = _stringId(json['id'] ?? json['_id']);
    if (id == null || id.isEmpty) return null;

    Map<String, dynamic>? t;
    final tr = json['transporter'];
    if (tr is Map) {
      t = Map<String, dynamic>.from(tr);
    }

    Map<String, dynamic>? veh;
    final vehRaw = json['vehicle'];
    if (vehRaw is Map) {
      veh = Map<String, dynamic>.from(vehRaw);
    }

    final transporterId = _stringId(t?['id'] ?? t?['_id']);

    String? vehicleId = _stringId(veh?['id'] ?? veh?['_id']);
    String? vehicleNumber = json['vehicleNumber']?.toString();
    String? vehicleType = json['vehicleType']?.toString();
    String? vehicleTrailerType;

    if (veh != null) {
      vehicleNumber ??= veh['vehicleNumber']?.toString();
      vehicleType ??= veh['vehicleType']?.toString();
      vehicleTrailerType = veh['trailerType']?.toString();
    }

    final avRaw = json['availableVehicles'];
    final assignments = <VehiclePostAssignment>[];
    if (avRaw is List) {
      for (final item in avRaw) {
        if (item is Map) {
          final a = VehiclePostAssignment.fromJson(Map<String, dynamic>.from(item));
          if (a != null) assignments.add(a);
        }
      }
    }

    final ppv = json['pricePerVehicle'];
    final num? pricePerVehicle = ppv is num ? ppv : num.tryParse('$ppv');
    final sl = json['slotsLeft'];
    final int? slotsLeft = sl is num ? sl.toInt() : int.tryParse('$sl');

    List<int> destQty = [];
    final dqRaw = json['destinationQuantities'];
    if (dqRaw is List) {
      for (final e in dqRaw) {
        final n = e is num ? e.toInt() : int.tryParse('$e');
        if (n != null && n >= 0) destQty.add(n);
      }
    }

    final originRaw = json['origin'];
    final destRaw = json['destination'];
    final originLabel = _locationDisplayLabel(originRaw);
    var stops = _destinationsAllLabels(json['destinationsAll']);
    if (stops.isEmpty) {
      final destLabel = _locationDisplayLabel(destRaw);
      if (destLabel.isNotEmpty) stops = [destLabel];
      final extra = json['destinations'];
      if (extra is List) {
        for (final e in extra) {
          final s = _locationDisplayLabel(e);
          if (s.isNotEmpty && !stops.contains(s)) stops.add(s);
        }
      }
    }
    final destPrimary = stops.isEmpty ? null : stops.first;

    return VehiclePostModel(
      id: id,
      transporterId: transporterId,
      transporterName: t?['name']?.toString(),
      transporterCompany: t?['company']?.toString(),
      transporterMobile: t?['mobile']?.toString(),
      vehicleId: vehicleId,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      vehicleTrailerType: vehicleTrailerType,
      origin: originLabel,
      destination: destPrimary,
      destinationStops: stops,
      originLocation: _locationDetailFromApi(originRaw),
      destinationLocation: destPrimary != null
          ? (_locationDetailFromApi(destRaw) ??
              TripLocation(
                address: destPrimary,
                coordinates: LocationCoordinates(latitude: 0, longitude: 0),
              ))
          : _locationDetailFromApi(destRaw),
      destinationQuantities: destQty,
      quantity: json['quantity'] is num ? (json['quantity'] as num).toInt() : null,
      availableFrom: _parseDate(json['availableFrom']),
      availableTo: _parseDate(json['availableTo']),
      note: json['note']?.toString(),
      status: json['status']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      lastEdited: _parseDate(json['lastEdited']),
      pricePerVehicle: pricePerVehicle,
      slotsLeft: slotsLeft,
      availableVehicles: assignments,
    );
  }
}

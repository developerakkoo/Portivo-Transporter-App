import '../../core/constants/app_constants.dart';
import '../../core/utils/json_parser.dart';

String _normalizeTripStatus(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return AppConstants.tripStatusPlanned;
  return t.toUpperCase();
}

/// API may return populated refs as `Map` or raw ids as `String` — never cast with `as Map?`.
String? _stringFieldFromMap(dynamic node, String key) {
  if (node is Map) {
    final v = node[key];
    if (v != null) return v.toString();
  }
  return null;
}

String? _vehicleNumberFromTripJson(Map<String, dynamic> json) {
  final vn = _stringFieldFromMap(json['vehicle'], 'vehicleNumber');
  if (vn != null && vn.isNotEmpty) return vn;
  return _stringFieldFromMap(json['vehicleId'], 'vehicleNumber');
}

String? _driverNameFromTripJson(Map<String, dynamic> json) {
  return _stringFieldFromMap(json['driverId'], 'name');
}

String? _transporterDisplayNameFromTripJson(Map<String, dynamic> json) {
  final t = json['transporterId'];
  if (t is! Map) return null;
  return _stringFieldFromMap(t, 'company') ?? _stringFieldFromMap(t, 'name');
}

TripLocation? _parseTripLocation(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    try {
      return TripLocation.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }
  return null;
}

List<TripAssignment>? _parseAssignments(dynamic data) {
  if (data == null || data is! List || data.isEmpty) return null;
  try {
    final list = <TripAssignment>[];
    for (final e in data) {
      if (e is Map) {
        list.add(TripAssignment.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return list.isEmpty ? null : list;
  } catch (_) {
    return null;
  }
}

class TripAssignment {
  final String containerNumber;
  final String vehicleId;
  final String driverId;
  final String? vehicleNumber;
  final String? driverName;

  TripAssignment({
    required this.containerNumber,
    required this.vehicleId,
    required this.driverId,
    this.vehicleNumber,
    this.driverName,
  });

  factory TripAssignment.fromJson(Map<String, dynamic> json) {
    final v = json['vehicleId'];
    final d = json['driverId'];
    String? extractId(dynamic x) {
      if (x == null) return null;
      if (x is Map) return (x['_id'] ?? x['id'])?.toString();
      return x.toString();
    }
    return TripAssignment(
      containerNumber: json['containerNumber']?.toString() ?? '',
      vehicleId: extractId(v) ?? '',
      driverId: extractId(d) ?? '',
      vehicleNumber: v is Map ? v['vehicleNumber']?.toString() : null,
      driverName: d is Map ? d['name']?.toString() : null,
    );
  }
}

class TripModel {
  final String id;
  final String tripId;
  final String transporterId;
  final String? customerId;
  final String? customerName;
  final String vehicleId;
  final String? driverId;
  final String? vehicleNumber;
  final String? driverName;
  final String? transporterName;
  final String? containerNumber;
  final List<TripAssignment>? assignments;
  final String? reference;
  final TripLocation? pickupLocation;
  final TripLocation? dropLocation;
  final String tripType; // IMPORT or EXPORT
  final String status; // PLANNED, ACTIVE, COMPLETED, POD_PENDING, CANCELLED
  final List<MilestoneModel> milestones;
  final PODModel? pod;
  final String? shareToken;
  final DateTime? shareTokenExpiry;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? podDueAt;

  TripModel({
    required this.id,
    required this.tripId,
    required this.transporterId,
    this.customerId,
    this.customerName,
    required this.vehicleId,
    this.driverId,
    this.vehicleNumber,
    this.driverName,
    this.transporterName,
    this.containerNumber,
    this.assignments,
    this.reference,
    this.pickupLocation,
    this.dropLocation,
    required this.tripType,
    required this.status,
    required this.milestones,
    this.pod,
    this.shareToken,
    this.shareTokenExpiry,
    required this.createdAt,
    required this.updatedAt,
    this.podDueAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final customerIdData = json['customerId'];
    String? customerName;
    if (customerIdData is Map && customerIdData['name'] != null) {
      customerName = customerIdData['name']?.toString();
    }
    return TripModel(
      id: JsonParser.extractString(json['_id'] ?? json['id'], ''),
      tripId: JsonParser.extractString(json['tripId'], ''),
      transporterId: JsonParser.extractId(json['transporterId']) ?? '',
      customerId: JsonParser.extractId(customerIdData),
      customerName: customerName ?? json['customerName']?.toString(),
      vehicleId: JsonParser.extractId(json['vehicleId']) ?? '',
      driverId: JsonParser.extractId(json['driverId']),
      vehicleNumber: _vehicleNumberFromTripJson(json),
      driverName: _driverNameFromTripJson(json),
      transporterName: _transporterDisplayNameFromTripJson(json),
      containerNumber: json['containerNumber']?.toString(),
      assignments: _parseAssignments(json['assignments']),
      reference: json['reference']?.toString(),
      pickupLocation: _parseTripLocation(json['pickupLocation']),
      dropLocation: _parseTripLocation(json['dropLocation']),
      tripType: JsonParser.extractString(json['tripType'], 'EXPORT'),
      status: _normalizeTripStatus(JsonParser.extractString(json['status'], 'PLANNED')),
      milestones: JsonParser.extractList<MilestoneModel>(
        json['milestones'],
        (json) => MilestoneModel.fromJson(json),
      ),
      pod: json['POD'] != null ? PODModel.fromJson(json['POD']) : null,
      shareToken: json['shareToken']?.toString(),
      shareTokenExpiry: JsonParser.extractDateTime(json['shareTokenExpiry']),
      createdAt: JsonParser.extractDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: JsonParser.extractDateTime(json['updatedAt']) ?? DateTime.now(),
      podDueAt: JsonParser.extractDateTime(json['podDueAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'driverId': driverId,
      'containerNumber': containerNumber,
      'reference': reference,
      'pickupLocation': pickupLocation?.toJson(),
      'dropLocation': dropLocation?.toJson(),
      'tripType': tripType,
    };
  }
}

class TripLocation {
  final String? address;
  final LocationCoordinates coordinates;

  TripLocation({
    this.address,
    required this.coordinates,
  });

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    return TripLocation(
      address: json['address'],
      coordinates: LocationCoordinates.fromJson(json['coordinates'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'coordinates': coordinates.toJson(),
    };
  }
}

class LocationCoordinates {
  final double latitude;
  final double longitude;

  LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  factory LocationCoordinates.fromJson(Map<String, dynamic> json) {
    return LocationCoordinates(
      latitude: JsonParser.extractDouble(json['latitude'], 0.0),
      longitude: JsonParser.extractDouble(json['longitude'], 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class MilestoneModel {
  final String milestoneType;
  final int milestoneNumber;
  final DateTime timestamp;
  final LocationCoordinates location;
  final String? photo;
  final String driverId;
  final String backendMeaning;

  MilestoneModel({
    required this.milestoneType,
    required this.milestoneNumber,
    required this.timestamp,
    required this.location,
    this.photo,
    required this.driverId,
    required this.backendMeaning,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    return MilestoneModel(
      milestoneType: JsonParser.extractString(json['milestoneType'], ''),
      milestoneNumber: JsonParser.extractInt(json['milestoneNumber'], 0),
      timestamp: JsonParser.extractDateTime(json['timestamp']) ?? DateTime.now(),
      location: LocationCoordinates.fromJson(json['location'] ?? {}),
      photo: json['photo']?.toString(),
      driverId: JsonParser.extractId(json['driverId']) ?? '',
      backendMeaning: JsonParser.extractString(json['backendMeaning'], ''),
    );
  }
}

class PODModel {
  final String? photo;
  final DateTime? uploadedAt;
  final String? uploadedBy;
  final DateTime? approvedAt;
  final String? approvedBy;

  PODModel({
    this.photo,
    this.uploadedAt,
    this.uploadedBy,
    this.approvedAt,
    this.approvedBy,
  });

  factory PODModel.fromJson(Map<String, dynamic> json) {
    return PODModel(
      photo: json['photo']?.toString(),
      uploadedAt: JsonParser.extractDateTime(json['uploadedAt']),
      uploadedBy: JsonParser.extractId(json['uploadedBy']),
      approvedAt: JsonParser.extractDateTime(json['approvedAt']),
      approvedBy: JsonParser.extractId(json['approvedBy']),
    );
  }
}

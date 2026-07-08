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

String? _driverMobileFromTripJson(Map<String, dynamic> json) {
  return _stringFieldFromMap(json['driverId'], 'mobile');
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

/// Server-driven flags for marketplace trips (`buyer` = read-only execution).
class TripCapabilities {
  final bool assignVehicle;
  final bool assignDriver;
  final bool updateTrip;
  final bool cancelTrip;
  final bool approvePod;
  final bool startTrip;
  final bool completeTrip;
  final bool shareTrip;
  final bool closeWithoutPod;

  const TripCapabilities({
    required this.assignVehicle,
    required this.assignDriver,
    required this.updateTrip,
    required this.cancelTrip,
    required this.approvePod,
    required this.startTrip,
    required this.completeTrip,
    required this.shareTrip,
    required this.closeWithoutPod,
  });

  /// API omitted [capabilities] → legacy / non-marketplace transporter (full control).
  static TripCapabilities? fromJson(dynamic json) {
    if (json == null || json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    bool b(String key, bool def) {
      final v = m[key];
      return v is bool ? v : def;
    }
    return TripCapabilities(
      assignVehicle: b('assignVehicle', true),
      assignDriver: b('assignDriver', true),
      updateTrip: b('updateTrip', true),
      cancelTrip: b('cancelTrip', true),
      approvePod: b('approvePod', true),
      startTrip: b('startTrip', true),
      completeTrip: b('completeTrip', true),
      shareTrip: b('shareTrip', true),
      closeWithoutPod: b('closeWithoutPod', true),
    );
  }
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

/// Last GPS fix persisted on the server for ACTIVE trips (seed map before next socket tick).
class LastDriverLocation {
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  LastDriverLocation({
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  static LastDriverLocation? fromJson(dynamic value) {
    if (value == null || value is! Map) return null;
    final m = Map<String, dynamic>.from(value);
    return LastDriverLocation(
      latitude: JsonParser.extractDouble(m['latitude'], 0),
      longitude: JsonParser.extractDouble(m['longitude'], 0),
      updatedAt: JsonParser.extractDateTime(m['updatedAt']),
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
  final String? driverMobile;
  final String? transporterName;
  final String? containerNumber;
  final List<TripAssignment>? assignments;
  final String? reference;
  final TripLocation? pickupLocation;
  final TripLocation? intermediateLocation;
  final TripLocation? dropLocation;
  final String tripType; // IMPORT, EXPORT, or LOCAL
  final String status; // PLANNED, ACTIVE, COMPLETED, POD_PENDING, CANCELLED
  final List<MilestoneModel> milestones;
  final PODModel? pod;
  final String? shareToken;
  final DateTime? shareTokenExpiry;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? podDueAt;
  final LastDriverLocation? lastDriverLocation;
  /// True when this trip was created from a marketplace vehicle booking (API: isFromBooking).
  final bool isFromBooking;
  /// `buyer` | `seller` when this trip is from a marketplace booking.
  final String? marketplaceRole;
  final TripCapabilities? capabilities;
  final int? queuePosition;
  final bool isQueued;
  final String? blockingTripId;

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
    this.driverMobile,
    this.transporterName,
    this.containerNumber,
    this.assignments,
    this.reference,
    this.pickupLocation,
    this.intermediateLocation,
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
    this.lastDriverLocation,
    this.isFromBooking = false,
    this.marketplaceRole,
    this.capabilities,
    this.queuePosition,
    this.isQueued = false,
    this.blockingTripId,
  });

  bool get isQueuedBlocked {
    if (!isQueued) return false;
    if (blockingTripId != null && blockingTripId != id) return true;
    return (queuePosition ?? 0) > 1;
  }

  bool get canAssignVehicle => capabilities?.assignVehicle ?? true;
  bool get canAssignDriver => capabilities?.assignDriver ?? true;
  bool get canUpdateTrip => capabilities?.updateTrip ?? true;
  bool get canCancelTrip => capabilities?.cancelTrip ?? true;
  bool get canApprovePod => capabilities?.approvePod ?? true;
  bool get canStartTrip => capabilities?.startTrip ?? true;
  bool get canCompleteTrip => capabilities?.completeTrip ?? true;
  bool get canShareTrip => capabilities?.shareTrip ?? true;
  bool get canCloseWithoutPod => capabilities?.closeWithoutPod ?? true;
  bool get isMarketplaceBuyerView => marketplaceRole == 'buyer';
  bool get isMarketplaceBookingTrip => isFromBooking || marketplaceRole != null;

  TripModel copyWith({
    String? id,
    String? tripId,
    String? transporterId,
    String? customerId,
    String? customerName,
    String? vehicleId,
    String? driverId,
    String? vehicleNumber,
    String? driverName,
    String? driverMobile,
    String? transporterName,
    String? containerNumber,
    List<TripAssignment>? assignments,
    String? reference,
    TripLocation? pickupLocation,
    TripLocation? intermediateLocation,
    TripLocation? dropLocation,
    String? tripType,
    String? status,
    List<MilestoneModel>? milestones,
    PODModel? pod,
    String? shareToken,
    DateTime? shareTokenExpiry,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? podDueAt,
    LastDriverLocation? lastDriverLocation,
    bool? isFromBooking,
    String? marketplaceRole,
    TripCapabilities? capabilities,
    int? queuePosition,
    bool? isQueued,
    String? blockingTripId,
  }) {
    return TripModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      transporterId: transporterId ?? this.transporterId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      vehicleId: vehicleId ?? this.vehicleId,
      driverId: driverId ?? this.driverId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverName: driverName ?? this.driverName,
      driverMobile: driverMobile ?? this.driverMobile,
      transporterName: transporterName ?? this.transporterName,
      containerNumber: containerNumber ?? this.containerNumber,
      assignments: assignments ?? this.assignments,
      reference: reference ?? this.reference,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      intermediateLocation: intermediateLocation ?? this.intermediateLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      tripType: tripType ?? this.tripType,
      status: status ?? this.status,
      milestones: milestones ?? this.milestones,
      pod: pod ?? this.pod,
      shareToken: shareToken ?? this.shareToken,
      shareTokenExpiry: shareTokenExpiry ?? this.shareTokenExpiry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      podDueAt: podDueAt ?? this.podDueAt,
      lastDriverLocation: lastDriverLocation ?? this.lastDriverLocation,
      isFromBooking: isFromBooking ?? this.isFromBooking,
      marketplaceRole: marketplaceRole ?? this.marketplaceRole,
      capabilities: capabilities ?? this.capabilities,
      queuePosition: queuePosition ?? this.queuePosition,
      isQueued: isQueued ?? this.isQueued,
      blockingTripId: blockingTripId ?? this.blockingTripId,
    );
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final customerIdData = json['customerId'];
    String? customerName;
    if (customerIdData is Map && customerIdData['name'] != null) {
      customerName = customerIdData['name']?.toString();
    }
    final isFromBookingFlag = json['isFromBooking'] == true ||
        json['isFromBooking']?.toString().toLowerCase() == 'true';
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
      driverMobile: _driverMobileFromTripJson(json),
      transporterName: _transporterDisplayNameFromTripJson(json),
      containerNumber: json['containerNumber']?.toString(),
      assignments: _parseAssignments(json['assignments']),
      reference: json['reference']?.toString(),
      pickupLocation: _parseTripLocation(json['pickupLocation']),
      intermediateLocation: _parseTripLocation(json['intermediateLocation']),
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
      lastDriverLocation: LastDriverLocation.fromJson(json['lastDriverLocation']),
      isFromBooking: isFromBookingFlag,
      marketplaceRole: json['marketplaceRole']?.toString(),
      capabilities: TripCapabilities.fromJson(json['capabilities']),
      queuePosition: json['queuePosition'] is num
          ? (json['queuePosition'] as num).toInt()
          : int.tryParse(json['queuePosition']?.toString() ?? ''),
      isQueued: json['isQueued'] == true ||
          json['isQueued']?.toString().toLowerCase() == 'true',
      blockingTripId: JsonParser.extractId(json['blockingTripId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'driverId': driverId,
      'containerNumber': containerNumber,
      'reference': reference,
      'pickupLocation': pickupLocation?.toJson(),
      'intermediateLocation': intermediateLocation?.toJson(),
      'dropLocation': dropLocation?.toJson(),
      'tripType': tripType,
    };
  }
}

class TripLocation {
  final String? address;
  final LocationCoordinates coordinates;
  final String? countryCode;

  TripLocation({
    this.address,
    required this.coordinates,
    this.countryCode,
  });

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    return TripLocation(
      address: json['address']?.toString() ??
          json['formattedAddress']?.toString(),
      coordinates: LocationCoordinates.fromJson(json['coordinates']),
      countryCode: json['countryCode']?.toString().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'coordinates': coordinates.toJson(),
      if (countryCode != null && countryCode!.isNotEmpty)
        'countryCode': countryCode,
    };
  }

  /// GeoJSON-shaped body for `POST/PUT /vehicle-posts` ([normalizeLocationInput] on API).
  /// Returns null if address is empty or coordinates are unset (0,0) or out of range.
  Map<String, dynamic>? toVehiclePostLocationPayload() {
    final addr = (address ?? '').trim();
    if (addr.isEmpty) return null;
    final lat = coordinates.latitude;
    final lng = coordinates.longitude;
    if (lng == 0 && lat == 0) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return {
      'type': 'Point',
      'formattedAddress': addr,
      'coordinates': [lng, lat],
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

  /// API GeoJSON Point uses `coordinates: [longitude, latitude]`; milestones use `{ latitude, longitude }`.
  factory LocationCoordinates.fromJson(dynamic json) {
    if (json == null) {
      return LocationCoordinates(latitude: 0, longitude: 0);
    }
    if (json is List) {
      if (json.length >= 2) {
        final lng = (json[0] as num).toDouble();
        final lat = (json[1] as num).toDouble();
        return LocationCoordinates(latitude: lat, longitude: lng);
      }
      return LocationCoordinates(latitude: 0, longitude: 0);
    }
    if (json is Map) {
      final m = Map<String, dynamic>.from(json);
      return LocationCoordinates(
        latitude: JsonParser.extractDouble(m['latitude'], 0.0),
        longitude: JsonParser.extractDouble(m['longitude'], 0.0),
      );
    }
    return LocationCoordinates(latitude: 0, longitude: 0);
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

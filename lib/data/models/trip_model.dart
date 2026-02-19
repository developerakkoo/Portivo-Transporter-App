import '../../core/utils/json_parser.dart';

class TripModel {
  final String id;
  final String tripId;
  final String transporterId;
  final String vehicleId;
  final String? driverId;
  final String? containerNumber;
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

  TripModel({
    required this.id,
    required this.tripId,
    required this.transporterId,
    required this.vehicleId,
    this.driverId,
    this.containerNumber,
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
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: JsonParser.extractString(json['_id'] ?? json['id'], ''),
      tripId: JsonParser.extractString(json['tripId'], ''),
      transporterId: JsonParser.extractId(json['transporterId']) ?? '',
      vehicleId: JsonParser.extractId(json['vehicleId']) ?? '',
      driverId: JsonParser.extractId(json['driverId']),
      containerNumber: json['containerNumber']?.toString(),
      reference: json['reference']?.toString(),
      pickupLocation: json['pickupLocation'] != null
          ? TripLocation.fromJson(json['pickupLocation'])
          : null,
      dropLocation: json['dropLocation'] != null
          ? TripLocation.fromJson(json['dropLocation'])
          : null,
      tripType: JsonParser.extractString(json['tripType'], 'EXPORT'),
      status: JsonParser.extractString(json['status'], 'PLANNED'),
      milestones: JsonParser.extractList<MilestoneModel>(
        json['milestones'],
        (json) => MilestoneModel.fromJson(json),
      ),
      pod: json['POD'] != null ? PODModel.fromJson(json['POD']) : null,
      shareToken: json['shareToken']?.toString(),
      shareTokenExpiry: JsonParser.extractDateTime(json['shareTokenExpiry']),
      createdAt: JsonParser.extractDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: JsonParser.extractDateTime(json['updatedAt']) ?? DateTime.now(),
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

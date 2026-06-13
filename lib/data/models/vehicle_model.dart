import '../../core/utils/json_parser.dart';

class VehicleModel {
  final String id;
  final String vehicleNumber;
  final String transporterId;
  final String ownerType; // OWN or HIRED
  final String? originalOwnerId;
  final List<String> hiredBy;
  final String? driverId;
  final String status;
  final String? trailerType;
  final String? vehicleType;
  final VehicleDocuments? documents;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleModel({
    required this.id,
    required this.vehicleNumber,
    required this.transporterId,
    required this.ownerType,
    this.originalOwnerId,
    required this.hiredBy,
    this.driverId,
    required this.status,
    this.trailerType,
    this.vehicleType,
    this.documents,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: JsonParser.extractString(json['_id'] ?? json['id'], ''),
      vehicleNumber: JsonParser.extractString(json['vehicleNumber'], ''),
      transporterId: JsonParser.extractId(json['transporterId']) ?? '',
      ownerType: JsonParser.extractString(json['ownerType'], 'OWN'),
      originalOwnerId: JsonParser.extractId(json['originalOwnerId']),
      hiredBy: JsonParser.extractIdList(json['hiredBy']),
      driverId: JsonParser.extractId(json['driverId']),
      status: JsonParser.extractString(json['status'], 'active'),
      trailerType: json['trailerType'] is String 
          ? json['trailerType'] as String?
          : json['trailerType']?.toString(),
      vehicleType: json['vehicleType'] is String
          ? json['vehicleType'] as String?
          : json['vehicleType']?.toString(),
      documents: json['documents'] != null && json['documents'] is Map
          ? VehicleDocuments.fromJson(json['documents'] as Map<String, dynamic>)
          : null,
      createdAt: JsonParser.extractDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: JsonParser.extractDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleNumber': vehicleNumber,
      'ownerType': ownerType,
      'trailerType': trailerType,
      if (vehicleType != null && vehicleType!.isNotEmpty) 'vehicleType': vehicleType,
      'driverId': driverId,
    };
  }
}

class VehicleDocuments {
  final DocumentInfo? rc;
  final DocumentInfo? insurance;
  final DocumentInfo? fitness;
  final DocumentInfo? permit;

  VehicleDocuments({
    this.rc,
    this.insurance,
    this.fitness,
    this.permit,
  });

  factory VehicleDocuments.fromJson(Map<String, dynamic> json) {
    return VehicleDocuments(
      rc: JsonParser.extractDocumentInfo(json['rc']),
      insurance: JsonParser.extractDocumentInfo(json['insurance']),
      fitness: JsonParser.extractDocumentInfo(json['fitness']),
      permit: JsonParser.extractDocumentInfo(json['permit']),
    );
  }
  
  // Helper getters for backward compatibility (extract URLs)
  String? get rcUrl => rc?.url;
  String? get insuranceUrl => insurance?.url;
  String? get fitnessUrl => fitness?.url;
  String? get permitUrl => permit?.url;
}

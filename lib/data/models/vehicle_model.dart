import '../../core/utils/json_parser.dart';
import 'driver_model.dart';
import 'rc_verification.dart';

class VehicleModel {
  final String id;
  final String vehicleNumber;
  final String transporterId;
  final String ownerType; // OWN or HIRED
  final String? originalOwnerId;
  final List<String> hiredBy;
  final String? driverId;
  final DriverModel? driver;
  final String status;
  final String? trailerType;
  final String? vehicleType;
  final double? cargoWeightMt;
  final VehicleDocuments? documents;
  final RcVerification? rcVerification;
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
    this.driver,
    required this.status,
    this.trailerType,
    this.vehicleType,
    this.cargoWeightMt,
    this.documents,
    this.rcVerification,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    DriverModel? nestedDriver;
    if (json['driver'] is Map) {
      nestedDriver = DriverModel.fromJson(
        Map<String, dynamic>.from(json['driver'] as Map),
      );
    } else if (json['driverId'] is Map) {
      nestedDriver = DriverModel.fromJson(
        Map<String, dynamic>.from(json['driverId'] as Map),
      );
    }

    return VehicleModel(
      id: JsonParser.extractString(json['_id'] ?? json['id'], ''),
      vehicleNumber: JsonParser.extractString(json['vehicleNumber'], ''),
      transporterId: JsonParser.extractId(json['transporterId']) ?? '',
      ownerType: JsonParser.extractString(json['ownerType'], 'OWN'),
      originalOwnerId: JsonParser.extractId(json['originalOwnerId']),
      hiredBy: JsonParser.extractIdList(json['hiredBy']),
      driverId: JsonParser.extractId(json['driverId']) ?? nestedDriver?.id,
      driver: nestedDriver,
      status: JsonParser.extractString(json['status'], 'active'),
      trailerType: json['trailerType'] is String
          ? json['trailerType'] as String?
          : json['trailerType']?.toString(),
      vehicleType: json['vehicleType'] is String
          ? json['vehicleType'] as String?
          : json['vehicleType']?.toString(),
      cargoWeightMt: JsonParser.extractNullableDouble(json['cargoWeightMt']),
      documents: json['documents'] != null && json['documents'] is Map
          ? VehicleDocuments.fromJson(json['documents'] as Map<String, dynamic>)
          : null,
      rcVerification: json['rcVerification'] is Map
          ? RcVerification.fromJson(
              Map<String, dynamic>.from(json['rcVerification'] as Map),
            )
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
      if (cargoWeightMt != null) 'cargoWeightMt': cargoWeightMt,
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

  String? get rcUrl => rc?.url;
  String? get insuranceUrl => insurance?.url;
  String? get fitnessUrl => fitness?.url;
  String? get permitUrl => permit?.url;
}

/// Vehicle plus the informational RC result from a 201 create.
class VehicleCreateResult {
  final VehicleModel vehicle;
  final RcVerification? verification;

  const VehicleCreateResult({
    required this.vehicle,
    this.verification,
  });
}

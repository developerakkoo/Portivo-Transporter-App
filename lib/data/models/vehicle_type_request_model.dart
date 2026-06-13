import '../../core/utils/json_parser.dart';

class VehicleTypeRequestModel {
  final String id;
  final String requestedName;
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? approvedVehicleTypeId;

  VehicleTypeRequestModel({
    required this.id,
    required this.requestedName,
    required this.status,
    this.createdAt,
    this.reviewedAt,
    this.rejectionReason,
    this.approvedVehicleTypeId,
  });

  factory VehicleTypeRequestModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeRequestModel(
      id: JsonParser.extractString(json['id'] ?? json['_id'], ''),
      requestedName: JsonParser.extractString(json['requestedName'], ''),
      status: JsonParser.extractString(json['status'], 'pending'),
      createdAt: JsonParser.extractDateTime(json['createdAt']),
      reviewedAt: JsonParser.extractDateTime(json['reviewedAt']),
      rejectionReason: json['rejectionReason']?.toString(),
      approvedVehicleTypeId: json['approvedVehicleTypeId']?.toString(),
    );
  }

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
}

import '../../core/utils/json_parser.dart';

/// Result of a `POST /api/vehicles/verify` (SurePass RC) check.
///
/// Parsed from both success (HTTP 200) and error (HTTP 4xx/5xx) response
/// bodies, which share the same shape.
class VehicleVerificationResult {
  final bool success;
  final bool isVerified;
  final int? statusCode;
  final String? message;
  final String? messageCode;

  VehicleVerificationResult({
    required this.success,
    required this.isVerified,
    this.statusCode,
    this.message,
    this.messageCode,
  });

  factory VehicleVerificationResult.fromJson(Map<String, dynamic> json) {
    return VehicleVerificationResult(
      success: JsonParser.extractBool(json['success'], false),
      isVerified: JsonParser.extractBool(json['isVerified'], false),
      statusCode: json['status_code'] != null
          ? JsonParser.extractInt(json['status_code'], 0)
          : null,
      message: json['message']?.toString(),
      messageCode: json['message_code']?.toString(),
    );
  }
}

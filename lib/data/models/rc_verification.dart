import '../../core/utils/json_parser.dart';

/// RC outcome from `POST /api/vehicles` (`data.verification` or `rcVerification`).
///
/// Provider payloads such as `rawResponse` and `messageCode` are intentionally
/// not parsed. UI copy comes from [status] only.
class RcVerification {
  final bool verified;
  final String status;
  final DateTime? checkedAt;
  final String? verifiedVehicleNumber;

  const RcVerification({
    required this.verified,
    required this.status,
    this.checkedAt,
    this.verifiedVehicleNumber,
  });

  bool get isVerified => verified || status.toLowerCase() == 'verified';

  factory RcVerification.fromJson(Map<String, dynamic> json) {
    return RcVerification(
      verified: JsonParser.extractBool(json['verified'], false),
      status: JsonParser.extractString(json['status'], 'pending'),
      checkedAt: JsonParser.extractDateTime(json['checkedAt']),
      verifiedVehicleNumber: json['verifiedVehicleNumber']?.toString(),
    );
  }
}

/// Snackbar copy after a successful create. Never uses the provider message.
String rcStatusLabel(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'verified':
      return 'RC verified';
    case 'not_verified':
      return 'Vehicle saved. RC could not be verified.';
    case 'timeout':
      return 'Vehicle saved. RC verification timed out.';
    case 'pending':
      return 'Vehicle saved. RC verification is pending.';
    case 'error':
    case 'not-configured':
    case 'unsupported':
      return 'Vehicle saved. RC verification is unavailable.';
    default:
      return 'Vehicle saved. RC verification is unavailable.';
  }
}

/// Short label for the vehicle list.
String rcStatusShortLabel(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'verified':
      return 'Verified';
    case 'not_verified':
      return 'Not verified';
    case 'timeout':
      return 'Timed out';
    case 'pending':
      return 'Pending';
    case 'error':
    case 'not-configured':
    case 'unsupported':
      return 'Unavailable';
    default:
      return 'Unavailable';
  }
}

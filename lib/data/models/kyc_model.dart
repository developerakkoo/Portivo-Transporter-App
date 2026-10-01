class KycBankDetails {
  const KycBankDetails({
    this.isAdded = false,
    this.accountHolderName,
    this.bankAccountLast4,
    this.ifscCode,
    this.bankName,
    this.source,
  });

  final bool isAdded;
  final String? accountHolderName;
  final String? bankAccountLast4;
  final String? ifscCode;
  final String? bankName;
  final String? source;

  factory KycBankDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const KycBankDetails();
    return KycBankDetails(
      isAdded: json['isAdded'] == true,
      accountHolderName: json['accountHolderName']?.toString(),
      bankAccountLast4: json['bankAccountLast4']?.toString(),
      ifscCode: json['ifscCode']?.toString(),
      bankName: json['bankName']?.toString(),
      source: json['source']?.toString(),
    );
  }
}

class TransporterKyc {
  const TransporterKyc({
    this.status = 'pending',
    this.isCompleted = false,
    this.panNumber,
    this.panImage,
    this.panImagePath,
    this.aadhaarNumber,
    this.aadhaarImage,
    this.aadhaarImagePath,
    this.aadhaarBackImage,
    this.aadhaarBackImagePath,
    this.bankDetails = const KycBankDetails(),
    this.submittedAt,
    this.updatedAt,
    this.adminReviewed = false,
    this.adminNotes,
    this.networkAccessGranted = false,
  });

  final String status;
  final bool isCompleted;
  final String? panNumber;
  final String? panImage;
  final String? panImagePath;
  final String? aadhaarNumber;
  final String? aadhaarImage;
  final String? aadhaarImagePath;
  final String? aadhaarBackImage;
  final String? aadhaarBackImagePath;
  final KycBankDetails bankDetails;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final bool adminReviewed;
  final String? adminNotes;
  final bool networkAccessGranted;

  bool get hasExistingPanImage =>
      (panImage != null && panImage!.trim().isNotEmpty) ||
      (panImagePath != null && panImagePath!.trim().isNotEmpty);

  bool get hasExistingAadhaarImage =>
      (aadhaarImage != null && aadhaarImage!.trim().isNotEmpty) ||
      (aadhaarImagePath != null && aadhaarImagePath!.trim().isNotEmpty);

  bool get hasExistingAadhaarBackImage =>
      (aadhaarBackImage != null && aadhaarBackImage!.trim().isNotEmpty) ||
      (aadhaarBackImagePath != null && aadhaarBackImagePath!.trim().isNotEmpty);

  bool get hasBeenSubmitted =>
      submittedAt != null ||
      (panNumber != null && panNumber!.trim().isNotEmpty) ||
      hasExistingPanImage ||
      hasExistingAadhaarImage;

  factory TransporterKyc.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TransporterKyc();
    return TransporterKyc(
      status: json['status']?.toString() ?? 'pending',
      isCompleted: json['isCompleted'] == true,
      panNumber: json['panNumber']?.toString(),
      panImage: json['panImage']?.toString(),
      panImagePath: json['panImagePath']?.toString(),
      aadhaarNumber: json['aadhaarNumber']?.toString(),
      aadhaarImage: json['aadhaarImage']?.toString(),
      aadhaarImagePath: json['aadhaarImagePath']?.toString(),
      aadhaarBackImage: json['aadhaarBackImage']?.toString(),
      aadhaarBackImagePath: json['aadhaarBackImagePath']?.toString(),
      bankDetails: json['bankDetails'] is Map
          ? KycBankDetails.fromJson(
              Map<String, dynamic>.from(json['bankDetails'] as Map),
            )
          : const KycBankDetails(),
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      adminReviewed: json['adminReviewed'] == true,
      adminNotes: json['adminNotes']?.toString(),
      networkAccessGranted: json['networkAccessGranted'] == true,
    );
  }
}

/// Remaining required KYC document, or null when PAN + Aadhaar docs exist.
String? kycMissingRequirement(TransporterKyc kyc) {
  if (kyc.panNumber == null || kyc.panNumber!.trim().isEmpty) {
    return 'PAN number is missing';
  }
  if (!kyc.hasExistingPanImage) return 'PAN image is missing';
  if (kyc.aadhaarNumber == null || kyc.aadhaarNumber!.trim().length != 12) {
    return 'Aadhaar number is missing';
  }
  if (!kyc.hasExistingAadhaarImage) return 'Aadhaar image is missing';
  return null;
}

/// Mask a KYC identifier, keeping the last [keepLast] characters.
String maskKycNumber(String? value, {int keepLast = 4}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '';
  if (text.length <= keepLast) return '*' * text.length;
  return '${'*' * (text.length - keepLast)}${text.substring(text.length - keepLast)}';
}

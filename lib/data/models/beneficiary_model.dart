/// Razorpay payout beneficiary (bank account for receiving payments).
class BeneficiaryModel {
  final String? name;
  final String? verificationStatus;
  final String? maskedAccountNumber;
  final String? ifsc;
  final String? phone;
  final String? razorpayContactId;
  final String? razorpayFundAccountId;
  final String? razorpayFundAccountStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;
  final DateTime? deletedAt;

  BeneficiaryModel({
    this.name,
    this.verificationStatus,
    this.maskedAccountNumber,
    this.ifsc,
    this.phone,
    this.razorpayContactId,
    this.razorpayFundAccountId,
    this.razorpayFundAccountStatus,
    this.createdAt,
    this.updatedAt,
    this.verifiedAt,
    this.deletedAt,
  });

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) {
    return BeneficiaryModel(
      name: json['name']?.toString(),
      verificationStatus: json['verificationStatus']?.toString(),
      maskedAccountNumber: json['maskedAccountNumber']?.toString(),
      ifsc: json['ifsc']?.toString(),
      phone: json['phone']?.toString(),
      razorpayContactId: json['razorpayContactId']?.toString(),
      razorpayFundAccountId: json['razorpayFundAccountId']?.toString(),
      razorpayFundAccountStatus: json['razorpayFundAccountStatus']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      verifiedAt: _parseDate(json['verifiedAt']),
      deletedAt: _parseDate(json['deletedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool get isDeleted =>
      deletedAt != null ||
      verificationStatus?.toUpperCase() == 'DELETED' ||
      razorpayFundAccountStatus?.toUpperCase() == 'DELETED';

  /// True when a Razorpay fund account is registered for payouts.
  bool get isActive =>
      !isDeleted &&
      razorpayFundAccountId != null &&
      razorpayFundAccountId!.trim().isNotEmpty;
}

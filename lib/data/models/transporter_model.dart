import '../../core/utils/json_parser.dart';

class TransporterModel {
  final String id;
  final String mobile;
  final String? name;
  final String? email;
  final String? company;
  final String operatingCountry;
  final String status;
  final bool hasAccess;
  final double walletBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? kycStatus;
  final bool isKycCompleted;
  final String? kycMessage;

  TransporterModel({
    required this.id,
    required this.mobile,
    this.name,
    this.email,
    this.company,
    this.operatingCountry = 'IN',
    required this.status,
    required this.hasAccess,
    required this.walletBalance,
    required this.createdAt,
    required this.updatedAt,
    this.kycStatus,
    this.isKycCompleted = false,
    this.kycMessage,
  });

  factory TransporterModel.fromJson(Map<String, dynamic> json) {
    return TransporterModel(
      id: JsonParser.extractString(json['_id'] ?? json['id'], ''),
      mobile: JsonParser.extractString(json['mobile'], ''),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      company: json['company']?.toString(),
      operatingCountry:
          JsonParser.extractString(json['operatingCountry'], 'IN').toUpperCase(),
      status: JsonParser.extractString(json['status'], 'pending'),
      hasAccess: JsonParser.extractBool(json['hasAccess'], false),
      walletBalance: JsonParser.extractDouble(json['walletBalance'], 0.0),
      createdAt: JsonParser.extractDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: JsonParser.extractDateTime(json['updatedAt']) ?? DateTime.now(),
      kycStatus: json['kycStatus']?.toString(),
      isKycCompleted: JsonParser.extractBool(json['isKycCompleted'], false),
      kycMessage: json['kycMessage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'company': company,
      'operatingCountry': operatingCountry,
    };
  }
}

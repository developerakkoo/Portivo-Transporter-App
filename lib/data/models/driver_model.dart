import '../../core/utils/json_parser.dart';

class DriverModel {
  final String id;
  final String mobile;
  final String? name;
  final String? transporterId;
  final String status;
  final String? riskLevel;
  final String? language;
  final double walletBalance;
  final String? alternateMobile;
  final String? licenseNumber;
  final DateTime? licenseValidTill;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverModel({
    required this.id,
    required this.mobile,
    this.name,
    this.transporterId,
    required this.status,
    this.riskLevel,
    this.language,
    required this.walletBalance,
    this.alternateMobile,
    this.licenseNumber,
    this.licenseValidTill,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: JsonParser.extractString(json['_id'] ?? json['id'], ''),
      mobile: JsonParser.extractString(json['mobile'], ''),
      name: json['name']?.toString(),
      transporterId: JsonParser.extractId(json['transporterId']),
      status: JsonParser.extractString(json['status'], 'pending'),
      riskLevel: json['riskLevel']?.toString(),
      language: json['language']?.toString(),
      walletBalance: JsonParser.extractDouble(json['walletBalance'], 0.0),
      alternateMobile: _optionalString(json['alternateMobile']),
      licenseNumber: _optionalString(json['licenseNumber']),
      licenseValidTill: JsonParser.extractDateTime(json['licenseValidTill']),
      createdAt: JsonParser.extractDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: JsonParser.extractDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'language': language,
    };
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

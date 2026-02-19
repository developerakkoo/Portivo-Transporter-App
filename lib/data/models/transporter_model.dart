import '../../core/utils/json_parser.dart';

class TransporterModel {
  final String id;
  final String mobile;
  final String? name;
  final String? email;
  final String? company;
  final String status;
  final bool hasAccess;
  final double walletBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransporterModel({
    required this.id,
    required this.mobile,
    this.name,
    this.email,
    this.company,
    required this.status,
    required this.hasAccess,
    required this.walletBalance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransporterModel.fromJson(Map<String, dynamic> json) {
    return TransporterModel(
      id: JsonParser.extractString(json['_id'] ?? json['id'], ''),
      mobile: JsonParser.extractString(json['mobile'], ''),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      company: json['company']?.toString(),
      status: JsonParser.extractString(json['status'], 'pending'),
      hasAccess: JsonParser.extractBool(json['hasAccess'], false),
      walletBalance: JsonParser.extractDouble(json['walletBalance'], 0.0),
      createdAt: JsonParser.extractDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: JsonParser.extractDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'company': company,
    };
  }
}

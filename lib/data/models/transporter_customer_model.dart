import '../../core/utils/json_parser.dart';

class TransporterCustomerModel {
  final String id;
  final String name;
  final DateTime? lastUsedAt;

  TransporterCustomerModel({
    required this.id,
    required this.name,
    this.lastUsedAt,
  });

  factory TransporterCustomerModel.fromJson(Map<String, dynamic> json) {
    return TransporterCustomerModel(
      id: JsonParser.extractString(json['id'] ?? json['_id'], ''),
      name: JsonParser.extractString(json['name'], ''),
      lastUsedAt: JsonParser.extractDateTime(json['lastUsedAt']),
    );
  }
}

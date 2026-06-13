import '../../core/utils/json_parser.dart';

class VehicleTypeModel {
  final String id;
  final String name;
  final String? code;
  final String? description;

  VehicleTypeModel({
    required this.id,
    required this.name,
    this.code,
    this.description,
  });

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: JsonParser.extractString(json['id'] ?? json['_id'], ''),
      name: JsonParser.extractString(json['name'], ''),
      code: json['code'] is String ? json['code'] as String? : json['code']?.toString(),
      description: json['description'] is String
          ? json['description'] as String?
          : json['description']?.toString(),
    );
  }
}

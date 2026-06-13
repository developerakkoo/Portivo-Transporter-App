import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/utils/json_parser.dart';
import '../data/models/vehicle_type_model.dart';
import '../data/models/vehicle_type_request_model.dart';
import 'api_service.dart';

class VehicleTypeService {
  final ApiService _api = ApiService();

  Future<List<VehicleTypeModel>> getActiveTypes({String? query}) async {
    try {
      final response = await _api.get(
        ApiConfig.vehicleTypes,
        queryParameters: query != null && query.trim().isNotEmpty
            ? {'q': query.trim()}
            : null,
      );
      if (response.data['success'] == true) {
        final results = response.data['data']?['results'];
        if (results is List) {
          return JsonParser.extractList<VehicleTypeModel>(
            results,
            (json) => VehicleTypeModel.fromJson(json),
          );
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleTypeService: Error fetching types: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<VehicleTypeRequestModel>> getMyRequests() async {
    try {
      final response = await _api.get(ApiConfig.vehicleTypeRequestsMine);
      if (response.data['success'] == true) {
        final results = response.data['data']?['results'];
        if (results is List) {
          return JsonParser.extractList<VehicleTypeRequestModel>(
            results,
            (json) => VehicleTypeRequestModel.fromJson(json),
          );
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleTypeService: Error fetching my requests: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<VehicleTypeRequestModel> submitRequest(String name) async {
    final response = await _api.post(
      ApiConfig.vehicleTypeRequests,
      data: {'name': name.trim()},
    );

    if (response.data['success'] == true) {
      final request = response.data['data']?['request'];
      if (request is Map) {
        return VehicleTypeRequestModel.fromJson(
          Map<String, dynamic>.from(request),
        );
      }
    }

    throw Exception(response.data['message'] ?? 'Failed to submit vehicle type request');
  }
}

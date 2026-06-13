import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/utils/json_parser.dart';
import '../data/models/driver_model.dart';
import 'api_service.dart';

class DriverService {
  final ApiService _api = ApiService();

  Future<List<DriverModel>> getDriversByTransporter(
    String transporterId, {
    bool availableForTrip = false,
  }) async {
    try {
      if (kDebugMode) {
        print('DriverService: Fetching drivers for transporter: $transporterId');
      }

      final queryParams = <String, dynamic>{};
      if (availableForTrip) queryParams['availableForTrip'] = 'true';
      
      final response = await _api.get(
        ApiConfig.getDriversByTransporter(transporterId),
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> driversData = [];
        
        // Handle both response formats
        if (data is List) {
          driversData = data;
        } else if (data is Map && data['drivers'] != null) {
          final drivers = data['drivers'];
          if (drivers is List) {
            driversData = drivers;
          }
        }
        
        if (driversData.isNotEmpty) {
          return JsonParser.extractList<DriverModel>(
            driversData,
            (json) => DriverModel.fromJson(json),
          );
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DriverService: Error fetching drivers: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<DriverModel?> getDriverById(String id) async {
    try {
      if (kDebugMode) {
        print('DriverService: Fetching driver by id: $id');
      }
      
      final response = await _api.get(ApiConfig.driverById(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['driver'] != null) {
          return DriverModel.fromJson(data['driver']);
        }
        if (data != null) {
          return DriverModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DriverService: Error fetching driver: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<DriverModel?> createDriver({
    required String mobile,
    required String name,
    String? status,
  }) async {
    try {
      if (kDebugMode) {
        print('DriverService: Creating driver: $name, $mobile');
      }

      final response = await _api.post(
        ApiConfig.drivers,
        data: {
          'mobile': mobile,
          'name': name,
          if (status != null) 'status': status,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['driver'] != null) {
          return DriverModel.fromJson(data['driver']);
        }
        if (data != null) {
          return DriverModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DriverService: Error creating driver: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<DriverModel?> updateDriver({
    required String id,
    String? name,
    String? status,
  }) async {
    try {
      if (kDebugMode) {
        print('DriverService: Updating driver: $id');
      }

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (status != null) updateData['status'] = status;

      final response = await _api.put(
        ApiConfig.driverById(id),
        data: updateData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['driver'] != null) {
          return DriverModel.fromJson(data['driver']);
        }
        if (data != null) {
          return DriverModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DriverService: Error updating driver: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> deleteDriver(String id) async {
    try {
      if (kDebugMode) {
        print('DriverService: Deleting driver: $id');
      }

      final response = await _api.delete(ApiConfig.driverById(id));

      return response.data['success'] == true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DriverService: Error deleting driver: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

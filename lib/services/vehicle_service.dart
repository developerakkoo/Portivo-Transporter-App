import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/utils/json_parser.dart';
import '../data/models/vehicle_model.dart';
import '../data/models/trip_model.dart';
import '../data/models/fleet_import_result.dart';
import '../data/models/vehicle_verification_result.dart';
import 'api_service.dart';

class VehicleService {
  final ApiService _api = ApiService();

  Never _throwApiFailure(dynamic data, {required String fallback}) {
    if (data is Map) {
      final message = data['message']?.toString();
      throw Exception(message ?? fallback);
    }
    throw Exception(fallback);
  }

  Future<List<VehicleModel>> getVehicles({
    String? status,
    String? ownerType,
    String? driverId,
    bool availableForTrip = false,
  }) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Fetching vehicles');
      }
      
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (ownerType != null) queryParams['ownerType'] = ownerType;
      if (driverId != null) queryParams['driverId'] = driverId;
      if (availableForTrip) queryParams['availableForTrip'] = 'true';

      final response = await _api.get(
        ApiConfig.vehicles,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> vehiclesData = [];
        
        // Handle both response formats
        if (data is List) {
          vehiclesData = data;
        } else if (data is Map && data['vehicles'] != null) {
          final vehicles = data['vehicles'];
          if (vehicles is List) {
            vehiclesData = vehicles;
          }
        }
        
        if (vehiclesData.isNotEmpty) {
          return JsonParser.extractList<VehicleModel>(
            vehiclesData,
            (json) => VehicleModel.fromJson(json),
          );
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error fetching vehicles: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<VehicleModel?> getVehicleById(String id) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Fetching vehicle by id: $id');
      }
      
      final response = await _api.get(ApiConfig.vehicleById(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['vehicle'] != null) {
          return VehicleModel.fromJson(data['vehicle']);
        }
        // Fallback
        if (data != null) {
          return VehicleModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error fetching vehicle: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<VehicleModel?> createVehicle(Map<String, dynamic> vehicleData) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Creating vehicle');
      }
      
      final response = await _api.post(
        ApiConfig.vehicles,
        data: vehicleData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['vehicle'] != null) {
          return VehicleModel.fromJson(data['vehicle']);
        }
        // Fallback
        if (data != null) {
          return VehicleModel.fromJson(data);
        }
      }
      _throwApiFailure(response.data, fallback: 'Failed to create vehicle');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error creating vehicle: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  /// Verifies a vehicle registration number via SurePass RC (`POST /vehicles/verify`).
  ///
  /// Always returns a result (never rethrows): non-2xx responses throw a
  /// [DioException], whose body carries the same shape and is parsed so the UI
  /// can still show a message. A gateway outage surfaces as an unverified
  /// result rather than breaking the form.
  Future<VehicleVerificationResult> verifyVehicleNumber(String vehicleNumber) async {
    try {
      final response = await _api.post(
        ApiConfig.vehiclesVerify,
        data: {'vehicleNumber': vehicleNumber},
      );
      final data = response.data;
      if (data is Map) {
        return VehicleVerificationResult.fromJson(Map<String, dynamic>.from(data));
      }
      return VehicleVerificationResult(success: false, isVerified: false);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        return VehicleVerificationResult.fromJson(Map<String, dynamic>.from(data));
      }
      return VehicleVerificationResult(
        success: false,
        isVerified: false,
        message: 'Could not verify vehicle. Please check your connection.',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error verifying vehicle: $e');
        print('Stack: $stackTrace');
      }
      return VehicleVerificationResult(
        success: false,
        isVerified: false,
        message: 'Verification failed',
      );
    }
  }

  Future<VehicleModel?> updateVehicle(String id, Map<String, dynamic> vehicleData) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Updating vehicle: $id');
      }
      
      final response = await _api.put(
        ApiConfig.vehicleById(id),
        data: vehicleData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['vehicle'] != null) {
          return VehicleModel.fromJson(data['vehicle']);
        }
        // Fallback
        if (data != null) {
          return VehicleModel.fromJson(data);
        }
      }
      _throwApiFailure(response.data, fallback: 'Failed to update vehicle');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error updating vehicle: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Deleting vehicle: $id');
      }
      
      final response = await _api.delete(ApiConfig.vehicleById(id));

      if (response.data['success'] == true) {
        return true;
      }
      _throwApiFailure(response.data, fallback: 'Failed to delete vehicle');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error deleting vehicle: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<TripModel>> getVehicleTrips(String id) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Fetching trips for vehicle: $id');
      }
      
      final response = await _api.get(ApiConfig.vehicleById(id) + '/trips');

      if (response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> tripsData = [];
        
        // Handle both response formats
        if (data is List) {
          tripsData = data;
        } else if (data is Map && data['trips'] != null) {
          final trips = data['trips'];
          if (trips is List) {
            tripsData = trips;
          }
        }
        
        if (tripsData.isNotEmpty) {
          return JsonParser.extractList<TripModel>(
            tripsData,
            (json) => TripModel.fromJson(json),
          );
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error fetching vehicle trips: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getVehicleAvailability(String id) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Checking availability for vehicle: $id');
      }
      
      final response = await _api.get(ApiConfig.vehicleAvailability(id));

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error checking availability: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> uploadVehicleDocument(
    String id,
    String documentType,
    String filePath, {
    DateTime? expiryDate,
  }) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Uploading document for vehicle: $id');
      }
      
      final formData = FormData.fromMap({
        'documentType': documentType,
        'file': await MultipartFile.fromFile(filePath),
        if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
      });

      final response = await _api.postMultipart(
        ApiConfig.vehicleDocuments(id),
        formData: formData,
      );

      return response.data['success'] == true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error uploading document: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  /// Uploads an xlsx/csv spreadsheet to bulk-import fleet (vehicles + drivers).
  Future<FleetImportResult> bulkImportFleet(String filePath) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Bulk importing fleet from: $filePath');
      }

      final filename = filePath.split(RegExp(r'[\\/]+')).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });

      final response = await _api.postMultipart(
        ApiConfig.vehiclesBulkImport,
        formData: formData,
      );

      if (response.data['success'] == true) {
        return FleetImportResult.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      _throwApiFailure(response.data, fallback: 'Failed to import fleet');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error importing fleet: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getVehicleDocuments(String id) async {
    try {
      if (kDebugMode) {
        print('VehicleService: Fetching documents for vehicle: $id');
      }
      
      final response = await _api.get(ApiConfig.vehicleDocuments(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['documents'] != null) {
          return List<Map<String, dynamic>>.from(data['documents']);
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('VehicleService: Error fetching documents: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

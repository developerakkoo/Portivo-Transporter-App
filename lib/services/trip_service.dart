import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/utils/json_parser.dart';
import '../data/models/trip_model.dart';
import 'api_service.dart';

class TripService {
  final ApiService _api = ApiService();

  Future<List<TripModel>> getTrips({
    String? status,
    String? vehicleId,
    String? driverId,
    String? tripType,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null) queryParams['status'] = status;
      if (vehicleId != null) queryParams['vehicleId'] = vehicleId;
      if (driverId != null) queryParams['driverId'] = driverId;
      if (tripType != null) queryParams['tripType'] = tripType;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _api.get(
        ApiConfig.trips,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> tripsData = [];
        
        // Handle both response formats:
        // Format 1: data: trips (array directly) - used by GET /api/trips
        // Format 2: data: {trips: [...]} - used by some other endpoints
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
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> getTripById(String id) async {
    try {
      if (kDebugMode) {
        print('TripService: Fetching trip by ID: $id');
      }
      
      final response = await _api.get(ApiConfig.tripById(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        
        // Handle array response (if API returns array)
        if (data is List && data.isNotEmpty) {
          if (kDebugMode) {
            print('TripService: API returned array format, finding trip with ID: $id');
          }
          // Find trip with matching ID or take first element
          try {
            final tripData = data.firstWhere(
              (trip) => (trip['_id'] ?? trip['id'] ?? '').toString() == id,
              orElse: () => data.first,
            );
            if (tripData is Map<String, dynamic>) {
              return TripModel.fromJson(tripData);
            } else if (tripData is Map) {
              return TripModel.fromJson(Map<String, dynamic>.from(tripData));
            }
          } catch (e) {
            // If firstWhere fails, use first element
            if (kDebugMode) {
              print('TripService: Could not find exact match, using first element');
            }
            final firstTrip = data.first;
            if (firstTrip is Map<String, dynamic>) {
              return TripModel.fromJson(firstTrip);
            } else if (firstTrip is Map) {
              return TripModel.fromJson(Map<String, dynamic>.from(firstTrip));
            }
          }
        }
        
        // Handle object response with 'trip' property
        if (data != null && data is Map && data['trip'] != null) {
          if (kDebugMode) {
            print('TripService: Found trip in data.trip');
          }
          final tripData = data['trip'];
          if (tripData is Map<String, dynamic>) {
            return TripModel.fromJson(tripData);
          } else if (tripData is Map) {
            return TripModel.fromJson(Map<String, dynamic>.from(tripData));
          }
        }
        
        // Fallback: data is single trip object
        if (data != null && data is Map) {
          if (kDebugMode) {
            print('TripService: Using data as single trip object');
          }
          if (data is Map<String, dynamic>) {
            return TripModel.fromJson(data);
          } else {
            return TripModel.fromJson(Map<String, dynamic>.from(data));
          }
        }
        
        if (kDebugMode) {
          print('TripService: No valid trip data found in response');
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TripService: Error fetching trip by ID: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<TripModel?> createTrip(Map<String, dynamic> tripData) async {
    try {
      final response = await _api.post(
        ApiConfig.trips,
        data: tripData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['trip'] != null) {
          return TripModel.fromJson(data['trip']);
        }
        // Fallback
        if (data != null) {
          return TripModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> updateTrip(String id, Map<String, dynamic> tripData) async {
    try {
      final response = await _api.put(
        ApiConfig.updateTrip(id),
        data: tripData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['trip'] != null) {
          return TripModel.fromJson(data['trip']);
        }
        // Fallback
        if (data != null) {
          return TripModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> cancelTrip(String id) async {
    try {
      final response = await _api.put(ApiConfig.tripCancel(id));

      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> startTrip(String id) async {
    try {
      final response = await _api.put(ApiConfig.tripStart(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['trip'] != null) {
          return TripModel.fromJson(data['trip']);
        }
        // Fallback
        if (data != null) {
          return TripModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> completeTrip(String id) async {
    try {
      final response = await _api.put(ApiConfig.tripComplete(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['trip'] != null) {
          return TripModel.fromJson(data['trip']);
        }
        // Fallback
        if (data != null) {
          return TripModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TripModel>> searchTrips({
    required String query,
  }) async {
    try {
      if (kDebugMode) {
        print('TripService: Searching trips with query: $query');
      }
      
      final response = await _api.get(
        ApiConfig.tripsSearch,
        queryParameters: {'q': query},
      );

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
        print('TripService: Error searching trips: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<TripModel>> getTripsByStatus(String status, {int page = 1, int limit = 20}) async {
    try {
      final queryParams = {
        'page': page,
        'limit': limit,
      };

      final response = await _api.get(
        ApiConfig.tripsByStatus(status),
        queryParameters: queryParams,
      );

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
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCurrentMilestone(String tripId) async {
    try {
      final response = await _api.get(ApiConfig.tripCurrentMilestone(tripId));

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getTripTimeline(String tripId) async {
    try {
      final response = await _api.get(ApiConfig.tripTimeline(tripId));

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TripModel>> getActiveTrips() async {
    try {
      if (kDebugMode) {
        print('TripService: Fetching active trips');
      }
      
      final response = await _api.get(ApiConfig.tripsActive);

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
        print('TripService: Error fetching active trips: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPendingPODTrips({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      if (kDebugMode) {
        print('TripService: Fetching pending POD trips');
      }
      
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      final response = await _api.get(
        ApiConfig.tripsPendingPOD,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        return response.data['data'] ?? {};
      }
      
      return {};
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TripService: Error fetching pending POD trips: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<TripModel?> uploadPOD(String tripId, String photoPath) async {
    try {
      if (kDebugMode) {
        print('TripService: Uploading POD for trip: $tripId');
      }
      
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photoPath),
      });

      final response = await _api.postMultipart(
        ApiConfig.tripPOD(tripId),
        formData: formData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['trip'] != null) {
          return TripModel.fromJson(data['trip']);
        }
        if (data != null) {
          return TripModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TripService: Error uploading POD: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<TripModel?> approvePOD(String tripId) async {
    try {
      if (kDebugMode) {
        print('TripService: Approving POD for trip: $tripId');
      }
      
      final response = await _api.put(ApiConfig.tripPODApprove(tripId));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['trip'] != null) {
          return TripModel.fromJson(data['trip']);
        }
        if (data != null) {
          return TripModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TripService: Error approving POD: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> shareTrip(String tripId, {int expiryHours = 24}) async {
    try {
      if (kDebugMode) {
        print('TripService: Generating share link for trip: $tripId');
      }
      
      final response = await _api.post(
        ApiConfig.tripShare(tripId),
        data: {'expiryHours': expiryHours},
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TripService: Error sharing trip: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<TripModel?> getSharedTrip(String token) async {
    try {
      if (kDebugMode) {
        print('TripService: Fetching shared trip with token');
      }
      
      final response = await _api.get(ApiConfig.sharedTrip(token));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['trip'] != null) {
          return TripModel.fromJson(data['trip']);
        }
        if (data != null) {
          return TripModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TripService: Error fetching shared trip: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

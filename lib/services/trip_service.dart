import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/utils/json_parser.dart';
import '../data/models/trip_model.dart';
import 'api_service.dart';

/// Trip API client. Status transitions (source of truth in repo):
///
/// **Transporter-created:** `POST /api/trips` → `PLANNED` (`trip.controller.js` createTrip).
/// **Customer book:** `BOOKED` + `OPEN` (no transporter yet) → marketplace list, not main `GET /trips`.
/// **Accept customer trip:** `PUT .../accept` → `ACCEPTED`, `transporterId` set (`acceptCustomerTrip`).
/// **Assign vehicle/driver (customer trip):** `ACCEPTED` → `PLANNED` when both assigned (`finalizeAssignmentState`).
/// **Driver:** `PUT .../accept-driver` (PLANNED, sets `driverAcceptedAt`) → `PUT .../start` → `ACTIVE` →
/// milestones → `PUT .../complete` → `POD_PENDING` (`tripStatus.controller.js`).
///
/// See also [TripProvider.loadTrips] for how the transporter list is loaded.
class TripService {
  final ApiService _api = ApiService();

  static List<TripModel> _parseTripsList(List<dynamic> tripsData) {
    final out = <TripModel>[];
    for (final raw in tripsData) {
      if (raw == null || raw is! Map) continue;
      try {
        final m = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw);
        out.add(TripModel.fromJson(m));
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('TripService: Skipping trip in getTrips (parse error): $e');
          print(stackTrace);
        }
      }
    }
    return out;
  }

  static List<dynamic> _extractTripsArray(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map && data['trips'] != null) {
      final trips = data['trips'];
      if (trips is List) {
        return trips;
      }
    }
    return [];
  }

  static int _totalPagesFromPagination(
    dynamic pagination,
    int limitPerPage,
    int tripsOnPage,
  ) {
    if (pagination is! Map) {
      return tripsOnPage == 0 ? 0 : 1;
    }
    final pages = pagination['pages'];
    if (pages is int) return pages;
    if (pages is num) return pages.toInt();
    final total = pagination['total'];
    if (total is num && limitPerPage > 0) {
      return (total / limitPerPage).ceil();
    }
    return tripsOnPage == 0 ? 0 : 1;
  }

  /// GET /api/trips — sorted by `createdAt` descending on the server.
  ///
  /// When [fetchAllPages] is true, loads every page (using [limit] per request, up to [maxPages])
  /// so older PLANNED/ACCEPTED trips are not missing from the transporter list.
  Future<List<TripModel>> getTrips({
    String? status,
    String? vehicleId,
    String? driverId,
    String? tripType,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 100,
    bool fetchAllPages = false,
    int maxPages = 50,
  }) async {
    try {
      if (fetchAllPages) {
        final merged = <TripModel>[];
        final seenIds = <String>{};
        var currentPage = 1;
        while (currentPage <= maxPages) {
          final pageTrips = await _getTripsPage(
            status: status,
            vehicleId: vehicleId,
            driverId: driverId,
            tripType: tripType,
            startDate: startDate,
            endDate: endDate,
            page: currentPage,
            limit: limit,
          );
          final totalPages = pageTrips.totalPages;
          for (final t in pageTrips.trips) {
            if (seenIds.add(t.id)) {
              merged.add(t);
            }
          }
          if (pageTrips.trips.isEmpty) break;
          if (currentPage >= totalPages || totalPages == 0) break;
          currentPage++;
        }
        return merged;
      }

      final one = await _getTripsPage(
        status: status,
        vehicleId: vehicleId,
        driverId: driverId,
        tripType: tripType,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
      );
      return one.trips;
    } catch (e) {
      rethrow;
    }
  }

  Future<({List<TripModel> trips, int totalPages})> _getTripsPage({
    String? status,
    String? vehicleId,
    String? driverId,
    String? tripType,
    String? startDate,
    String? endDate,
    required int page,
    required int limit,
  }) async {
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

    if (response.data['success'] != true) {
      return (trips: <TripModel>[], totalPages: 0);
    }

    final data = response.data['data'];
    final tripsData = _extractTripsArray(data);
    if (tripsData.isEmpty) {
      return (trips: <TripModel>[], totalPages: 0);
    }

    final trips = _parseTripsList(tripsData);
    final pagination = response.data['pagination'];
    final totalPages = _totalPagesFromPagination(pagination, limit, trips.length);

    return (trips: trips, totalPages: totalPages);
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

  Future<TripModel?> closeTripWithoutPOD(String id) async {
    try {
      final response = await _api.put(ApiConfig.tripCloseWithoutPOD(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null) {
          return TripModel.fromJson(data is Map ? Map<String, dynamic>.from(data) : {});
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

  Future<List<TripModel>> getAvailableCustomerTrips({
    int page = 1,
    int limit = 20,
    String? tripType,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (tripType != null) queryParams['tripType'] = tripType;

      final response = await _api.get(
        ApiConfig.tripsCustomerAvailable,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> tripsData = [];

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

  Future<TripModel?> acceptCustomerTrip(String tripId) async {
    try {
      final response = await _api.put(ApiConfig.tripAccept(tripId));

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
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> rejectCustomerTrip(String tripId) async {
    try {
      final response = await _api.put(ApiConfig.tripReject(tripId));
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> assignVehicle(String tripId, String vehicleId) async {
    try {
      final response = await _api.put(
        ApiConfig.tripAssignVehicle(tripId),
        data: {'vehicleId': vehicleId},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data is Map) {
          return TripModel.fromJson(data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data));
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> assignDriver(String tripId, String driverId) async {
    try {
      final response = await _api.put(
        ApiConfig.tripAssignDriver(tripId),
        data: {'driverId': driverId},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data is Map) {
          return TripModel.fromJson(data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data));
        }
      }
      return null;
    } catch (e) {
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

  Future<TripModel?> saveTripDraft(Map<String, dynamic> draftData) async {
    try {
      final response = await _api.post(
        ApiConfig.tripDrafts,
        data: draftData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data is Map) {
          return TripModel.fromJson(
            data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data),
          );
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TripModel>> listTripDrafts() async {
    try {
      final response = await _api.get(ApiConfig.tripDrafts);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data is List && data.isNotEmpty) {
          return _parseTripsList(data);
        }
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> getTripDraft(String id) async {
    try {
      final response = await _api.get(ApiConfig.tripDraftById(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data is Map) {
          return TripModel.fromJson(
            data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data),
          );
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteTripDraft(String id) async {
    try {
      final response = await _api.delete(ApiConfig.tripDraftById(id));
      return response.data['success'] == true;
    } catch (e) {
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

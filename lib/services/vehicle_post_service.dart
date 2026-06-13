import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/vehicle_post_model.dart';
import 'api_service.dart';

class VehiclePostSearchResult {
  VehiclePostSearchResult({required this.results, required this.total});

  final List<VehiclePostModel> results;
  final int total;
}

class VehiclePostService {
  final ApiService _api = ApiService();

  /// GeoJSON Point body for vehicle posts without map coordinates ([vehiclePost.controller] `requireCoordinates: false`).
  static Map<String, dynamic> textOnlyLocation(String address) {
    return {
      'type': 'Point',
      'formattedAddress': address.trim(),
      'coordinates': <double>[],
    };
  }

  /// GET /api/vehicle-posts — search active availability posts.
  Future<VehiclePostSearchResult> search({
    String? origin,
    String? destination,
    DateTime? date,
    String? vehicleType,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (origin != null && origin.trim().isNotEmpty) {
      query['origin'] = origin.trim();
    }
    if (destination != null && destination.trim().isNotEmpty) {
      query['destination'] = destination.trim();
    }
    if (vehicleType != null && vehicleType.trim().isNotEmpty) {
      query['vehicleType'] = vehicleType.trim();
    }
    if (date != null) {
      query['date'] = date.toUtc().toIso8601String();
    }

    try {
      final response = await _api.get(
        ApiConfig.vehiclePosts,
        queryParameters: query,
      );

      final body = response.data;
      if (body is! Map) {
        throw Exception('Invalid response');
      }
      if (body['success'] != true) {
        throw Exception(body['message']?.toString() ?? 'Search failed');
      }

      final data = body['data'];
      if (data is! Map) {
        return VehiclePostSearchResult(results: [], total: 0);
      }

      final rawList = data['results'];
      final total = data['total'] is num ? (data['total'] as num).toInt() : 0;
      final results = <VehiclePostModel>[];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map) {
            final m = VehiclePostModel.fromJson(Map<String, dynamic>.from(item));
            if (m != null) results.add(m);
          }
        }
      }

      return VehiclePostSearchResult(results: results, total: total);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('VehiclePostService.search: $e');
      }
      throw Exception(_messageFromDio(e));
    }
  }

  /// GET /api/vehicle-posts/mine
  Future<List<VehiclePostModel>> fetchMine() async {
    try {
      final response = await _api.get(ApiConfig.vehiclePostsMine);
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
        );
      }
      final data = body['data'];
      if (data is! Map) return [];
      final rawList = data['results'];
      final out = <VehiclePostModel>[];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map) {
            final m = VehiclePostModel.fromJson(Map<String, dynamic>.from(item));
            if (m != null) out.add(m);
          }
        }
      }
      return out;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('VehiclePostService.fetchMine: $e');
      }
      throw Exception(_messageFromDio(e));
    }
  }

  /// GET /api/vehicle-posts/:id
  Future<VehiclePostModel> fetchById(String id) async {
    try {
      final response = await _api.get(ApiConfig.vehiclePostById(id));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Not found' : 'Not found',
        );
      }
      final data = body['data'];
      if (data is! Map || data['post'] is! Map) {
        throw Exception('Invalid response');
      }
      final post =
          VehiclePostModel.fromJson(Map<String, dynamic>.from(data['post'] as Map));
      if (post == null) throw Exception('Invalid post');
      return post;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('VehiclePostService.fetchById: $e');
      }
      throw Exception(_messageFromDio(e));
    }
  }

  /// DELETE /api/vehicle-posts/:id — cancel (owner)
  Future<VehiclePostModel> cancel(String id) async {
    try {
      final response = await _api.delete(ApiConfig.vehiclePostById(id));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Cancel failed' : 'Cancel failed',
        );
      }
      final data = body['data'];
      if (data is Map && data['post'] is Map) {
        final post =
            VehiclePostModel.fromJson(Map<String, dynamic>.from(data['post'] as Map));
        if (post != null) return post;
      }
      return (await fetchById(id));
    } on DioException catch (e) {
      if (kDebugMode) {
        print('VehiclePostService.cancel: $e');
      }
      throw Exception(_messageFromDio(e));
    }
  }

  /// POST /api/vehicle-posts — create availability post.
  Future<VehiclePostModel?> create({
    required String vehicleType,
    required String originAddress,
    List<String> destinationAddresses = const [],
    List<int> destinationQuantities = const [],
    required DateTime availableFrom,
    DateTime? availableTo,
    int? durationDays,
    String? vehicleId,
    int? quantity,
    String? note,
    num? pricePerVehicle,
  }) async {
    final originTrim = originAddress.trim();
    if (originTrim.isEmpty) {
      throw Exception('Origin is required');
    }
    final destObjects = destinationAddresses
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(textOnlyLocation)
        .toList();
    final payload = <String, dynamic>{
      'vehicleType': vehicleType,
      'origin': textOnlyLocation(originTrim),
      'availableFrom': availableFrom.toUtc().toIso8601String(),
      if (availableTo != null)
        'availableTo': availableTo.toUtc().toIso8601String(),
      if (durationDays != null && durationDays > 0) 'durationDays': durationDays,
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      if (destinationQuantities.isNotEmpty)
        'destinationQuantities': destinationQuantities
      else if (quantity != null && quantity > 0)
        'quantity': quantity,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (pricePerVehicle != null) 'pricePerVehicle': pricePerVehicle,
      if (destObjects.isNotEmpty) 'destinations': destObjects,
    };

    try {
      final response = await _api.post(ApiConfig.vehiclePosts, data: payload);
      final body = response.data;
      if (body is! Map) {
        throw Exception('Invalid response');
      }
      if (body['success'] != true) {
        throw Exception(body['message']?.toString() ?? 'Could not post');
      }
      final data = body['data'];
      if (data is Map && data['post'] is Map) {
        return VehiclePostModel.fromJson(
          Map<String, dynamic>.from(data['post'] as Map),
        );
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('VehiclePostService.create: $e');
      }
      final msg = _messageFromDio(e);
      throw Exception(msg);
    }
  }

  /// PUT /api/vehicle-posts/:id — update availability post (owner).
  Future<VehiclePostModel> update(
    String id, {
    required String vehicleType,
    required String originAddress,
    List<String> destinationAddresses = const [],
    List<int> destinationQuantities = const [],
    required DateTime availableFrom,
    DateTime? availableTo,
    int? durationDays,
    String? vehicleId,
    int? quantity,
    String? note,
    num? pricePerVehicle,
  }) async {
    final originTrim = originAddress.trim();
    if (originTrim.isEmpty) {
      throw Exception('Origin is required');
    }
    final destObjects = destinationAddresses
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(textOnlyLocation)
        .toList();
    final payload = <String, dynamic>{
      'vehicleType': vehicleType,
      'origin': textOnlyLocation(originTrim),
      'availableFrom': availableFrom.toUtc().toIso8601String(),
      if (availableTo != null)
        'availableTo': availableTo.toUtc().toIso8601String(),
      if (durationDays != null && durationDays > 0) 'durationDays': durationDays,
      'vehicleId':
          (vehicleId != null && vehicleId.isNotEmpty) ? vehicleId : null,
      if (destinationQuantities.isNotEmpty)
        'destinationQuantities': destinationQuantities
      else if (quantity != null && quantity > 0)
        'quantity': quantity,
      'note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      'pricePerVehicle': pricePerVehicle,
      'destinations': destObjects,
    };

    try {
      final response =
          await _api.put(ApiConfig.vehiclePostById(id), data: payload);
      final body = response.data;
      if (body is! Map) {
        throw Exception('Invalid response');
      }
      if (body['success'] != true) {
        throw Exception(body['message']?.toString() ?? 'Could not update');
      }
      final data = body['data'];
      if (data is Map && data['post'] is Map) {
        final post = VehiclePostModel.fromJson(
          Map<String, dynamic>.from(data['post'] as Map),
        );
        if (post != null) return post;
      }
      return await fetchById(id);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('VehiclePostService.update: $e');
      }
      throw Exception(_messageFromDio(e));
    }
  }

  /// POST /vehicle-posts/:id/vehicles — add one or more fleet vehicles (owner only).
  Future<List<Map<String, dynamic>>> addVehicles(
    String postId, {
    required List<String> vehicleIds,
    List<int>? servedStopIndexes,
  }) async {
    if (vehicleIds.isEmpty) return [];
    try {
      final response = await _api.post(
        ApiConfig.vehiclePostVehicles(postId),
        data: {
          'vehicleIds': vehicleIds,
          if (servedStopIndexes != null && servedStopIndexes.isNotEmpty)
            'servedStopIndexes': servedStopIndexes,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
        );
      }
      final data = body['data'];
      if (data is! Map) return [];
      final raw = data['assignments'];
      if (raw is! List) return [];
      final out = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
        }
      }
      return out;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('VehiclePostService.addVehicles: $e');
      }
      throw Exception(_messageFromDio(e));
    }
  }

  static String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Request failed';
  }
}

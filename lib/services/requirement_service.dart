import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/requirement_model.dart';
import '../data/models/quote_model.dart';
import 'api_service.dart';

class RequirementService {
  final ApiService _api = ApiService();

  /// GeoJSON Point body for text-only locations (backend `requireCoordinates:false`).
  static Map<String, dynamic> textOnlyLocation(String address) => {
        'type': 'Point',
        'formattedAddress': address.trim(),
        'coordinates': <double>[],
      };

  /// POST /api/requirements — post a new inquiry.
  Future<RequirementModel> create({
    required String origin,
    required String destination,
    required String vehicleType,
    required String direction,
    int noOfVehicles = 1,
    DateTime? requiredBy,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{
      'origin': textOnlyLocation(origin),
      'destination': textOnlyLocation(destination),
      'vehicleType': vehicleType,
      'direction': direction,
      'noOfVehicles': noOfVehicles,
      if (requiredBy != null) 'requiredBy': requiredBy.toUtc().toIso8601String(),
      if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
    };
    try {
      final res = await _api.post(ApiConfig.requirements, data: payload);
      final r = _requirementFrom(res.data);
      if (r == null) throw Exception('Invalid response');
      return r;
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// GET /api/requirements/mine
  Future<List<RequirementModel>> fetchMine() =>
      _fetchList(ApiConfig.requirementsMine);

  /// GET /api/requirements/incoming
  Future<List<RequirementModel>> fetchIncoming() =>
      _fetchList(ApiConfig.requirementsIncoming);

  Future<List<RequirementModel>> _fetchList(String path) async {
    try {
      final res = await _api.get(path);
      final body = res.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      final raw = data is Map ? data['requirements'] : null;
      final out = <RequirementModel>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final m = RequirementModel.fromJson(Map<String, dynamic>.from(item));
            if (m != null) out.add(m);
          }
        }
      }
      return out;
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// GET /api/requirements/:id
  Future<RequirementModel> fetchById(String id) async {
    try {
      final res = await _api.get(ApiConfig.requirementById(id));
      final r = _requirementFrom(res.data);
      if (r == null) throw Exception('Not found');
      return r;
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// PATCH /api/requirements/:id/cancel
  Future<void> cancel(String id) async {
    try {
      await _api.patch(ApiConfig.requirementCancel(id));
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// GET /api/requirements/:id/quotes (requester)
  Future<List<QuoteModel>> fetchQuotes(String requirementId) async {
    try {
      final res = await _api.get(ApiConfig.requirementQuotes(requirementId));
      final body = res.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      final raw = data is Map ? data['quotes'] : null;
      final out = <QuoteModel>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final q = QuoteModel.fromJson(Map<String, dynamic>.from(item));
            if (q != null) out.add(q);
          }
        }
      }
      return out;
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  RequirementModel? _requirementFrom(dynamic body) {
    if (body is! Map || body['success'] != true) {
      final m = body is Map ? body['message']?.toString() : null;
      throw Exception(m ?? 'Request failed');
    }
    final data = body['data'];
    if (data is Map && data['requirement'] is Map) {
      return RequirementModel.fromJson(
        Map<String, dynamic>.from(data['requirement'] as Map),
      );
    }
    return null;
  }

  static String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? 'Request failed';
  }
}

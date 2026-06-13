import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/config/api_config.dart';
import '../core/utils/trail_points.dart';
import 'api_service.dart';

/// Fetches GPS breadcrumb trail for live trip tracking maps.
class TripLocationTrailService {
  TripLocationTrailService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<List<LatLng>> fetchTrail(String tripId) async {
    if (tripId.isEmpty) return const [];

    try {
      final res = await _api.get(ApiConfig.tripLocationTrail(tripId));
      final data = res.data;
      if (data is! Map || data['success'] != true) return const [];

      final payload = data['data'];
      if (payload is! Map) return const [];

      final raw = payload['points'];
      if (raw is! List || raw.isEmpty) return const [];

      final points = <LatLng>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final lat = (item['latitude'] as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        if (lat == 0 && lng == 0) continue;
        points.add(LatLng(lat, lng));
      }

      return simplifyTrail(points);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('TripLocationTrailService: ${e.response?.statusCode} $e');
      }
      return const [];
    } catch (e) {
      if (kDebugMode) {
        print('TripLocationTrailService: $e');
      }
      return const [];
    }
  }
}

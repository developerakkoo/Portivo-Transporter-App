import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/config/api_config.dart';

/// Snaps GPS points to roads via Google Roads API (max 100 points per request).
class RoadsSnapService {
  RoadsSnapService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  String get _key {
    final roads = ApiConfig.googleMapsRoadsKey.trim();
    if (roads.isNotEmpty) return roads;
    return ApiConfig.googleMapsDirectionsKey.trim();
  }

  /// Returns snapped points or original [points] on failure.
  Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    if (points.length < 2) return List<LatLng>.from(points);
    final key = _key;
    if (key.isEmpty) {
      throw StateError('No Roads API key (GOOGLE_MAPS_ROADS_KEY or DIRECTIONS key)');
    }

    final batch = points.length > 100 ? points.sublist(points.length - 100) : points;
    final path = batch.map((p) => '${p.latitude},${p.longitude}').join('|');

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://roads.googleapis.com/v1/snapToRoads',
        queryParameters: <String, dynamic>{
          'path': path,
          'interpolate': 'true',
          'key': key,
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      final data = response.data;
      final snapped = data?['snappedPoints'] as List<dynamic>?;
      if (snapped == null || snapped.isEmpty) {
        return List<LatLng>.from(points);
      }

      final out = <LatLng>[];
      for (final item in snapped) {
        if (item is! Map) continue;
        final loc = item['location'] as Map<String, dynamic>?;
        final lat = (loc?['latitude'] as num?)?.toDouble();
        final lng = (loc?['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          out.add(LatLng(lat, lng));
        }
      }
      if (out.isEmpty) return List<LatLng>.from(points);

      if (points.length > 100) {
        return [...points.sublist(0, points.length - 100), ...out];
      }
      return out;
    } catch (e) {
      if (kDebugMode) {
        print('RoadsSnapService: $e');
      }
      rethrow;
    }
  }
}

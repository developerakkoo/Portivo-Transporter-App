import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/config/api_config.dart';

class DistanceMatrixResult {
  const DistanceMatrixResult({
    this.distanceText,
    this.durationText,
    this.status = 'UNKNOWN',
    this.message,
  });

  final String? distanceText;
  final String? durationText;
  final String status;
  final String? message;
}

/// Driver → drop ETA via Google Distance Matrix API.
class DistanceMatrixService {
  DistanceMatrixService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  String get _key {
    final dm = ApiConfig.googleMapsDistanceMatrixKey.trim();
    if (dm.isNotEmpty) return dm;
    return ApiConfig.googleMapsDirectionsKey.trim();
  }

  Future<DistanceMatrixResult> getDrivingEta(LatLng origin, LatLng destination) async {
    final key = _key;
    if (key.isEmpty) {
      return const DistanceMatrixResult(
        status: 'NO_KEY',
        message: 'Set GOOGLE_MAPS_DISTANCE_MATRIX_KEY or DIRECTIONS key',
      );
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/distancematrix/json',
        queryParameters: <String, dynamic>{
          'origins': '${origin.latitude},${origin.longitude}',
          'destinations': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'key': key,
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      final data = response.data;
      final status = data?['status']?.toString() ?? 'UNKNOWN';
      if (status != 'OK') {
        return DistanceMatrixResult(
          status: status,
          message: data?['error_message']?.toString(),
        );
      }

      final rows = data?['rows'] as List<dynamic>?;
      if (rows == null || rows.isEmpty) {
        return const DistanceMatrixResult(status: 'EMPTY');
      }
      final elements = (rows.first as Map)['elements'] as List<dynamic>?;
      if (elements == null || elements.isEmpty) {
        return const DistanceMatrixResult(status: 'EMPTY');
      }
      final el = elements.first as Map<String, dynamic>;
      final elStatus = el['status']?.toString() ?? 'UNKNOWN';
      if (elStatus != 'OK') {
        return DistanceMatrixResult(status: elStatus);
      }

      final dist = el['distance'] as Map<String, dynamic>?;
      final dur = el['duration'] as Map<String, dynamic>?;
      return DistanceMatrixResult(
        status: 'OK',
        distanceText: dist?['text']?.toString(),
        durationText: dur?['text']?.toString(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('DistanceMatrixService: $e');
      }
      return DistanceMatrixResult(status: 'ERROR', message: e.toString());
    }
  }
}

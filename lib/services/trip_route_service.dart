import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/config/api_config.dart';
import '../core/utils/polyline_decode.dart';

/// Result of a Directions API fetch for HUD / debugging.
class RouteFetchResult {
  const RouteFetchResult({
    required this.points,
    required this.status,
    this.message,
  });

  final List<LatLng> points;
  final String status;
  final String? message;
}

/// Pickup–drop route polyline (Directions API when key is set, else straight line).
class TripRouteService {
  TripRouteService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<LatLng>> getPickupDropRoute(LatLng? pickup, LatLng? drop) async {
    final r = await getPickupDropRouteDetailed(pickup, drop);
    return r.points;
  }

  Future<RouteFetchResult> getPickupDropRouteDetailed(
    LatLng? pickup,
    LatLng? drop,
  ) async {
    if (pickup == null || drop == null) {
      return const RouteFetchResult(points: [], status: 'NO_ENDPOINTS');
    }

    final key = ApiConfig.googleMapsDirectionsKey.trim();
    if (key.isEmpty) {
      return RouteFetchResult(
        points: [pickup, drop],
        status: 'NO_KEY',
        message: 'Set GOOGLE_MAPS_DIRECTIONS_KEY via dart-define',
      );
    }

    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json';
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: <String, dynamic>{
          'origin': '${pickup.latitude},${pickup.longitude}',
          'destination': '${drop.latitude},${drop.longitude}',
          'mode': 'driving',
          'key': key,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      final apiStatus = data?['status']?.toString() ?? 'UNKNOWN';
      if (data == null || apiStatus != 'OK') {
        if (kDebugMode) {
          print('TripRouteService: Directions status $apiStatus');
        }
        return RouteFetchResult(
          points: [pickup, drop],
          status: apiStatus,
          message: data?['error_message']?.toString(),
        );
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return RouteFetchResult(
          points: [pickup, drop],
          status: 'EMPTY',
          message: 'No routes returned',
        );
      }

      final overview = routes.first['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        return RouteFetchResult(
          points: [pickup, drop],
          status: 'NO_POLYLINE',
        );
      }

      return RouteFetchResult(
        points: decodeEncodedPolyline(encoded),
        status: 'OK',
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('TripRouteService: Directions failed: $e');
        print(st);
      }
      return RouteFetchResult(
        points: [pickup, drop],
        status: 'ERROR',
        message: e.toString(),
      );
    }
  }

  Future<RouteFetchResult> getMultiStopRouteDetailed(
    LatLng? origin,
    LatLng? waypoint,
    LatLng? destination,
  ) async {
    if (origin == null || waypoint == null || destination == null) {
      return const RouteFetchResult(points: [], status: 'NO_ENDPOINTS');
    }

    final key = ApiConfig.googleMapsDirectionsKey.trim();
    if (key.isEmpty) {
      return RouteFetchResult(
        points: [origin, waypoint, destination],
        status: 'NO_KEY',
        message: 'Set GOOGLE_MAPS_DIRECTIONS_KEY via dart-define',
      );
    }

    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json';
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: <String, dynamic>{
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'waypoints': '${waypoint.latitude},${waypoint.longitude}',
          'mode': 'driving',
          'key': key,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      final apiStatus = data?['status']?.toString() ?? 'UNKNOWN';
      if (data == null || apiStatus != 'OK') {
        return RouteFetchResult(
          points: [origin, waypoint, destination],
          status: apiStatus,
          message: data?['error_message']?.toString(),
        );
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return RouteFetchResult(
          points: [origin, waypoint, destination],
          status: 'EMPTY',
          message: 'No routes returned',
        );
      }

      final overview = routes.first['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        return RouteFetchResult(
          points: [origin, waypoint, destination],
          status: 'NO_POLYLINE',
        );
      }

      return RouteFetchResult(
        points: decodeEncodedPolyline(encoded),
        status: 'OK',
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('TripRouteService: Multi-stop directions failed: $e');
        print(st);
      }
      return RouteFetchResult(
        points: [origin, waypoint, destination],
        status: 'ERROR',
        message: e.toString(),
      );
    }
  }
}

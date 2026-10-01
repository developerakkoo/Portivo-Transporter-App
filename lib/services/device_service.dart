import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import 'api_service.dart';

/// Registers / unregisters this device's FCM token with the backend so the
/// server can target the user with push notifications.
class DeviceService {
  final ApiService _api = ApiService();

  Future<void> register({required String token, String? platform}) async {
    try {
      await _api.post(
        ApiConfig.devicesRegister,
        data: {
          'token': token,
          if (platform != null) 'platform': platform,
        },
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DeviceService.register failed: ${e.message}');
      }
    }
  }

  Future<void> unregister(String token) async {
    try {
      await _api.delete(ApiConfig.devicesToken, data: {'token': token});
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DeviceService.unregister failed: ${e.message}');
      }
    }
  }
}

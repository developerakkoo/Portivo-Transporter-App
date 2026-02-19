import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/transporter_model.dart';
import 'api_service.dart';

class TransporterService {
  final ApiService _api = ApiService();

  Future<TransporterModel> getProfile() async {
    try {
      if (kDebugMode) {
        print('TransporterService: Fetching profile');
      }
      
      final response = await _api.get(ApiConfig.transporterProfile);

      if (kDebugMode) {
        print('TransporterService: Profile response received');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        final transporterData = response.data['data']['transporter'];
        return TransporterModel.fromJson(transporterData);
      }
      
      throw Exception(response.data['message'] ?? 'Failed to fetch profile');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TransporterService: Error fetching profile: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<TransporterModel> updateProfile(Map<String, dynamic> data) async {
    try {
      if (kDebugMode) {
        print('TransporterService: Updating profile with data: $data');
      }
      
      final response = await _api.put(
        ApiConfig.transporterProfile,
        data: data,
      );

      if (kDebugMode) {
        print('TransporterService: Update profile response received');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        final transporterData = response.data['data']['transporter'];
        return TransporterModel.fromJson(transporterData);
      }
      
      throw Exception(response.data['message'] ?? 'Failed to update profile');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TransporterService: Error updating profile: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      if (kDebugMode) {
        print('TransporterService: Fetching dashboard stats');
      }
      
      final response = await _api.get(ApiConfig.transporterDashboard);

      if (kDebugMode) {
        print('TransporterService: Dashboard response received');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data']['dashboard'] ?? {};
      }
      
      throw Exception(response.data['message'] ?? 'Failed to fetch dashboard');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('TransporterService: Error fetching dashboard: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

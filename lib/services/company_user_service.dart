import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/company_user_model.dart';
import 'api_service.dart';

class CompanyUserService {
  final ApiService _api = ApiService();

  Future<List<CompanyUserModel>> getUsers() async {
    try {
      if (kDebugMode) {
        print('CompanyUserService: Fetching users');
      }
      
      final response = await _api.get(ApiConfig.companyUsers);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['users'] != null) {
          final List<dynamic> usersData = data['users'];
          return usersData.map((json) => CompanyUserModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CompanyUserService: Error fetching users: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<CompanyUserModel?> getUserById(String id) async {
    try {
      if (kDebugMode) {
        print('CompanyUserService: Fetching user by id: $id');
      }
      
      final response = await _api.get(ApiConfig.companyUserById(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['user'] != null) {
          return CompanyUserModel.fromJson(data['user']);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CompanyUserService: Error fetching user: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<CompanyUserModel?> createUser(Map<String, dynamic> userData) async {
    try {
      if (kDebugMode) {
        print('CompanyUserService: Creating user');
      }
      
      final response = await _api.post(
        ApiConfig.companyUsers,
        data: userData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['user'] != null) {
          return CompanyUserModel.fromJson(data['user']);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CompanyUserService: Error creating user: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<CompanyUserModel?> updateUser(String id, Map<String, dynamic> userData) async {
    try {
      if (kDebugMode) {
        print('CompanyUserService: Updating user: $id');
      }
      
      final response = await _api.put(
        ApiConfig.companyUserById(id),
        data: userData,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['user'] != null) {
          return CompanyUserModel.fromJson(data['user']);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CompanyUserService: Error updating user: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      if (kDebugMode) {
        print('CompanyUserService: Deleting user: $id');
      }
      
      final response = await _api.delete(ApiConfig.companyUserById(id));

      return response.data['success'] == true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CompanyUserService: Error deleting user: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> setPin(String id, String pin) async {
    try {
      if (kDebugMode) {
        print('CompanyUserService: Setting PIN for user: $id');
      }
      
      final response = await _api.put(
        ApiConfig.companyUserSetPin(id),
        data: {'pin': pin},
      );

      return response.data['success'] == true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CompanyUserService: Error setting PIN: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> toggleAccess(String id, bool hasAccess) async {
    try {
      if (kDebugMode) {
        print('CompanyUserService: Toggling access for user: $id');
      }
      
      final response = await _api.put(
        ApiConfig.companyUserToggleAccess(id),
        data: {'hasAccess': hasAccess},
      );

      return response.data['success'] == true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CompanyUserService: Error toggling access: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

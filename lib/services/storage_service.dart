import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;

  Future<bool> init() async {
    try {
      if (!_isInitialized) {
        _prefs = await SharedPreferences.getInstance();
        _isInitialized = true;
        if (kDebugMode) {
          print('StorageService: SharedPreferences initialized');
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('StorageService: Error initializing SharedPreferences: $e');
      }
      // Try to continue with null _prefs - secure storage might still work
      return false;
    }
  }

  // Secure Storage (for tokens)
  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(key: AppConstants.accessTokenKey, value: token);
      if (kDebugMode) {
        print('StorageService: Access token saved successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('StorageService: Error saving access token: $e');
      }
      rethrow;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (kDebugMode) {
        print('StorageService: Access token retrieved: ${token != null ? "found" : "not found"}');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('StorageService: Error getting access token: $e');
      }
      return null;
    }
  }

  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: AppConstants.refreshTokenKey, value: token);
      if (kDebugMode) {
        print('StorageService: Refresh token saved successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('StorageService: Error saving refresh token: $e');
      }
      rethrow;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (kDebugMode) {
        print('StorageService: Refresh token retrieved: ${token != null ? "found" : "not found"}');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('StorageService: Error getting refresh token: $e');
      }
      return null;
    }
  }

  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: AppConstants.accessTokenKey);
      await _secureStorage.delete(key: AppConstants.refreshTokenKey);
      if (kDebugMode) {
        print('StorageService: Tokens cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('StorageService: Error clearing tokens: $e');
      }
    }
  }

  // Shared Preferences (for user data)
  Future<void> saveUserData(String userData) async {
    await _prefs?.setString(AppConstants.userDataKey, userData);
  }

  Future<String?> getUserData() async {
    return _prefs?.getString(AppConstants.userDataKey);
  }

  Future<void> saveTransporterId(String transporterId) async {
    await _prefs?.setString(AppConstants.transporterIdKey, transporterId);
  }

  Future<String?> getTransporterId() async {
    return _prefs?.getString(AppConstants.transporterIdKey);
  }

  Future<void> clearAll() async {
    await clearTokens();
    await _prefs?.clear();
  }
}

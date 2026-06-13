import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/auth_response_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<AuthResponseModel> register(
    String mobile,
    String name,
    String email,
    String company,
    String operatingCountry,
  ) async {
    try {
      if (kDebugMode) {
        print('AuthService: Registering transporter with mobile: $mobile');
      }
      
      final response = await _api.post(
        ApiConfig.register,
        data: {
          'mobile': mobile,
          'name': name,
          'email': email,
          'company': company,
          'operatingCountry': operatingCountry,
        },
      );

      if (kDebugMode) {
        print('AuthService: Registration response received');
      }

      final authResponse = AuthResponseModel.fromJson(response.data);

      if (authResponse.success && authResponse.data != null) {
        if (kDebugMode) {
          print('AuthService: Registration successful, saving tokens and user data');
        }
        // Ensure storage is initialized
        await _storage.init();
        
        // Save tokens
        await _storage.saveAccessToken(authResponse.data!.accessToken);
        await _storage.saveRefreshToken(authResponse.data!.refreshToken);

        // Verify tokens were saved
        final savedAccessToken = await _storage.getAccessToken();
        final savedRefreshToken = await _storage.getRefreshToken();
        if (kDebugMode) {
          print('AuthService: Token verification - Access: ${savedAccessToken != null}, Refresh: ${savedRefreshToken != null}');
        }

        // Save user data
        await _storage.saveTransporterId(authResponse.data!.user.id);
        await _storage.saveUserData(authResponse.data!.user.id);
      } else {
        if (kDebugMode) {
          print('AuthService: Registration failed: ${authResponse.message}');
        }
      }

      return authResponse;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthService: Error during registration: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> setPin(String pin) async {
    try {
      if (kDebugMode) {
        print('AuthService: Setting PIN');
      }
      
      final response = await _api.put(
        ApiConfig.transporterSetPin,
        data: {
          'pin': pin,
        },
      );

      if (kDebugMode) {
        print('AuthService: Set PIN response received');
      }

      if (response.data['success'] == true) {
        if (kDebugMode) {
          print('AuthService: PIN set successfully');
        }
        return true;
      }
      
      if (kDebugMode) {
        print('AuthService: Set PIN failed: ${response.data['message']}');
      }
      return false;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthService: Error setting PIN: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<AuthResponseModel> sendOTP(String mobile, String userType) async {
    try {
      if (kDebugMode) {
        print('AuthService: Sending OTP for mobile: $mobile, userType: $userType');
      }
      
      final response = await _api.post(
        ApiConfig.sendOTP,
        data: {
          'mobile': mobile,
          'userType': userType,
        },
      );

      if (kDebugMode) {
        print('AuthService: OTP response received');
      }

      final authResponse = AuthResponseModel.fromJson(response.data);

      if (authResponse.success && authResponse.data != null) {
        if (kDebugMode) {
          print('AuthService: OTP successful, saving tokens and user data');
        }
        // Ensure storage is initialized
        await _storage.init();
        
        // Save tokens
        await _storage.saveAccessToken(authResponse.data!.accessToken);
        await _storage.saveRefreshToken(authResponse.data!.refreshToken);

        // Verify tokens were saved
        final savedAccessToken = await _storage.getAccessToken();
        final savedRefreshToken = await _storage.getRefreshToken();
        if (kDebugMode) {
          print('AuthService: Token verification - Access: ${savedAccessToken != null}, Refresh: ${savedRefreshToken != null}');
        }

        // Save user data
        await _storage.saveTransporterId(authResponse.data!.user.id);
        await _storage.saveUserData(authResponse.data!.user.id);
      } else {
        if (kDebugMode) {
          print('AuthService: OTP failed: ${authResponse.message}');
        }
      }

      return authResponse;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthService: Error sending OTP: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<AuthResponseModel> pinLogin(String mobile, String pin) async {
    try {
      if (kDebugMode) {
        print('AuthService: Attempting PIN login for mobile: $mobile');
      }
      
      final response = await _api.post(
        ApiConfig.pinLogin,
        data: {
          'mobile': mobile,
          'pin': pin,
        },
      );

      if (kDebugMode) {
        print('AuthService: PIN login response received');
      }

      final authResponse = AuthResponseModel.fromJson(response.data);

      if (authResponse.success && authResponse.data != null) {
        if (kDebugMode) {
          print('AuthService: PIN login successful, saving tokens and user data');
        }
        // Ensure storage is initialized
        await _storage.init();
        
        // Save tokens
        await _storage.saveAccessToken(authResponse.data!.accessToken);
        await _storage.saveRefreshToken(authResponse.data!.refreshToken);

        // Verify tokens were saved
        final savedAccessToken = await _storage.getAccessToken();
        final savedRefreshToken = await _storage.getRefreshToken();
        if (kDebugMode) {
          print('AuthService: Token verification - Access: ${savedAccessToken != null}, Refresh: ${savedRefreshToken != null}');
        }

        // Save user data
        // For company users, save transporterId instead of their own id
        final userId = authResponse.data!.user.transporterId ?? authResponse.data!.user.id;
        await _storage.saveTransporterId(userId);
        await _storage.saveUserData(authResponse.data!.user.id);
      } else {
        if (kDebugMode) {
          print('AuthService: PIN login failed: ${authResponse.message}');
        }
      }

      return authResponse;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthService: Error during PIN login: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<AuthResponseModel> companyUserLogin(String mobile, String pin) async {
    try {
      if (kDebugMode) {
        print('AuthService: Attempting company user login for mobile: $mobile');
      }
      
      final response = await _api.post(
        ApiConfig.companyUserLogin,
        data: {
          'mobile': mobile,
          'pin': pin,
        },
      );

      if (kDebugMode) {
        print('AuthService: Company user login response received');
      }

      final authResponse = AuthResponseModel.fromJson(response.data);

      if (authResponse.success && authResponse.data != null) {
        if (kDebugMode) {
          print('AuthService: Company user login successful, saving tokens and user data');
        }
        // Ensure storage is initialized
        await _storage.init();
        
        // Save tokens
        await _storage.saveAccessToken(authResponse.data!.accessToken);
        await _storage.saveRefreshToken(authResponse.data!.refreshToken);

        // Verify tokens were saved
        final savedAccessToken = await _storage.getAccessToken();
        final savedRefreshToken = await _storage.getRefreshToken();
        if (kDebugMode) {
          print('AuthService: Token verification - Access: ${savedAccessToken != null}, Refresh: ${savedRefreshToken != null}');
        }

        // Save user data
        // For company users, save transporterId (not their own id) for Socket.IO and data filtering
        final transporterId = authResponse.data!.user.transporterId ?? authResponse.data!.user.id;
        await _storage.saveTransporterId(transporterId);
        await _storage.saveUserData(authResponse.data!.user.id);
      } else {
        if (kDebugMode) {
          print('AuthService: Company user login failed: ${authResponse.message}');
        }
      }

      return authResponse;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthService: Error during company user login: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _api.post(
        ApiConfig.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _storage.saveAccessToken(data['accessToken']);
        if (data['refreshToken'] != null) {
          await _storage.saveRefreshToken(data['refreshToken']);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<String?> getAccessToken() async {
    return await _storage.getAccessToken();
  }

  Future<String?> getTransporterId() async {
    return await _storage.getTransporterId();
  }

  /// Last logged-in user id (transporter or company user), for session restore.
  Future<String?> getStoredUserId() async {
    await _storage.init();
    return await _storage.getUserData();
  }
}

import 'package:flutter/foundation.dart';
import '../data/models/auth_response_model.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/transporter_service.dart';
import '../utils/error_utils.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SocketService _socketService = SocketService();

  UserModel? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.getAccessToken();
      if (token != null) {
        _isAuthenticated = true;
        if (kDebugMode) {
          print('AuthProvider: Found existing token, user is authenticated');
        }
        // Reload user data from profile endpoint
        await _reloadUserFromProfile();
        // Don't connect Socket.IO here - wait for successful login
        // Socket.IO will be connected after login
      } else {
        if (kDebugMode) {
          print('AuthProvider: No existing token found');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Error during initialization: $e');
        print('Stack: $stackTrace');
      }
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reload user data from profile endpoint
  /// This is used when app restarts and we have a token but no user data
  Future<void> _reloadUserFromProfile() async {
    try {
      if (kDebugMode) {
        print('AuthProvider: Attempting to reload user from profile');
      }
      
      // Import transporter service to get profile
      final transporterService = TransporterService();
      final transporter = await transporterService.getProfile();
      
      // Create UserModel from transporter profile
      // Assume userType is 'transporter' since we're calling transporter profile
      _user = UserModel(
        id: transporter.id,
        mobile: transporter.mobile,
        name: transporter.name,
        userType: 'transporter',
        status: transporter.status,
        hasAccess: transporter.hasAccess,
      );
      
      if (kDebugMode) {
        print('AuthProvider: User reloaded from profile - ID: ${_user!.id}, userType: ${_user!.userType}');
      }
      
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Error reloading user from profile: $e');
        print('Stack: $stackTrace');
        print('AuthProvider: User will remain null, may need to login again');
      }
      // Don't set error here - user might just need to login again
      // This is not critical for app initialization
    }
  }

  Future<bool> register(String mobile, String name, String email, String company) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('AuthProvider: Attempting registration for mobile: $mobile');
      }
      
      final response = await _authService.register(mobile, name, email, company);
      
      if (response.success && response.data != null) {
        _user = response.data!.user;
        _isAuthenticated = true;
        _isLoading = false;
        
        if (kDebugMode) {
          print('AuthProvider: Registration successful for user: ${_user!.id}');
        }
        
        // Don't connect Socket.IO yet - wait for PIN setup
        notifyListeners();
        return true;
      } else {
        _error = response.message;
        _isLoading = false;
        if (kDebugMode) {
          print('AuthProvider: Registration failed: ${response.message}');
        }
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Registration error: $e');
        print('Stack: $stackTrace');
      }
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithOTP(String mobile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('AuthProvider: Attempting OTP login for mobile: $mobile');
      }
      
      final response = await _authService.sendOTP(mobile, 'transporter');
      
      if (response.success && response.data != null) {
        _user = response.data!.user;
        _isAuthenticated = true;
        _isLoading = false;
        
        if (kDebugMode) {
          print('AuthProvider: Login successful for user: ${_user!.id}');
        }
        
        // Connect Socket.IO after successful login
        try {
          await _socketService.connect();
          // For company users, use transporterId for Socket.IO room
          final transporterId = _user!.transporterId ?? _user!.id;
          _socketService.joinTransporterRoom(transporterId);
          if (kDebugMode) {
            print('AuthProvider: Socket.IO connected and joined transporter room: $transporterId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('AuthProvider: Socket.IO connection failed (non-critical): $e');
          }
          // Don't fail login if Socket.IO fails
        }
        
        notifyListeners();
        return true;
      } else {
        _error = response.message;
        _isLoading = false;
        if (kDebugMode) {
          print('AuthProvider: Login failed: ${response.message}');
        }
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Login error: $e');
        print('Stack: $stackTrace');
      }
      
      // Extract user-friendly error message
      String errorMessage = _extractErrorMessage(e);
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithPIN(String mobile, String pin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('AuthProvider: Attempting PIN login for mobile: $mobile');
      }
      
      final response = await _authService.pinLogin(mobile, pin);
      
      if (response.success && response.data != null) {
        _user = response.data!.user;
        _isAuthenticated = true;
        _isLoading = false;
        
        if (kDebugMode) {
          print('AuthProvider: PIN login successful for user: ${_user!.id}');
        }
        
        // Connect Socket.IO after successful login
        try {
          await _socketService.connect();
          // For company users, use transporterId for Socket.IO room
          final transporterId = _user!.transporterId ?? _user!.id;
          _socketService.joinTransporterRoom(transporterId);
          if (kDebugMode) {
            print('AuthProvider: Socket.IO connected and joined transporter room: $transporterId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('AuthProvider: Socket.IO connection failed (non-critical): $e');
          }
          // Don't fail login if Socket.IO fails
        }
        
        notifyListeners();
        return true;
      } else {
        _error = response.message;
        _isLoading = false;
        if (kDebugMode) {
          print('AuthProvider: PIN login failed: ${response.message}');
        }
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: PIN login error: $e');
        print('Stack: $stackTrace');
      }
      String errorMessage = _extractErrorMessage(e);
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginAsCompanyUser(String mobile, String pin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('AuthProvider: Attempting company user login for mobile: $mobile');
      }
      
      final response = await _authService.companyUserLogin(mobile, pin);
      
      if (response.success && response.data != null) {
        _user = response.data!.user;
        _isAuthenticated = true;
        _isLoading = false;
        
        if (kDebugMode) {
          print('AuthProvider: Company user login successful for user: ${_user!.id}');
          print('AuthProvider: User permissions: ${_user!.permissions}');
          print('AuthProvider: Transporter ID: ${_user!.transporterId}');
        }
        
        // Connect Socket.IO after successful login
        // Use transporterId for Socket.IO room (company users receive updates for their transporter)
        try {
          await _socketService.connect();
          final transporterId = _user!.transporterId ?? _user!.id;
          _socketService.joinTransporterRoom(transporterId);
          if (kDebugMode) {
            print('AuthProvider: Socket.IO connected and joined transporter room: $transporterId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('AuthProvider: Socket.IO connection failed (non-critical): $e');
          }
          // Don't fail login if Socket.IO fails
        }
        
        notifyListeners();
        return true;
      } else {
        _error = response.message;
        _isLoading = false;
        if (kDebugMode) {
          print('AuthProvider: Company user login failed: ${response.message}');
        }
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Company user login error: $e');
        print('Stack: $stackTrace');
      }
      String errorMessage = _extractErrorMessage(e);
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('AuthProvider: Logging out');
      }
      await _authService.logout();
      _socketService.disconnect();
      _user = null;
      _isAuthenticated = false;
      if (kDebugMode) {
        print('AuthProvider: Logout successful');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Logout error: $e');
        print('Stack: $stackTrace');
      }
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Extract user-friendly error message from exception
  String _extractErrorMessage(dynamic error) {
    return ErrorUtils.extractErrorMessage(error);
  }
}

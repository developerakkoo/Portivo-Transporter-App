import 'package:flutter/foundation.dart';
import '../data/models/auth_response_model.dart';
import '../services/auth_service.dart';
import '../services/company_user_service.dart';
import '../services/marketplace_message_cache.dart';
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
        if (kDebugMode) {
          print('AuthProvider: Found existing token, loading session');
        }
        await _reloadUserFromProfile();
        if (_user != null) {
          _isAuthenticated = true;
          await _connectSocketForCurrentUser();
        } else {
          await _clearInvalidSession();
        }
      } else {
        if (kDebugMode) {
          print('AuthProvider: No existing token found');
        }
        _isAuthenticated = false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Error during initialization: $e');
        print('Stack: $stackTrace');
      }
      _error = ErrorUtils.userMessage(e);
      await _clearInvalidSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _clearInvalidSession() async {
    _user = null;
    _isAuthenticated = false;
    try {
      await MarketplaceMessageCache.instance.clearAll();
    } catch (_) {}
    try {
      await _authService.logout();
    } catch (_) {}
  }

  Future<void> _connectSocketForCurrentUser() async {
    final u = _user;
    if (u == null) return;
    try {
      await _socketService.connect();
      final transporterId = u.transporterId ?? u.id;
      _socketService.joinTransporterRoom(transporterId);
      if (kDebugMode) {
        print('AuthProvider: Socket connected, joined transporter room: $transporterId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthProvider: Socket.IO connection failed (non-critical): $e');
      }
    }
  }

  /// Reload user from transporter profile, or company-user profile when JWT is a company user.
  Future<void> _reloadUserFromProfile() async {
    final transporterService = TransporterService();
    try {
      if (kDebugMode) {
        print('AuthProvider: Attempting transporter profile');
      }
      final transporter = await transporterService.getProfile();
      _user = UserModel(
        id: transporter.id,
        mobile: transporter.mobile,
        name: transporter.name,
        userType: 'transporter',
        status: transporter.status,
        hasAccess: transporter.hasAccess,
        operatingCountry: transporter.operatingCountry,
        company: transporter.company,
      );
      if (kDebugMode) {
        print('AuthProvider: User from transporter profile — ${_user!.id}');
      }
      notifyListeners();
      return;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('AuthProvider: Transporter profile failed: $e');
        print('Stack: $stackTrace');
      }
    }

    final storedUserId = await _authService.getStoredUserId();
    if (storedUserId != null && storedUserId.isNotEmpty) {
      try {
        final companyUserService = CompanyUserService();
        final cu = await companyUserService.getUserById(storedUserId);
        if (cu != null) {
          _user = UserModel(
            id: cu.id,
            mobile: cu.mobile,
            name: cu.name,
            userType: 'company-user',
            status: cu.status,
            hasAccess: cu.hasAccess,
            transporterId: cu.transporterId,
            permissions: cu.permissions,
          );
          if (kDebugMode) {
            print('AuthProvider: User from company profile — ${_user!.id}');
          }
          notifyListeners();
          return;
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('AuthProvider: Company user profile failed: $e');
          print('Stack: $stackTrace');
        }
      }
    }

    _user = null;
    if (kDebugMode) {
      print('AuthProvider: Could not restore user; session cleared');
    }
  }

  String? get operatingCountry => _user?.operatingCountry;

  void updateOperatingCountry(String countryCode) {
    if (_user == null) return;
    _user = _user!.copyWith(operatingCountry: countryCode.toUpperCase());
    notifyListeners();
  }

  Future<bool> register(
    String mobile,
    String name,
    String email,
    String company,
    String operatingCountry,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('AuthProvider: Attempting registration for mobile: $mobile');
      }
      
      final response = await _authService.register(
        mobile,
        name,
        email,
        company,
        operatingCountry,
      );
      
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
      _error = ErrorUtils.userMessage(e);
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

        await _connectSocketForCurrentUser();

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

        await _connectSocketForCurrentUser();

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

        await _connectSocketForCurrentUser();

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
      final u = _user;
      if (u != null) {
        final actorId = u.transporterId ?? u.id;
        try {
          await MarketplaceMessageCache.instance.clearAllForActor(actorId);
        } catch (_) {}
      }
      await _authService.logout();
      _socketService.clearJoinedRooms();
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
      _error = ErrorUtils.userMessage(e);
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
    return ErrorUtils.userMessage(error);
  }
}

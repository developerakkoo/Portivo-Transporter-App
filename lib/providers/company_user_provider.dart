import 'package:flutter/foundation.dart';
import '../data/models/company_user_model.dart';
import '../services/company_user_service.dart';
import '../utils/error_utils.dart';

class CompanyUserProvider with ChangeNotifier {
  final CompanyUserService _companyUserService = CompanyUserService();

  List<CompanyUserModel> _users = [];
  CompanyUserModel? _selectedUser;
  bool _isLoading = false;
  String? _error;

  List<CompanyUserModel> get users => _users;
  CompanyUserModel? get selectedUser => _selectedUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUsers({bool refresh = false}) async {
    if (!refresh && _users.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final users = await _companyUserService.getUsers();
      _users = users;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CompanyUserProvider: Error loading users: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CompanyUserModel?> getUserById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _companyUserService.getUserById(id);
      _selectedUser = user;
      return user;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CompanyUserProvider: Error getting user: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CompanyUserModel?> createUser(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _companyUserService.createUser(userData);
      if (user != null) {
        _users.insert(0, user);
      }
      return user;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CompanyUserProvider: Error creating user: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser(String id, Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _companyUserService.updateUser(id, userData);
      if (user != null) {
        final index = _users.indexWhere((u) => u.id == id);
        if (index != -1) {
          _users[index] = user;
        }
        if (_selectedUser?.id == id) {
          _selectedUser = user;
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CompanyUserProvider: Error updating user: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _companyUserService.deleteUser(id);
      if (success) {
        _users.removeWhere((u) => u.id == id);
        if (_selectedUser?.id == id) {
          _selectedUser = null;
        }
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CompanyUserProvider: Error deleting user: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setPin(String id, String pin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _companyUserService.setPin(id, pin);
      if (success) {
        // Reload user to get updated data
        await getUserById(id);
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CompanyUserProvider: Error setting PIN: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleAccess(String id, bool hasAccess) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _companyUserService.toggleAccess(id, hasAccess);
      if (success) {
        // Reload user to get updated data
        await getUserById(id);
        // Also update in list
        final index = _users.indexWhere((u) => u.id == id);
        if (index != -1) {
          _users[index] = _users[index].copyWith(hasAccess: hasAccess);
        }
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CompanyUserProvider: Error toggling access: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectUser(CompanyUserModel? user) {
    _selectedUser = user;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

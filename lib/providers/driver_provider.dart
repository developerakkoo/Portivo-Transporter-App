import 'package:flutter/foundation.dart';
import '../data/models/driver_model.dart';
import '../services/driver_service.dart';
import '../services/auth_service.dart';

class DriverProvider with ChangeNotifier {
  final DriverService _driverService = DriverService();
  final AuthService _authService = AuthService();

  List<DriverModel> _drivers = [];
  DriverModel? _selectedDriver;
  bool _isLoading = false;
  String? _error;

  List<DriverModel> get drivers => _drivers;
  DriverModel? get selectedDriver => _selectedDriver;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDrivers({
    bool availableForTrip = false,
    bool refresh = false,
  }) async {
    if (!refresh && _drivers.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final transporterId = await _authService.getTransporterId();
      if (transporterId == null) {
        _error = 'Not authenticated';
        return;
      }

      final drivers = await _driverService.getDriversByTransporter(
        transporterId,
        availableForTrip: availableForTrip,
      );

      if (refresh) {
        _drivers = drivers;
      } else {
        _drivers = drivers;
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('DriverProvider: Error loading drivers: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DriverModel?> getDriverById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final driver = await _driverService.getDriverById(id);
      _selectedDriver = driver;
      return driver;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('DriverProvider: Error getting driver: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDriver(DriverModel? driver) {
    _selectedDriver = driver;
    notifyListeners();
  }

  void refreshDrivers() {
    loadDrivers(refresh: true);
  }

  Future<DriverModel?> createDriver({
    required String mobile,
    required String name,
    String? status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final driver = await _driverService.createDriver(
        mobile: mobile,
        name: name,
        status: status,
      );
      if (driver != null) {
        _drivers.add(driver);
        notifyListeners();
      }
      return driver;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('DriverProvider: Error creating driver: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DriverModel?> updateDriver({
    required String id,
    String? name,
    String? status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final driver = await _driverService.updateDriver(
        id: id,
        name: name,
        status: status,
      );
      if (driver != null) {
        final index = _drivers.indexWhere((d) => d.id == id);
        if (index != -1) {
          _drivers[index] = driver;
        }
        if (_selectedDriver?.id == id) {
          _selectedDriver = driver;
        }
        notifyListeners();
      }
      return driver;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('DriverProvider: Error updating driver: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDriver(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _driverService.deleteDriver(id);
      if (success) {
        _drivers.removeWhere((d) => d.id == id);
        if (_selectedDriver?.id == id) {
          _selectedDriver = null;
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('DriverProvider: Error deleting driver: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

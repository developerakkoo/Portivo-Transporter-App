import 'package:flutter/foundation.dart';
import '../data/models/vehicle_model.dart';
import '../data/models/trip_model.dart';
import '../services/vehicle_service.dart';
import '../utils/error_utils.dart';

class VehicleProvider with ChangeNotifier {
  final VehicleService _vehicleService = VehicleService();

  List<VehicleModel> _vehicles = [];
  VehicleModel? _selectedVehicle;
  bool _isLoading = false;
  String? _error;

  List<VehicleModel> get vehicles => _vehicles;
  VehicleModel? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadVehicles({
    String? status,
    String? ownerType,
    String? driverId,
    bool availableForTrip = false,
    bool refresh = false,
  }) async {
    if (!refresh && _vehicles.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final vehicles = await _vehicleService.getVehicles(
        status: status,
        ownerType: ownerType,
        driverId: driverId,
        availableForTrip: availableForTrip,
      );

      if (refresh) {
        _vehicles = vehicles;
      } else {
        _vehicles = vehicles;
      }
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('VehicleProvider: Error loading vehicles: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<VehicleModel?> getVehicleById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final vehicle = await _vehicleService.getVehicleById(id);
      _selectedVehicle = vehicle;
      return vehicle;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('VehicleProvider: Error getting vehicle: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<VehicleModel?> createVehicle(Map<String, dynamic> vehicleData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final vehicle = await _vehicleService.createVehicle(vehicleData);
      if (vehicle != null) {
        _vehicles.insert(0, vehicle);
      }
      return vehicle;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('VehicleProvider: Error creating vehicle: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateVehicle(String id, Map<String, dynamic> vehicleData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final vehicle = await _vehicleService.updateVehicle(id, vehicleData);
      if (vehicle != null) {
        final index = _vehicles.indexWhere((v) => v.id == id);
        if (index != -1) {
          _vehicles[index] = vehicle;
        }
        if (_selectedVehicle?.id == id) {
          _selectedVehicle = vehicle;
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('VehicleProvider: Error updating vehicle: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteVehicle(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _vehicleService.deleteVehicle(id);
      if (success) {
        _vehicles.removeWhere((v) => v.id == id);
        if (_selectedVehicle?.id == id) {
          _selectedVehicle = null;
        }
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('VehicleProvider: Error deleting vehicle: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<TripModel>> getVehicleTrips(String id) async {
    try {
      return await _vehicleService.getVehicleTrips(id);
    } catch (e) {
      if (kDebugMode) {
        print('VehicleProvider: Error getting vehicle trips: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> getVehicleAvailability(String id) async {
    try {
      return await _vehicleService.getVehicleAvailability(id);
    } catch (e) {
      if (kDebugMode) {
        print('VehicleProvider: Error getting availability: $e');
      }
      return null;
    }
  }

  Future<bool> uploadDocument(
    String id,
    String documentType,
    String filePath, {
    DateTime? expiryDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _vehicleService.uploadVehicleDocument(
        id,
        documentType,
        filePath,
        expiryDate: expiryDate,
      );
      if (success) {
        // Reload vehicle to get updated documents
        await getVehicleById(id);
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('VehicleProvider: Error uploading document: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getDocuments(String id) async {
    try {
      return await _vehicleService.getVehicleDocuments(id);
    } catch (e) {
      if (kDebugMode) {
        print('VehicleProvider: Error getting documents: $e');
      }
      return [];
    }
  }

  void selectVehicle(VehicleModel? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

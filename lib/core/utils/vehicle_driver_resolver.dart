import '../constants/app_constants.dart';
import '../../data/models/driver_model.dart';
import '../../data/models/vehicle_model.dart';

/// Returns the active driver linked to [vehicle], or null if none/unavailable.
DriverModel? resolveDriverForVehicle(
  VehicleModel vehicle,
  List<DriverModel> drivers,
) {
  if (vehicle.driver != null &&
      vehicle.driver!.status == AppConstants.driverStatusActive) {
    return vehicle.driver;
  }
  final id = vehicle.driverId;
  if (id == null || id.isEmpty) return null;

  for (final driver in drivers) {
    if (driver.id == id && driver.status == AppConstants.driverStatusActive) {
      return driver;
    }
  }
  return null;
}

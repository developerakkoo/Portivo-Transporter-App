import 'package:dio/dio.dart';

/// HTTP 409 when a driver is already linked to another vehicle.
class DriverAlreadyAssignedException implements Exception {
  static const code = 'DRIVER_ALREADY_ASSIGNED';

  final String message;
  final String? driverId;
  final String? driverName;
  final String? driverMobile;
  final String? currentVehicleId;
  final String? currentVehicleNumber;
  final String? currentVehicleType;
  final double? currentCargoWeightMt;

  const DriverAlreadyAssignedException({
    this.message = 'Driver is already assigned to another vehicle',
    this.driverId,
    this.driverName,
    this.driverMobile,
    this.currentVehicleId,
    this.currentVehicleNumber,
    this.currentVehicleType,
    this.currentCargoWeightMt,
  });

  String get displayName =>
      (driverName != null && driverName!.trim().isNotEmpty)
          ? driverName!.trim()
          : 'This driver';

  String get formattedMobile {
    final digits = (driverMobile ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (last10.length != 10) return driverMobile ?? '';
    return '${last10.substring(0, 5)} ${last10.substring(5)}';
  }

  static DriverAlreadyAssignedException? tryParse(Object error) {
    if (error is DriverAlreadyAssignedException) return error;
    if (error is! DioException) return null;
    if (error.response?.statusCode != 409) return null;
    final data = error.response?.data;
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final nested = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : const <String, dynamic>{};
    final code = map['code']?.toString();
    final currentVehicle = _asMap(map['currentVehicle']) ??
        _asMap(nested['currentVehicle']);
    final isAssignedCode = code == DriverAlreadyAssignedException.code;
    final hasCurrentVehicle = currentVehicle != null;
    if (!isAssignedCode && !hasCurrentVehicle) return null;

    final driver = _asMap(nested['driver']) ?? _asMap(map['driver']);
    return DriverAlreadyAssignedException(
      message: map['message']?.toString() ??
          'Driver is already assigned to another vehicle',
      driverId: driver?['id']?.toString() ?? driver?['_id']?.toString(),
      driverName: driver?['name']?.toString(),
      driverMobile: driver?['mobile']?.toString(),
      currentVehicleId:
          currentVehicle?['id']?.toString() ?? currentVehicle?['_id']?.toString(),
      currentVehicleNumber: currentVehicle?['vehicleNumber']?.toString(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  @override
  String toString() => message;
}

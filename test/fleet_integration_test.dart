import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prottivo_transporter/core/utils/vehicle_create_payload.dart';
import 'package:prottivo_transporter/core/utils/validators.dart';
import 'package:prottivo_transporter/data/models/driver_already_assigned_exception.dart';
import 'package:prottivo_transporter/data/models/driver_model.dart';
import 'package:prottivo_transporter/data/models/vehicle_model.dart';

void main() {
  group('DriverModel.fromJson', () {
    test('parses optional license and alternate mobile', () {
      final driver = DriverModel.fromJson({
        'id': 'd1',
        'name': 'Jay',
        'mobile': '9876543210',
        'status': 'active',
        'alternateMobile': '8765432109',
        'licenseNumber': 'MH1220191234567',
        'licenseValidTill': '2027-09-12',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(driver.id, 'd1');
      expect(driver.alternateMobile, '8765432109');
      expect(driver.licenseNumber, 'MH1220191234567');
      expect(driver.licenseValidTill?.year, 2027);
    });

    test('keeps empty optionals as null', () {
      final driver = DriverModel.fromJson({
        'id': 'd1',
        'mobile': '9876543210',
        'status': 'active',
        'alternateMobile': '',
        'licenseNumber': null,
      });
      expect(driver.alternateMobile, isNull);
      expect(driver.licenseNumber, isNull);
      expect(driver.licenseValidTill, isNull);
    });
  });

  group('VehicleModel.fromJson', () {
    test('parses cargoWeightMt and nested driver', () {
      final vehicle = VehicleModel.fromJson({
        'id': 'v1',
        'vehicleNumber': 'MH04TT1224',
        'transporterId': 't1',
        'ownerType': 'OWN',
        'status': 'active',
        'cargoWeightMt': 32,
        'driverId': 'd1',
        'driver': {
          'id': 'd1',
          'name': 'Jay',
          'mobile': '9876543210',
          'status': 'active',
        },
      });

      expect(vehicle.cargoWeightMt, 32);
      expect(vehicle.driverId, 'd1');
      expect(vehicle.driver?.name, 'Jay');
    });
  });

  group('buildVehicleCreatePayload', () {
    test('omits forceReassign and cargo when not set', () {
      final payload = buildVehicleCreatePayload(
        vehicleNumber: 'MH04TT1224',
        vehicleType: 'Trailer',
        driverId: 'd1',
      );
      expect(payload.containsKey('forceReassign'), isFalse);
      expect(payload.containsKey('cargoWeightMt'), isFalse);
      expect(payload['ownerType'], 'OWN');
    });

    test('includes cargoWeightMt and forceReassign only when provided', () {
      final payload = buildVehicleCreatePayload(
        vehicleNumber: 'MH04TT1224',
        vehicleType: 'Trailer',
        driverId: 'd1',
        cargoWeightMt: 0,
        forceReassign: true,
      );
      expect(payload['cargoWeightMt'], 0);
      expect(payload['forceReassign'], true);
    });
  });

  group('Validators cargo and optional mobile', () {
    test('allows empty cargo and zero', () {
      expect(Validators.validateOptionalCargoWeightMt(''), isNull);
      expect(Validators.validateOptionalCargoWeightMt('0'), isNull);
      expect(Validators.parseOptionalCargoWeightMt('32'), 32);
    });

    test('rejects negative cargo', () {
      expect(Validators.validateOptionalCargoWeightMt('-1'), isNotNull);
    });

    test('optional mobile empty is valid', () {
      expect(Validators.validateOptionalMobile(''), isNull);
      expect(Validators.validateOptionalMobile('9876543210'), isNull);
      expect(Validators.validateOptionalMobile('123'), isNotNull);
    });
  });

  group('DriverAlreadyAssignedException', () {
    test('parses nested 409 contract', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/vehicles'),
        response: Response(
          requestOptions: RequestOptions(path: '/vehicles'),
          statusCode: 409,
          data: {
            'success': false,
            'code': 'DRIVER_ALREADY_ASSIGNED',
            'message': 'Driver is already assigned to another vehicle',
            'currentVehicle': {
              'id': 'old-v',
              'vehicleNumber': 'MH03EB6848',
            },
            'data': {
              'driver': {
                'id': 'd1',
                'name': 'Jay',
                'mobile': '9876545210',
              },
              'currentVehicle': {
                'id': 'old-v',
                'vehicleNumber': 'MH03EB6848',
              },
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final parsed = DriverAlreadyAssignedException.tryParse(error);
      expect(parsed, isNotNull);
      expect(parsed!.driverName, 'Jay');
      expect(parsed.currentVehicleNumber, 'MH03EB6848');
      expect(parsed.formattedMobile, '98765 45210');
    });

    test('does not parse driver-mobile duplicate 409', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/drivers'),
        response: Response(
          requestOptions: RequestOptions(path: '/drivers'),
          statusCode: 409,
          data: {
            'success': false,
            'message': 'Driver with this mobile number already exists',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(DriverAlreadyAssignedException.tryParse(error), isNull);
    });
  });
}

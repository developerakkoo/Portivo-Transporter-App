import 'package:flutter_test/flutter_test.dart';

import 'package:prottivo_transporter/core/utils/vehicle_overflow.dart';

void main() {
  group('extraVehiclesLabel', () {
    test('is empty when there are no extra vehicles', () {
      expect(extraVehiclesLabel(0), '');
      expect(extraVehiclesLabel(-1), '');
    });

    test('uses singular for one extra vehicle', () {
      expect(extraVehiclesLabel(1), '+1 more vehicle');
    });

    test('uses plural for two or more extra vehicles', () {
      expect(extraVehiclesLabel(2), '+2 more vehicles');
    });
  });

  group('vehicleOverflowFromPlates', () {
    test('returns the only plate with no overflow', () {
      final overflow = vehicleOverflowFromPlates(['MH12AB1234', '', null]);
      expect(overflow.primary, 'MH12AB1234');
      expect(overflow.extraCount, 0);
      expect(overflow.extraLabel, '');
    });

    test('dedupes plates and labels extras', () {
      final overflow = vehicleOverflowFromPlates([
        'MH12AB1234',
        'MH12AB1234',
        'KA05CD9999',
      ]);
      expect(overflow.primary, 'MH12AB1234');
      expect(overflow.extraCount, 1);
      expect(overflow.extraLabel, '+1 more vehicle');
    });
  });
}

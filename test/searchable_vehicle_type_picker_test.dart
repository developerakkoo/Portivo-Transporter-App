import 'package:flutter_test/flutter_test.dart';
import 'package:prottivo_transporter/providers/vehicle_type_provider.dart';

void main() {
  group('filterVehicleTypeNames', () {
    const catalog = [
      '20FT Trailer',
      '20FT Reefer',
      '20FT Truck',
      '40FT Reefer',
      'ODC Trailer',
    ];

    test('typing 20 shows 20FT matches', () {
      expect(
        filterVehicleTypeNames(catalogNames: catalog, pendingNames: const [], query: '20'),
        ['20FT Trailer', '20FT Reefer', '20FT Truck'],
      );
    });

    test('typing Reefer shows reefer types', () {
      expect(
        filterVehicleTypeNames(catalogNames: catalog, pendingNames: const [], query: 'Reefer'),
        ['20FT Reefer', '40FT Reefer'],
      );
    });

    test('typing ODC shows ODC Trailer', () {
      expect(
        filterVehicleTypeNames(catalogNames: catalog, pendingNames: const [], query: 'ODC'),
        ['ODC Trailer'],
      );
    });

    test('includes pending names in results', () {
      expect(
        filterVehicleTypeNames(
          catalogNames: catalog,
          pendingNames: const ['Custom Flatbed'],
          query: 'custom',
        ),
        ['Custom Flatbed'],
      );
    });
  });
}

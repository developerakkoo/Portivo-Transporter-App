import 'package:google_maps_flutter/google_maps_flutter.dart';

class OperatingCountry {
  final String code;
  final String name;
  final LatLng defaultCenter;

  const OperatingCountry({
    required this.code,
    required this.name,
    required this.defaultCenter,
  });
}

/// Supported transporter operating countries (must match API [OPERATING_COUNTRIES]).
class OperatingCountries {
  OperatingCountries._();

  static const String defaultCode = 'IN';

  static const List<OperatingCountry> all = [
    OperatingCountry(
      code: 'IN',
      name: 'India',
      defaultCenter: LatLng(19.0760, 72.8777),
    ),
    OperatingCountry(
      code: 'AE',
      name: 'United Arab Emirates',
      defaultCenter: LatLng(25.2048, 55.2708),
    ),
    OperatingCountry(
      code: 'SA',
      name: 'Saudi Arabia',
      defaultCenter: LatLng(24.7136, 46.6753),
    ),
    OperatingCountry(
      code: 'OM',
      name: 'Oman',
      defaultCenter: LatLng(23.5880, 58.3829),
    ),
    OperatingCountry(
      code: 'QA',
      name: 'Qatar',
      defaultCenter: LatLng(25.2854, 51.5310),
    ),
    OperatingCountry(
      code: 'KW',
      name: 'Kuwait',
      defaultCenter: LatLng(29.3759, 47.9774),
    ),
    OperatingCountry(
      code: 'BH',
      name: 'Bahrain',
      defaultCenter: LatLng(26.2285, 50.5860),
    ),
  ];

  static OperatingCountry? findByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final upper = code.toUpperCase();
    for (final country in all) {
      if (country.code == upper) return country;
    }
    return null;
  }

  static String displayName(String? code) {
    return findByCode(code)?.name ?? (code ?? defaultCode);
  }

  static LatLng defaultCenterFor(String? code) {
    return findByCode(code)?.defaultCenter ??
        findByCode(defaultCode)!.defaultCenter;
  }

  static bool isSupported(String? code) => findByCode(code) != null;
}

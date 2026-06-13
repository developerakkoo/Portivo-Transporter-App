import 'package:geocoding/geocoding.dart';

/// How confident we are about country restriction and origin quality.
enum SearchRegionConfidence {
  /// Operating country or geocoding confirmed country.
  high,

  /// Coordinates only (e.g. geocoding failed); origin bias without country lock.
  low,

  /// No position; country filter only (no origin).
  none,
}

/// Resolved search bias for Google Places (native SDK wrapper).
class SearchRegionContext {
  final double? latitude;
  final double? longitude;
  final SearchRegionConfidence confidence;

  /// ISO 3166-1 alpha-2 codes passed to Places `countries`. Null = worldwide.
  final List<String>? countryCodes;

  const SearchRegionContext({
    this.latitude,
    this.longitude,
    this.confidence = SearchRegionConfidence.none,
    this.countryCodes,
  });

  static const SearchRegionContext unknown = SearchRegionContext();

  bool get hasApproxLocation =>
      latitude != null && longitude != null;

  bool get restrictsToCountry =>
      countryCodes != null && countryCodes!.isNotEmpty;

  SearchRegionContext copyWith({
    double? latitude,
    double? longitude,
    SearchRegionConfidence? confidence,
    List<String>? countryCodes,
    bool clearCountryCodes = false,
  }) {
    return SearchRegionContext(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      confidence: confidence ?? this.confidence,
      countryCodes: clearCountryCodes ? null : (countryCodes ?? this.countryCodes),
    );
  }

  /// Primary source: transporter operating country. GPS supplies origin bias when available.
  static SearchRegionContext fromOperatingCountry(
    String countryCode, {
    double? latitude,
    double? longitude,
  }) {
    final code = countryCode.trim().toUpperCase();
    return SearchRegionContext(
      latitude: latitude,
      longitude: longitude,
      confidence: SearchRegionConfidence.high,
      countryCodes: [code],
    );
  }

  /// Broad bbox for mainland India — first stage before geocoding.
  static bool roughBBoxContainsIndia(double lat, double lng) {
    return lat >= 6.4 &&
        lat <= 37.6 &&
        lng >= 68.7 &&
        lng <= 97.25;
  }

  static bool isIndiaIsoCountry(String? isoCountryCode) {
    if (isoCountryCode == null || isoCountryCode.isEmpty) return false;
    return isoCountryCode.toUpperCase() == 'IN';
  }

  /// Build context from a GPS fix (fallback when operating country is unknown).
  static Future<SearchRegionContext> fromLatLng(double lat, double lng) async {
    if (!roughBBoxContainsIndia(lat, lng)) {
      return SearchRegionContext(
        latitude: lat,
        longitude: lng,
        confidence: SearchRegionConfidence.high,
      );
    }

    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 4));
      if (marks.isEmpty) {
        return SearchRegionContext(
          latitude: lat,
          longitude: lng,
          confidence: SearchRegionConfidence.low,
        );
      }
      final iso = marks.first.isoCountryCode;
      final inIndia = isIndiaIsoCountry(iso);
      return SearchRegionContext(
        latitude: lat,
        longitude: lng,
        confidence: SearchRegionConfidence.high,
        countryCodes: inIndia ? ['IN'] : null,
      );
    } catch (_) {
      return SearchRegionContext(
        latitude: lat,
        longitude: lng,
        confidence: SearchRegionConfidence.low,
      );
    }
  }
}

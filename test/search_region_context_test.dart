import 'package:flutter_test/flutter_test.dart';
import 'package:prottivo_transporter/services/search_region_context.dart';

void main() {
  group('SearchRegionContext', () {
    test('roughBBoxContainsIndia includes Mumbai', () {
      expect(SearchRegionContext.roughBBoxContainsIndia(19.076, 72.8777), isTrue);
    });

    test('roughBBoxContainsIndia excludes London', () {
      expect(SearchRegionContext.roughBBoxContainsIndia(51.5, -0.12), isFalse);
    });

    test('isIndiaIsoCountry', () {
      expect(SearchRegionContext.isIndiaIsoCountry('IN'), isTrue);
      expect(SearchRegionContext.isIndiaIsoCountry('in'), isTrue);
      expect(SearchRegionContext.isIndiaIsoCountry('US'), isFalse);
      expect(SearchRegionContext.isIndiaIsoCountry(null), isFalse);
    });

    test('fromOperatingCountry sets country filter', () {
      final ctx = SearchRegionContext.fromOperatingCountry(
        'AE',
        latitude: 25.2,
        longitude: 55.3,
      );
      expect(ctx.countryCodes, ['AE']);
      expect(ctx.latitude, 25.2);
      expect(ctx.longitude, 55.3);
      expect(ctx.confidence, SearchRegionConfidence.high);
    });

    test('copyWith preserves unspecified fields', () {
      const ctx = SearchRegionContext(
        latitude: 12.9,
        longitude: 77.6,
        confidence: SearchRegionConfidence.high,
        countryCodes: ['IN'],
      );
      final u = ctx.copyWith(clearCountryCodes: true);
      expect(u.latitude, 12.9);
      expect(u.longitude, 77.6);
      expect(u.confidence, SearchRegionConfidence.high);
      expect(u.countryCodes, isNull);
    });
  });
}

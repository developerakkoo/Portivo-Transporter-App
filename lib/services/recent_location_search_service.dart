import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/trip_model.dart';

class RecentLocationSearchService {
  RecentLocationSearchService._();

  static const _key = 'recent_location_searches';
  static const _maxItems = 8;

  static Future<List<TripLocation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((row) => TripLocation.fromJson(Map<String, dynamic>.from(row)))
          .where((loc) => (loc.address ?? '').trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> remember(TripLocation location) async {
    final address = location.address?.trim() ?? '';
    if (address.isEmpty) return;
    final items = await load();
    items.removeWhere(
      (existing) => (existing.address ?? '').trim() == address,
    );
    items.insert(0, location);
    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((loc) => loc.toJson()).toList()),
    );
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for pinned trip IDs (shown on home).
class PinnedTripsService {
  static const String _key = 'pinned_trip_ids';
  static const int _maxPinned = 10;

  Future<Set<String>> getPinnedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<bool> isPinned(String tripId) async {
    final ids = await getPinnedIds();
    return ids.contains(tripId);
  }

  Future<void> pinTrip(String tripId) async {
    final ids = await getPinnedIds();
    if (ids.contains(tripId)) return;
    if (ids.length >= _maxPinned) {
      if (kDebugMode) {
        print('PinnedTripsService: max pinned ($_maxPinned) reached');
      }
      return;
    }
    ids.add(tripId);
    await _save(ids);
  }

  Future<void> unpinTrip(String tripId) async {
    final ids = await getPinnedIds();
    if (!ids.remove(tripId)) return;
    await _save(ids);
  }

  Future<void> togglePin(String tripId) async {
    if (await isPinned(tripId)) {
      await unpinTrip(tripId);
    } else {
      await pinTrip(tripId);
    }
  }

  Future<void> _save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ids.toList()));
  }

  /// Remove IDs that are no longer in the given set (optional cleanup).
  Future<void> removeStaleIds(Set<String> validIds) async {
    final ids = await getPinnedIds();
    final next = ids.where(validIds.contains).toSet();
    if (next.length != ids.length) await _save(next);
  }
}

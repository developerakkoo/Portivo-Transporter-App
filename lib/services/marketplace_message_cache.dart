import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/marketplace_chat_models.dart';

/// Persistent per-booking message list for marketplace chat (scoped by actor id).
class MarketplaceMessageCache {
  MarketplaceMessageCache._();
  static final MarketplaceMessageCache instance = MarketplaceMessageCache._();

  static const int maxPerBooking = 500;
  static const String _prefix = 'mchat_v1_';

  static String _key(String actorId, String bookingId) =>
      '$_prefix${actorId}_$bookingId';

  /// Merge [incoming] (API/socket truth for server ids) with [existing] (keeps `local-*` pending rows).
  static List<MarketplaceMessage> mergeById(
    List<MarketplaceMessage> existing,
    List<MarketplaceMessage> incoming,
  ) {
    final byId = <String, MarketplaceMessage>{};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    for (final m in existing) {
      if (m.id.startsWith('local-')) {
        byId[m.id] = m;
      } else {
        byId.putIfAbsent(m.id, () => m);
      }
    }
    final out = byId.values.toList()
      ..sort((a, b) {
        final ca = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final c = ca.compareTo(cb);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    if (out.length <= maxPerBooking) return out;
    return out.sublist(out.length - maxPerBooking);
  }

  Future<List<MarketplaceMessage>> getMessages({
    required String actorId,
    required String bookingId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(actorId, bookingId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <MarketplaceMessage>[];
      for (final item in list) {
        if (item is Map) {
          final m = MarketplaceMessage.fromJson(Map<String, dynamic>.from(item));
          if (m != null) out.add(m);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> putMessages({
    required String actorId,
    required String bookingId,
    required List<MarketplaceMessage> messages,
  }) async {
    final capped = messages.length > maxPerBooking
        ? messages.sublist(messages.length - maxPerBooking)
        : messages;
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(capped.map((m) => m.toJson()).toList());
    await prefs.setString(_key(actorId, bookingId), encoded);
  }

  Future<void> removeBooking({
    required String actorId,
    required String bookingId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(actorId, bookingId));
  }

  Future<void> clearAllForActor(String actorId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_prefix${actorId}_';
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      await prefs.remove(k);
    }
  }

  /// Clear every marketplace message cache (e.g. invalid session).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(k);
    }
  }
}

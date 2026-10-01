import 'package:flutter/material.dart';

/// A single entry in a listing's activity timeline (from
/// GET /vehicle-posts/:id/activity).
class VehiclePostActivity {
  const VehiclePostActivity({
    required this.id,
    required this.action,
    this.actorName,
    this.details = const {},
    this.notes,
    this.source = 'API',
    this.createdAt,
  });

  final String id;

  /// Backend action code, e.g. CREATED, QUANTITY_CHANGED, RATES_UPDATED,
  /// ROUTE_ADDED, ROUTE_REMOVED, VEHICLE_ADDED, PAUSED, RESUMED, ACTIVATED,
  /// CANCELLED, FULFILLED, UPDATED.
  final String action;

  /// Display name of the actor (company preferred, else name). Null for
  /// SYSTEM events.
  final String? actorName;

  final Map<String, dynamic> details;
  final String? notes;
  final String source;
  final DateTime? createdAt;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static VehiclePostActivity? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = (json['id'] ?? json['_id'])?.toString();
    if (id == null || id.isEmpty) return null;

    String? actorName;
    final pb = json['performedBy'];
    if (pb is Map) {
      final company = pb['company']?.toString();
      final name = pb['name']?.toString();
      actorName = (company != null && company.trim().isNotEmpty)
          ? company
          : (name != null && name.trim().isNotEmpty ? name : null);
    }

    Map<String, dynamic> details = {};
    final d = json['details'];
    if (d is Map) {
      details = Map<String, dynamic>.from(d);
    }

    return VehiclePostActivity(
      id: id,
      action: (json['action'] ?? 'UPDATED').toString(),
      actorName: actorName,
      details: details,
      notes: json['notes']?.toString(),
      source: (json['source'] ?? 'API').toString(),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  /// Icon representing this activity type.
  IconData get icon {
    switch (action) {
      case 'CREATED':
        return Icons.add_box_outlined;
      case 'ACTIVATED':
      case 'RESUMED':
        return Icons.play_circle_outline;
      case 'PAUSED':
        return Icons.pause_circle_outline;
      case 'QUANTITY_CHANGED':
        return Icons.inventory_2_outlined;
      case 'RATES_UPDATED':
        return Icons.edit_outlined;
      case 'ROUTE_ADDED':
        return Icons.add_location_alt_outlined;
      case 'ROUTE_REMOVED':
        return Icons.wrong_location_outlined;
      case 'VEHICLE_ADDED':
        return Icons.local_shipping_outlined;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'FULFILLED':
        return Icons.check_circle_outline;
      default:
        return Icons.update;
    }
  }

  /// Short human-readable title, e.g. "Availability Updated".
  String get title {
    switch (action) {
      case 'CREATED':
        return 'Listing Created';
      case 'ACTIVATED':
        return 'Listing Activated';
      case 'RESUMED':
        return 'Listing Resumed';
      case 'PAUSED':
        return 'Listing Paused';
      case 'QUANTITY_CHANGED':
        return 'Availability Updated';
      case 'RATES_UPDATED':
        return 'Rates Updated';
      case 'ROUTE_ADDED':
        return 'Route Added';
      case 'ROUTE_REMOVED':
        return 'Route Removed';
      case 'VEHICLE_ADDED':
        return 'Vehicles Added';
      case 'CANCELLED':
        return 'Listing Cancelled';
      case 'FULFILLED':
        return 'Fully Booked';
      default:
        return 'Listing Updated';
    }
  }

  /// Detail subtitle derived from [details]/[notes], e.g. "Quantity changed: 2 -> 3".
  String get subtitle {
    switch (action) {
      case 'QUANTITY_CHANGED':
        final from = details['from'];
        final to = details['to'];
        if (from != null && to != null) {
          return 'Quantity changed: $from \u2192 $to';
        }
        break;
      case 'RATES_UPDATED':
        final count = details['count'];
        if (count != null) {
          return '$count route${count == 1 ? '' : 's'} updated';
        }
        break;
      case 'ROUTE_ADDED':
      case 'ROUTE_REMOVED':
        final dest = details['destination'];
        if (dest != null && dest.toString().trim().isNotEmpty) {
          return dest.toString();
        }
        break;
      case 'VEHICLE_ADDED':
        final count = details['count'];
        if (count != null) {
          return '$count vehicle${count == 1 ? '' : 's'} added';
        }
        break;
    }
    return notes ?? '';
  }
}

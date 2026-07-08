import '../../core/utils/json_parser.dart';

/// Result of a single row in a bulk fleet import (or a manual save row).
class FleetImportRowResult {
  final int row;
  final bool success;
  final String? vehicleNumber;
  final String? vehicleId;
  final String? driverId;
  final String? error;

  FleetImportRowResult({
    required this.row,
    required this.success,
    this.vehicleNumber,
    this.vehicleId,
    this.driverId,
    this.error,
  });

  factory FleetImportRowResult.fromJson(Map<String, dynamic> json) {
    return FleetImportRowResult(
      row: JsonParser.extractInt(json['row'], 0),
      success: json['success'] == true,
      vehicleNumber: json['vehicleNumber']?.toString(),
      vehicleId: json['vehicleId']?.toString(),
      driverId: json['driverId']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

/// Summary + per-row results of a bulk fleet import (or a manual save batch).
class FleetImportResult {
  final int total;
  final int succeeded;
  final int failed;
  final List<FleetImportRowResult> results;

  FleetImportResult({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.results,
  });

  factory FleetImportResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? json['data'] as Map : json;
    final summary = (data['summary'] is Map) ? data['summary'] as Map : const {};
    final rawResults = (data['results'] is List) ? data['results'] as List : const [];

    return FleetImportResult(
      total: JsonParser.extractInt(summary['total'], rawResults.length),
      succeeded: JsonParser.extractInt(summary['succeeded'], 0),
      failed: JsonParser.extractInt(summary['failed'], 0),
      results: rawResults
          .whereType<Map>()
          .map((e) => FleetImportRowResult.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

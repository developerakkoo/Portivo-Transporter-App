/// Formatting helpers for the persisted live-tracking metrics (ETA / distance),
/// shared by the trip-group card and the vehicle-view rows.
class TrackingFormat {
  TrackingFormat._();

  /// Human-readable ETA, e.g. "12 min" or "1 h 5 min". Null when unknown.
  static String? eta(int? etaSeconds) {
    final s = etaSeconds;
    if (s == null || s <= 0) return null;
    if (s < 60) return '< 1 min';
    final minutes = (s / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// Human-readable remaining distance, e.g. "850 m" or "12.4 km". Null when unknown.
  static String? distance(double? meters) {
    final d = meters;
    if (d == null || d < 0) return null;
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }
}

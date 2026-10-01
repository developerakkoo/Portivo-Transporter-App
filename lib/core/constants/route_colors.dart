import 'package:flutter/material.dart';

/// Fixed, high-contrast palette used to color a trip group's routes on the
/// fleet map. A trip's [TripModel.routeIndex] maps into this list (wrapping
/// around when there are more routes than colors), so every vehicle from the
/// same route shares one color across markers, polylines and legends.
class RouteColors {
  RouteColors._();

  static const List<Color> palette = <Color>[
    Color(0xFF2563EB), // blue
    Color(0xFFEA580C), // orange
    Color(0xFF16A34A), // green
    Color(0xFF9333EA), // purple
    Color(0xFFDC2626), // red
    Color(0xFF0891B2), // cyan
    Color(0xFFCA8A04), // amber
    Color(0xFFDB2777), // pink
    Color(0xFF4F46E5), // indigo
    Color(0xFF059669), // emerald
  ];

  /// Color for a given route index (wraps around for large batches).
  static Color forIndex(int routeIndex) {
    if (palette.isEmpty) return const Color(0xFF2563EB);
    final i = routeIndex % palette.length;
    return palette[i < 0 ? i + palette.length : i];
  }
}

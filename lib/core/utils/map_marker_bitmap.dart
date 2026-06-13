import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

/// Renders Material icons to [BitmapDescriptor] for Google Maps markers (with caching).
class MapMarkerBitmap {
  MapMarkerBitmap._();

  static final Map<String, BitmapDescriptor> _cache = {};

  static String _key(IconData icon, Color color, double size) =>
      '${icon.codePoint}_${color.value}_$size';

  static Future<BitmapDescriptor> fromIcon(
    IconData icon,
    Color color, {
    double logicalSize = 56,
  }) async {
    final key = _key(icon, color, logicalSize);
    final cached = _cache[key];
    if (cached != null) return cached;

    final views = WidgetsBinding.instance.platformDispatcher.views;
    final dpr = views.isNotEmpty ? views.first.devicePixelRatio : 2.0;
    final px = (logicalSize * dpr).round().clamp(48, 256);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: px * 0.55,
        fontFamily: icon.fontFamily ?? 'MaterialIcons',
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    final ox = (px - textPainter.width) / 2;
    final oy = (px - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(ox, oy));

    final picture = recorder.endRecording();
    final image = await picture.toImage(px, px);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    final bytes = byteData.buffer.asUint8List();
    final descriptor = BitmapDescriptor.fromBytes(bytes);
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<({BitmapDescriptor pickup, BitmapDescriptor drop, BitmapDescriptor truck})>
      loadTripMarkers() async {
    final pickup = await fromIcon(Icons.place, const Color(0xFF2E7D32), logicalSize: 52);
    final drop = await fromIcon(Icons.flag, const Color(0xFFC62828), logicalSize: 52);
    final truck = await fromIcon(Icons.local_shipping, AppColors.primary, logicalSize: 56);
    return (pickup: pickup, drop: drop, truck: truck);
  }
}

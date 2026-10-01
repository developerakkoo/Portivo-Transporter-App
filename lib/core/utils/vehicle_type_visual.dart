import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Maps a vehicle type name to a visual identity (SVG icon + accent color)
/// used by the Post Availability fleet list, stepper and My Listings.
///
/// Matching is keyword based so backend-managed type names like
/// "20ft Trailer", "40 ft Flatbed Trailer" or "Open Body Truck" all resolve
/// to a sensible icon without any hard-coded catalog.
class VehicleTypeVisual {
  final String svgAsset;
  final Color accentColor;
  final IconData fallbackIcon;

  const VehicleTypeVisual({
    required this.svgAsset,
    required this.accentColor,
    this.fallbackIcon = Icons.local_shipping,
  });

  static const _assetContainerTrailer =
      'assets/vehicle_types/container_trailer.svg';
  static const _assetOpenTruck = 'assets/vehicle_types/open_truck.svg';
  static const _assetTanker = 'assets/vehicle_types/tanker.svg';
  static const _assetTruck = 'assets/vehicle_types/truck.svg';

  // Accent palette (matches the mockup: blue 20ft, green 40ft, orange open).
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF16A34A);
  static const _orange = Color(0xFFF97316);
  static const _purple = Color(0xFF7C3AED);
  static const _teal = Color(0xFF0D9488);
  static const _slate = Color(0xFF475569);

  /// Palette used when no keyword rule decides the color; picked
  /// deterministically from the type name so each type stays distinct.
  static const _fallbackPalette = [_blue, _green, _orange, _purple, _teal, _slate];

  static VehicleTypeVisual forType(String? typeName) {
    final name = (typeName ?? '').toLowerCase();

    // Icon shape by keyword.
    String asset;
    IconData fallback = Icons.local_shipping;
    if (name.contains('tanker') || name.contains('tank')) {
      asset = _assetTanker;
      fallback = Icons.local_shipping;
    } else if (name.contains('open') ||
        name.contains('flatbed') ||
        name.contains('flat bed') ||
        name.contains('tipper')) {
      asset = _assetOpenTruck;
      fallback = Icons.fire_truck;
    } else if (name.contains('trailer') ||
        name.contains('container') ||
        name.contains('20ft') ||
        name.contains('40ft') ||
        name.contains('20 ft') ||
        name.contains('40 ft')) {
      asset = _assetContainerTrailer;
      fallback = Icons.local_shipping;
    } else {
      asset = _assetTruck;
    }

    // Accent color by keyword, deterministic palette otherwise.
    Color color;
    if (name.contains('20ft') || name.contains('20 ft')) {
      color = _blue;
    } else if (name.contains('40ft') || name.contains('40 ft')) {
      color = _green;
    } else if (name.contains('open') || name.contains('tipper')) {
      color = _orange;
    } else if (name.contains('tanker') || name.contains('tank')) {
      color = _purple;
    } else if (name.contains('trailer') || name.contains('container')) {
      color = _teal;
    } else {
      color = _fallbackPalette[name.hashCode.abs() % _fallbackPalette.length];
    }

    return VehicleTypeVisual(
      svgAsset: asset,
      accentColor: color,
      fallbackIcon: fallback,
    );
  }

  /// The tinted SVG truck icon by itself.
  Widget icon({double size = 40, Color? color}) {
    return SvgPicture.asset(
      svgAsset,
      width: size,
      height: size * (40 / 64),
      colorFilter: ColorFilter.mode(color ?? accentColor, BlendMode.srcIn),
    );
  }

  /// Icon inside a soft accent-tinted rounded badge (fleet cards, listings).
  Widget badge({double size = 56}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: icon(size: size * 0.62),
    );
  }
}

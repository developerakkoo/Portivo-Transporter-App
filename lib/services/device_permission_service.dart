import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for checking and requesting device/OS permissions.
/// Separate from [PermissionService] which handles app-level user/role permissions.
class DevicePermissionService {
  static const String _kLoginGateOsConfirmedKey = 'login_gate_location_camera_ok';
  /// Location + camera: asked once from the login sheet when missing.
  /// Contacts is requested in-context (e.g. [add_driver_screen]) when the user picks from contacts.
  static const List<Permission> loginPromptPermissions = [
    Permission.locationWhenInUse,
    Permission.camera,
  ];

  /// Permissions the app may need over its lifetime (includes contacts for driver pickers).
  static const List<Permission> appPermissions = [
    Permission.locationWhenInUse,
    Permission.contacts,
    Permission.camera,
  ];

  /// Check status of all app permissions
  Future<Map<Permission, PermissionStatus>> checkPermissions() async {
    final Map<Permission, PermissionStatus> statuses = {};
    for (final permission in appPermissions) {
      statuses[permission] = await permission.status;
    }
    return statuses;
  }

  /// Request all app permissions. Returns status after request.
  Future<Map<Permission, PermissionStatus>> requestPermissions() async {
    return await appPermissions.request();
  }

  /// Request only permissions shown on the login screen (location + camera).
  Future<Map<Permission, PermissionStatus>> requestLoginPromptPermissions() async {
    return await loginPromptPermissions.request();
  }

  /// Check if location permission is granted
  Future<bool> isLocationGranted() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  /// Check if contacts permission is granted
  Future<bool> isContactsGranted() async {
    return await Permission.contacts.isGranted;
  }

  /// Check if camera permission is granted
  Future<bool> isCameraGranted() async {
    return await Permission.camera.isGranted;
  }

  /// Open app settings so user can manually grant permissions
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// True when location, contacts, and camera are all granted (or limited for camera on iOS).
  Future<bool> areAllRequiredPermissionsGranted() async {
    for (final permission in appPermissions) {
      final status = await permission.status;
      final ok = status.isGranted || status == PermissionStatus.limited;
      if (!ok) return false;
    }
    return true;
  }

  /// Granted, limited (e.g. photo library), or provisional (iOS 14+).
  static bool _isOk(PermissionStatus status) {
    return status.isGranted ||
        status.isLimited ||
        status.isProvisional;
  }

  /// Location: [permission_handler] can report [denied] for [Permission.locationWhenInUse] when the user
  /// chose **approximate / coarse only** on Android 12+, while the app still has usable location.
  /// [Geolocator.checkPermission] matches the platform behavior Maps/tracking use.
  Future<bool> _isLocationEffectivelyGranted() async {
    try {
      final gp = await Geolocator.checkPermission();
      if (gp == LocationPermission.whileInUse || gp == LocationPermission.always) {
        return true;
      }
    } catch (_) {
      // Fall through to permission_handler.
    }

    final whenInUse = await Permission.locationWhenInUse.status;
    if (_isOk(whenInUse)) return true;
    final location = await Permission.location.status;
    if (_isOk(location)) return true;
    if (Platform.isAndroid) {
      final w2 = await Permission.locationWhenInUse.status;
      if (_isOk(w2)) return true;
    }
    return false;
  }

  Future<bool> _isCameraEffectivelyGranted() async {
    final status = await Permission.camera.status;
    if (_isOk(status)) return true;
    // Second read can flip right after returning from Settings.
    final again = await Permission.camera.status;
    return _isOk(again);
  }

  /// Persists when we have positively confirmed both login-gate permissions with the OS.
  Future<void> _persistLoginGateOk(bool ok) async {
    final prefs = await SharedPreferences.getInstance();
    if (ok) {
      await prefs.setBool(_kLoginGateOsConfirmedKey, true);
    } else {
      await prefs.remove(_kLoginGateOsConfirmedKey);
    }
  }

  /// True when location and camera are granted — do not show the login permission modal.
  /// Uses short retries because [permission_handler] can briefly report [denied] right after app start
  /// or after returning from Settings before the native layer updates.
  Future<bool> areLoginGatePermissionsGranted() async {
    const attempts = 5;
    const gap = Duration(milliseconds: 100);

    for (var i = 0; i < attempts; i++) {
      final loc = await _isLocationEffectivelyGranted();
      final cam = await _isCameraEffectivelyGranted();
      if (loc && cam) {
        await _persistLoginGateOk(true);
        return true;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(gap);
      }
    }

    // If we previously confirmed OK but OS now says no, user likely revoked in Settings.
    final prefs = await SharedPreferences.getInstance();
    final wasConfirmed = prefs.getBool(_kLoginGateOsConfirmedKey) ?? false;
    if (wasConfirmed) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final loc = await _isLocationEffectivelyGranted();
      final cam = await _isCameraEffectivelyGranted();
      if (loc && cam) {
        return true;
      }
      await _persistLoginGateOk(false);
    }

    return false;
  }

  /// Show the login permission sheet only when location or camera is not yet granted.
  Future<bool> shouldShowLoginPermissionModal() async {
    return !(await areLoginGatePermissionsGranted());
  }
}

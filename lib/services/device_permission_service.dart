import 'package:permission_handler/permission_handler.dart';

/// Service for checking and requesting device/OS permissions.
/// Separate from [PermissionService] which handles app-level user/role permissions.
class DevicePermissionService {
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

  /// Location: Android/iOS may report [Permission.location] vs [Permission.locationWhenInUse]
  /// differently after grant; treat as OK if either reports OK.
  Future<bool> _isLocationEffectivelyGranted() async {
    final whenInUse = await Permission.locationWhenInUse.status;
    if (_isOk(whenInUse)) return true;
    final location = await Permission.location.status;
    return _isOk(location);
  }

  Future<bool> _isCameraEffectivelyGranted() async {
    final status = await Permission.camera.status;
    return _isOk(status);
  }

  /// True when location and camera are granted — do not show the login permission modal.
  Future<bool> areLoginGatePermissionsGranted() async {
    final loc = await _isLocationEffectivelyGranted();
    final cam = await _isCameraEffectivelyGranted();
    return loc && cam;
  }

  /// Show the login permission sheet only when location or camera is not yet granted.
  Future<bool> shouldShowLoginPermissionModal() async {
    return !(await areLoginGatePermissionsGranted());
  }
}

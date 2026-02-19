import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';

/// Service for checking user permissions
/// Transporters have all permissions, company users have specific permissions
class PermissionService {
  final AuthProvider _authProvider;

  PermissionService(this._authProvider);

  /// Check if the current user has a specific permission
  /// Returns true for transporters (they have all permissions)
  /// Returns true for company users if they have the permission
  bool hasPermission(String permission) {
    final user = _authProvider.user;
    if (user == null) {
      if (kDebugMode) {
        print('PermissionService: No user found, denying permission: $permission');
        print('PermissionService: AuthProvider user is null');
      }
      return false;
    }

    if (kDebugMode) {
      print('PermissionService: Checking permission "$permission" for user: ${user.id}');
      print('PermissionService: User type: ${user.userType}');
      print('PermissionService: User permissions: ${user.permissions}');
    }

    // Transporters have all permissions
    if (user.userType == 'transporter') {
      if (kDebugMode) {
        print('PermissionService: User is transporter, granting permission: $permission');
      }
      return true;
    }

    // Company users need explicit permission
    final hasPermission = user.permissions.contains(permission);
    if (kDebugMode) {
      print('PermissionService: Company user permission check for "$permission": $hasPermission');
      print('PermissionService: User permissions: ${user.permissions}');
    }
    return hasPermission;
  }

  /// Check if the current user has any of the specified permissions
  /// Returns true if user has at least one of the permissions
  bool hasAnyPermission(List<String> permissions) {
    final user = _authProvider.user;
    if (user == null) {
      if (kDebugMode) {
        print('PermissionService: No user found, denying permissions: $permissions');
      }
      return false;
    }

    // Transporters have all permissions
    if (user.userType == 'transporter') {
      if (kDebugMode) {
        print('PermissionService: User is transporter, granting any permission: $permissions');
      }
      return true;
    }

    // Check if user has any of the permissions
    final hasAny = permissions.any((permission) => user.permissions.contains(permission));
    if (kDebugMode) {
      print('PermissionService: Company user hasAnyPermission check for $permissions: $hasAny');
    }
    return hasAny;
  }

  /// Check if the current user has all of the specified permissions
  /// Returns true only if user has all permissions
  bool hasAllPermissions(List<String> permissions) {
    final user = _authProvider.user;
    if (user == null) {
      if (kDebugMode) {
        print('PermissionService: No user found, denying permissions: $permissions');
      }
      return false;
    }

    // Transporters have all permissions
    if (user.userType == 'transporter') {
      if (kDebugMode) {
        print('PermissionService: User is transporter, granting all permissions: $permissions');
      }
      return true;
    }

    // Check if user has all permissions
    final hasAll = permissions.every((permission) => user.permissions.contains(permission));
    if (kDebugMode) {
      print('PermissionService: Company user hasAllPermissions check for $permissions: $hasAll');
    }
    return hasAll;
  }

  /// Check if the current user is a transporter
  bool get isTransporter {
    final user = _authProvider.user;
    final result = user?.userType == 'transporter';
    if (kDebugMode) {
      print('PermissionService: isTransporter check - user: ${user?.id}, userType: ${user?.userType}, result: $result');
    }
    return result;
  }

  /// Check if the current user is a company user
  bool get isCompanyUser {
    final user = _authProvider.user;
    return user?.userType == 'company-user';
  }

  /// Get all permissions for the current user
  /// Returns empty list if no user or if transporter (transporters don't need explicit permissions)
  List<String> getPermissions() {
    final user = _authProvider.user;
    if (user == null) {
      return [];
    }

    // Transporters have all permissions conceptually, but we return empty list
    // since they don't need explicit permission checks
    if (user.userType == 'transporter') {
      return [];
    }

    return List<String>.from(user.permissions);
  }
}

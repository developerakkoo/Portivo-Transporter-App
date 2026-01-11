enum UserPermission {
  viewTrips,
  createTrips,
  manageDrivers,
  manageVehicles,
  manageWallet,
  manageFuelCards,
  manageUsers,
  viewReports,
}

class AppUser {
  final String id;
  final String name;
  final String phone;
  final String? email;
  String? pin;
  bool hasAccess;
  List<UserPermission> permissions;
  final DateTime createdAt;
  DateTime updatedAt;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.pin,
    required this.hasAccess,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
  });

  bool hasPermission(UserPermission permission) {
    return permissions.contains(permission);
  }

  bool hasPinSet() {
    return pin != null && pin!.isNotEmpty;
  }

  List<String> getPermissionLabels() {
    return permissions.map((p) => _getPermissionLabel(p)).toList();
  }

  String _getPermissionLabel(UserPermission permission) {
    switch (permission) {
      case UserPermission.viewTrips:
        return 'View Trips';
      case UserPermission.createTrips:
        return 'Create Trips';
      case UserPermission.manageDrivers:
        return 'Manage Drivers';
      case UserPermission.manageVehicles:
        return 'Manage Vehicles';
      case UserPermission.manageWallet:
        return 'Manage Wallet';
      case UserPermission.manageFuelCards:
        return 'Manage Fuel Cards';
      case UserPermission.manageUsers:
        return 'Manage Users';
      case UserPermission.viewReports:
        return 'View Reports';
    }
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? pin,
    bool? hasAccess,
    List<UserPermission>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      pin: pin ?? this.pin,
      hasAccess: hasAccess ?? this.hasAccess,
      permissions: permissions ?? List.from(this.permissions),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


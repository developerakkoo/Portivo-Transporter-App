class CompanyUserModel {
  final String id;
  final String mobile;
  final String name;
  final String? email;
  final String transporterId;
  final bool hasAccess;
  final List<String> permissions;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyUserModel({
    required this.id,
    required this.mobile,
    required this.name,
    this.email,
    required this.transporterId,
    required this.hasAccess,
    required this.permissions,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyUserModel.fromJson(Map<String, dynamic> json) {
    return CompanyUserModel(
      id: json['_id'] ?? json['id'] ?? '',
      mobile: json['mobile'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      transporterId: json['transporterId']?.toString() ?? '',
      hasAccess: json['hasAccess'] ?? false,
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : [],
      status: json['status'] ?? 'active',
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mobile': mobile,
      'name': name,
      'email': email,
      'permissions': permissions,
      'hasAccess': hasAccess,
      'status': status,
    };
  }

  CompanyUserModel copyWith({
    String? id,
    String? mobile,
    String? name,
    String? email,
    String? transporterId,
    bool? hasAccess,
    List<String>? permissions,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyUserModel(
      id: id ?? this.id,
      mobile: mobile ?? this.mobile,
      name: name ?? this.name,
      email: email ?? this.email,
      transporterId: transporterId ?? this.transporterId,
      hasAccess: hasAccess ?? this.hasAccess,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool hasPinSet() {
    // Note: PIN is not returned from API, so we check if hasAccess is true
    // In practice, you might need a separate field or API call
    return hasAccess;
  }

  List<String> getPermissionLabels() {
    const permissionLabels = {
      'viewTrips': 'View Trips',
      'createTrips': 'Create Trips',
      'manageDrivers': 'Manage Drivers',
      'manageVehicles': 'Manage Vehicles',
      'manageWallet': 'Manage Wallet',
      'manageFuelCards': 'Manage Fuel Cards',
      'manageUsers': 'Manage Users',
      'viewReports': 'View Reports',
    };

    return permissions.map((p) => permissionLabels[p] ?? p).toList();
  }
}

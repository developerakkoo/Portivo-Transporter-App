/// Response from POST /auth/send-otp (no tokens).
class SendOtpResponse {
  const SendOtpResponse({
    required this.success,
    required this.message,
    this.mobile,
    this.userType,
    this.requestId,
  });

  final bool success;
  final String message;
  final String? mobile;
  final String? userType;
  final String? requestId;

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return SendOtpResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      mobile: map['mobile']?.toString(),
      userType: map['userType']?.toString(),
      requestId: map['requestId']?.toString(),
    );
  }
}

class AuthResponseModel {
  final bool success;
  final String message;
  final AuthData? data;

  AuthResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? AuthData.fromJson(json['data']) : null,
    );
  }
}

class AuthData {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  AuthData({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: UserModel.fromJson(json['user'] ?? {}),
    );
  }
}

class UserModel {
  final String id;
  final String mobile;
  final String? name;
  final String userType;
  final String status;
  final bool hasAccess;
  final String? transporterId; // For company users
  final List<String> permissions; // For company users
  final String? operatingCountry;
  final String? company;
  final bool hasPinSet;
  final String? kycStatus;
  final bool isKycCompleted;

  UserModel({
    required this.id,
    required this.mobile,
    this.name,
    required this.userType,
    required this.status,
    required this.hasAccess,
    this.transporterId,
    List<String>? permissions,
    this.operatingCountry,
    this.company,
    this.hasPinSet = false,
    this.kycStatus,
    this.isKycCompleted = false,
  }) : permissions = permissions ?? [];

  bool get isKycVerified {
    final status = kycStatus?.toLowerCase();
    return isKycCompleted || status == 'verified' || status == 'completed';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      mobile: json['mobile'] ?? '',
      name: json['name'],
      userType: json['userType'] ?? '',
      status: json['status'] ?? '',
      hasAccess: json['hasAccess'] ?? false,
      transporterId: json['transporterId']?.toString(),
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : [],
      operatingCountry: json['operatingCountry']?.toString().toUpperCase(),
      company: json['company']?.toString(),
      hasPinSet: json['hasPinSet'] == true,
      kycStatus: json['kycStatus']?.toString(),
      isKycCompleted: json['isKycCompleted'] == true,
    );
  }

  UserModel copyWith({
    String? id,
    String? mobile,
    String? name,
    String? userType,
    String? status,
    bool? hasAccess,
    String? transporterId,
    List<String>? permissions,
    String? operatingCountry,
    String? company,
    bool? hasPinSet,
    String? kycStatus,
    bool? isKycCompleted,
  }) {
    return UserModel(
      id: id ?? this.id,
      mobile: mobile ?? this.mobile,
      name: name ?? this.name,
      userType: userType ?? this.userType,
      status: status ?? this.status,
      hasAccess: hasAccess ?? this.hasAccess,
      transporterId: transporterId ?? this.transporterId,
      permissions: permissions ?? this.permissions,
      operatingCountry: operatingCountry ?? this.operatingCountry,
      company: company ?? this.company,
      hasPinSet: hasPinSet ?? this.hasPinSet,
      kycStatus: kycStatus ?? this.kycStatus,
      isKycCompleted: isKycCompleted ?? this.isKycCompleted,
    );
  }
}

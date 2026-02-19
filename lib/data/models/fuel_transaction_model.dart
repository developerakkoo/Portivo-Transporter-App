class FuelTransactionModel {
  final String id;
  final String transactionId;
  final String pumpOwnerId;
  final String? pumpStaffId;
  final String vehicleNumber;
  final String driverId;
  final String fuelCardId;
  final double amount;
  final String qrCode;
  final DateTime qrCodeExpiry;
  final TransactionLocation location;
  final String status;
  final TransactionReceipt? receipt;
  final FraudFlags? fraudFlags;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  FuelTransactionModel({
    required this.id,
    required this.transactionId,
    required this.pumpOwnerId,
    this.pumpStaffId,
    required this.vehicleNumber,
    required this.driverId,
    required this.fuelCardId,
    required this.amount,
    required this.qrCode,
    required this.qrCodeExpiry,
    required this.location,
    required this.status,
    this.receipt,
    this.fraudFlags,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FuelTransactionModel.fromJson(Map<String, dynamic> json) {
    return FuelTransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      transactionId: json['transactionId'] ?? '',
      pumpOwnerId: json['pumpOwnerId']?.toString() ?? '',
      pumpStaffId: json['pumpStaffId']?.toString(),
      vehicleNumber: json['vehicleNumber'] ?? '',
      driverId: json['driverId']?.toString() ?? '',
      fuelCardId: json['fuelCardId']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      qrCode: json['qrCode'] ?? '',
      qrCodeExpiry: json['qrCodeExpiry'] != null
          ? DateTime.parse(json['qrCodeExpiry'])
          : DateTime.now(),
      location: TransactionLocation.fromJson(json['location'] ?? {}),
      status: json['status'] ?? 'pending',
      receipt: json['receipt'] != null
          ? TransactionReceipt.fromJson(json['receipt'])
          : null,
      fraudFlags: json['fraudFlags'] != null
          ? FraudFlags.fromJson(json['fraudFlags'])
          : null,
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.parse(json['confirmedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      cancelledBy: json['cancelledBy']?.toString(),
      notes: json['notes'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  bool get isQRExpired => qrCodeExpiry.isBefore(DateTime.now());
  bool get hasFraudFlags => fraudFlags?.hasAnyFlag ?? false;
}

class TransactionLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final double? accuracy;

  TransactionLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.accuracy,
  });

  factory TransactionLocation.fromJson(Map<String, dynamic> json) {
    return TransactionLocation(
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      address: json['address'],
      accuracy: json['accuracy']?.toDouble(),
    );
  }
}

class TransactionReceipt {
  final String? photo;
  final DateTime? uploadedAt;
  final String? uploadedBy;

  TransactionReceipt({
    this.photo,
    this.uploadedAt,
    this.uploadedBy,
  });

  factory TransactionReceipt.fromJson(Map<String, dynamic> json) {
    return TransactionReceipt(
      photo: json['photo'],
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'])
          : null,
      uploadedBy: json['uploadedBy']?.toString(),
    );
  }
}

class FraudFlags {
  final bool duplicateReceipt;
  final bool gpsMismatch;
  final double? gpsMismatchDistance;
  final bool expressUploads;
  final bool unusualPattern;
  final String? flaggedBy;
  final DateTime? flaggedAt;
  final bool resolved;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  FraudFlags({
    required this.duplicateReceipt,
    required this.gpsMismatch,
    this.gpsMismatchDistance,
    required this.expressUploads,
    required this.unusualPattern,
    this.flaggedBy,
    this.flaggedAt,
    required this.resolved,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory FraudFlags.fromJson(Map<String, dynamic> json) {
    return FraudFlags(
      duplicateReceipt: json['duplicateReceipt'] ?? false,
      gpsMismatch: json['gpsMismatch'] ?? false,
      gpsMismatchDistance: json['gpsMismatchDistance']?.toDouble(),
      expressUploads: json['expressUploads'] ?? false,
      unusualPattern: json['unusualPattern'] ?? false,
      flaggedBy: json['flaggedBy']?.toString(),
      flaggedAt: json['flaggedAt'] != null
          ? DateTime.parse(json['flaggedAt'])
          : null,
      resolved: json['resolved'] ?? false,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : null,
      resolvedBy: json['resolvedBy']?.toString(),
    );
  }

  bool get hasAnyFlag =>
      duplicateReceipt || gpsMismatch || expressUploads || unusualPattern;
}

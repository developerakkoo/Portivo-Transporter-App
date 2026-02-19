class FuelCardModel {
  final String id;
  final String cardNumber;
  final String transporterId;
  final String? driverId;
  final double balance;
  final String status;
  final String? assignedBy;
  final DateTime? assignedAt;
  final DateTime? expiryDate;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  FuelCardModel({
    required this.id,
    required this.cardNumber,
    required this.transporterId,
    this.driverId,
    required this.balance,
    required this.status,
    this.assignedBy,
    this.assignedAt,
    this.expiryDate,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FuelCardModel.fromJson(Map<String, dynamic> json) {
    return FuelCardModel(
      id: json['_id'] ?? json['id'] ?? '',
      cardNumber: json['cardNumber'] ?? '',
      transporterId: json['transporterId']?.toString() ?? '',
      driverId: json['driverId']?.toString(),
      balance: (json['balance'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      assignedBy: json['assignedBy']?.toString(),
      assignedAt: json['assignedAt'] != null
          ? DateTime.parse(json['assignedAt'])
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  bool get isAssigned => driverId != null;
}

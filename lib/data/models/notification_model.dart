class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? readAt;
  final String? priority;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.read,
    this.readAt,
    this.priority,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {},
      read: json['read'] == true,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      priority: json['priority']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String? get tripId => data['tripId']?.toString();

  String? get bookingId => data['bookingId']?.toString();

  String? get marketplaceSenderId => data['senderId']?.toString();

  String? get marketplaceSenderName => data['senderName']?.toString();

  String? get vehicleTypeRequestId => data['requestId']?.toString();

  String? get requestedVehicleTypeName =>
      data['requestedName']?.toString();

  String? get vehicleTypeRejectionReason =>
      data['rejectionReason']?.toString();

  bool get isVehicleTypeDecision =>
      type == 'VEHICLE_TYPE_APPROVED' || type == 'VEHICLE_TYPE_REJECTED';
}

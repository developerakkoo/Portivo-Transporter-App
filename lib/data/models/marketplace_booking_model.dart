/// Typed booking detail for marketplace chat / payment banners.

class MarketplaceBookingDetail {
  const MarketplaceBookingDetail({
    required this.id,
    required this.status,
    this.agreedPrice,
    this.paymentStatus,
    this.buyerId,
    this.sellerId,
    this.linkedTripId,
    this.linkedTripStatus,
  });

  final String id;
  final String status;
  final num? agreedPrice;
  final String? paymentStatus;
  final String? buyerId;
  final String? sellerId;
  final String? linkedTripId;
  final String? linkedTripStatus;

  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get hasLinkedTrip => linkedTripId != null && linkedTripId!.isNotEmpty;

  static String? _refId(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return (v['_id'] ?? v['id'] ?? v[r'$oid'])?.toString();
    }
    return v.toString();
  }

  static MarketplaceBookingDetail? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = _refId(json['id'] ?? json['_id']);
    if (id == null || id.isEmpty) return null;

    String? tripId;
    String? tripStatus;
    final trip = json['tripId'] ?? json['linkedTrip'];
    if (trip is Map) {
      tripId = _refId(trip['id'] ?? trip['_id']);
      tripStatus = trip['status']?.toString();
    } else {
      tripId = _refId(trip);
    }

    return MarketplaceBookingDetail(
      id: id,
      status: (json['status'] ?? 'DRAFT').toString(),
      agreedPrice: json['agreedPrice'] is num
          ? json['agreedPrice'] as num
          : num.tryParse('${json['agreedPrice']}'),
      paymentStatus: json['paymentStatus']?.toString(),
      buyerId: _refId(json['buyerId']),
      sellerId: _refId(json['sellerId']),
      linkedTripId: tripId,
      linkedTripStatus: tripStatus,
    );
  }
}

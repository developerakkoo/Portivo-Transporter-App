/// A transporter's bid on a requirement. Mirrors quote.controller.serializeQuote.
class QuoteTransporter {
  const QuoteTransporter({
    this.id,
    this.name,
    this.company,
    this.rating,
    this.ratingCount = 0,
  });

  final String? id;
  final String? name;
  final String? company;
  final num? rating;
  final int ratingCount;

  String get displayName {
    if (company != null && company!.trim().isNotEmpty) return company!;
    if (name != null && name!.trim().isNotEmpty) return name!;
    return 'Transporter';
  }

  /// "New" when unrated, else formatted to one decimal.
  String get ratingLabel {
    if (rating == null || rating == 0) return 'New';
    return rating!.toStringAsFixed(1);
  }

  static QuoteTransporter fromJson(dynamic json) {
    if (json is! Map) return const QuoteTransporter();
    return QuoteTransporter(
      id: (json['id'] ?? json['_id'])?.toString(),
      name: json['name']?.toString(),
      company: json['company']?.toString(),
      rating: json['rating'] is num ? json['rating'] as num : null,
      ratingCount:
          json['ratingCount'] is num ? (json['ratingCount'] as num).toInt() : 0,
    );
  }
}

class QuoteModel {
  const QuoteModel({
    required this.id,
    required this.requirementId,
    required this.price,
    required this.availability,
    this.availabilityDate,
    this.message,
    required this.status,
    this.counterPrice,
    this.tripId,
    this.createdAt,
    this.respondedInMinutes,
    required this.transporter,
  });

  final String id;
  final String requirementId;
  final num price;
  final String availability; // TODAY | TOMORROW | CUSTOM
  final DateTime? availabilityDate;
  final String? message;
  final String status; // SUBMITTED | SELECTED | NOT_SELECTED | WITHDRAWN
  final num? counterPrice;
  final String? tripId;
  final DateTime? createdAt;
  final int? respondedInMinutes;
  final QuoteTransporter transporter;

  bool get isSelected => status == 'SELECTED';
  bool get isNotSelected => status == 'NOT_SELECTED';
  bool get isWithdrawn => status == 'WITHDRAWN';

  String get availabilityLabel {
    switch (availability) {
      case 'TODAY':
        return 'Available today';
      case 'TOMORROW':
        return 'Available tomorrow';
      case 'CUSTOM':
        if (availabilityDate != null) {
          final d = availabilityDate!;
          return 'Available ${d.day}/${d.month}/${d.year}';
        }
        return 'Custom date';
      default:
        return availability;
    }
  }

  static DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;

  static QuoteModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = (json['id'] ?? json['_id'])?.toString();
    if (id == null || id.isEmpty) return null;
    return QuoteModel(
      id: id,
      requirementId: (json['requirementId'] ?? '').toString(),
      price: json['price'] is num ? json['price'] as num : 0,
      availability: (json['availability'] ?? 'TODAY').toString(),
      availabilityDate: _date(json['availabilityDate']),
      message: json['message']?.toString(),
      status: (json['status'] ?? 'SUBMITTED').toString(),
      counterPrice: json['counterPrice'] is num ? json['counterPrice'] as num : null,
      tripId: json['tripId']?.toString(),
      createdAt: _date(json['createdAt']),
      respondedInMinutes: json['respondedInMinutes'] is num
          ? (json['respondedInMinutes'] as num).toInt()
          : null,
      transporter: QuoteTransporter.fromJson(json['transporter']),
    );
  }
}

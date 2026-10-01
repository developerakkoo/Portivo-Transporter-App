/// A transporter posted on the requester side; also the incoming inquiry a
/// transporter sees. Mirrors requirement.controller.serializeRequirement.
class RequirementRequester {
  const RequirementRequester({this.id, this.name, this.company, this.mobile});

  final String? id;
  final String? name;
  final String? company;
  final String? mobile;

  String get displayName {
    if (company != null && company!.trim().isNotEmpty) return company!;
    if (name != null && name!.trim().isNotEmpty) return name!;
    return 'Requester';
  }

  static RequirementRequester fromJson(dynamic json) {
    if (json is! Map) return const RequirementRequester();
    return RequirementRequester(
      id: (json['id'] ?? json['_id'])?.toString(),
      name: json['name']?.toString(),
      company: json['company']?.toString(),
      mobile: json['mobile']?.toString(),
    );
  }
}

class RequirementMyQuote {
  const RequirementMyQuote({this.id, this.price, this.status, this.availability});

  final String? id;
  final num? price;
  final String? status;
  final String? availability;

  static RequirementMyQuote? fromJson(dynamic json) {
    if (json is! Map) return null;
    return RequirementMyQuote(
      id: (json['id'] ?? json['_id'])?.toString(),
      price: json['price'] is num ? json['price'] as num : null,
      status: json['status']?.toString(),
      availability: json['availability']?.toString(),
    );
  }
}

class RequirementModel {
  const RequirementModel({
    required this.id,
    required this.ref,
    required this.origin,
    required this.destination,
    required this.vehicleType,
    required this.direction,
    required this.noOfVehicles,
    this.requiredBy,
    this.remarks,
    required this.status,
    this.awardedQuoteId,
    required this.requester,
    this.createdAt,
    this.quoteCount = 0,
    this.isOwner,
    this.myQuote,
    this.matchedCount,
  });

  final String id;
  final String ref;
  final String origin;
  final String destination;
  final String vehicleType;
  final String direction; // EXPORT | IMPORT | LOCAL
  final int noOfVehicles;
  final DateTime? requiredBy;
  final String? remarks;
  final String status; // OPEN | AWARDED | CANCELLED | EXPIRED | CLOSED
  final String? awardedQuoteId;
  final RequirementRequester requester;
  final DateTime? createdAt;
  final int quoteCount;
  final bool? isOwner;
  final RequirementMyQuote? myQuote;
  final int? matchedCount;

  bool get isOpen => status == 'OPEN';
  bool get isAwarded => status == 'AWARDED';

  static DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;

  static int _int(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static RequirementModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = (json['id'] ?? json['_id'])?.toString();
    if (id == null || id.isEmpty) return null;
    return RequirementModel(
      id: id,
      ref: (json['ref'] ?? '').toString(),
      origin: (json['origin'] ?? '').toString(),
      destination: (json['destination'] ?? '').toString(),
      vehicleType: (json['vehicleType'] ?? '').toString(),
      direction: (json['direction'] ?? 'EXPORT').toString(),
      noOfVehicles: _int(json['noOfVehicles'], 1),
      requiredBy: _date(json['requiredBy']),
      remarks: json['remarks']?.toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      awardedQuoteId: json['awardedQuoteId']?.toString(),
      requester: RequirementRequester.fromJson(json['requester']),
      createdAt: _date(json['createdAt']),
      quoteCount: _int(json['quoteCount']),
      isOwner: json['isOwner'] is bool ? json['isOwner'] as bool : null,
      myQuote: RequirementMyQuote.fromJson(json['myQuote']),
      matchedCount: json['matchedCount'] is num
          ? (json['matchedCount'] as num).toInt()
          : null,
    );
  }
}

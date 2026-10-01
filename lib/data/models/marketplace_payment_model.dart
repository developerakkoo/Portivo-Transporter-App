/// Marketplace trip payment status from GET .../razorpay/status.

class MarketplacePaymentEligibility {
  const MarketplacePaymentEligibility({
    this.marketplaceTrip = false,
    this.tripStarted = false,
    this.milestoneOneCompleted = false,
    this.paymentStatus,
    this.canInitiatePayment = false,
    this.recipientBeneficiaryReady,
    this.recipientBeneficiaryReason,
  });

  final bool marketplaceTrip;
  final bool tripStarted;
  final bool milestoneOneCompleted;
  final String? paymentStatus;
  final bool canInitiatePayment;
  final bool? recipientBeneficiaryReady;
  final String? recipientBeneficiaryReason;

  static MarketplacePaymentEligibility fromJson(dynamic json) {
    if (json is! Map) return const MarketplacePaymentEligibility();
    final m = Map<String, dynamic>.from(json);
    return MarketplacePaymentEligibility(
      marketplaceTrip: m['marketplaceTrip'] == true,
      tripStarted: m['tripStarted'] == true,
      milestoneOneCompleted: m['milestoneOneCompleted'] == true,
      paymentStatus: m['paymentStatus']?.toString(),
      canInitiatePayment: m['canInitiatePayment'] == true,
      recipientBeneficiaryReady: m.containsKey('recipientBeneficiaryReady')
          ? m['recipientBeneficiaryReady'] == true
          : null,
      recipientBeneficiaryReason: m['recipientBeneficiaryReason']?.toString(),
    );
  }
}

class MarketplacePaymentRecord {
  const MarketplacePaymentRecord({
    this.id,
    this.status,
    this.amount,
    this.currency = 'INR',
    this.provider,
    this.providerOrderId,
  });

  final String? id;
  final String? status;
  final num? amount;
  final String currency;
  final String? provider;
  final String? providerOrderId;

  bool get isSuccess => status?.toUpperCase() == 'SUCCESS';
  bool get isPending => status?.toUpperCase() == 'PENDING';
  bool get isProcessing => status?.toUpperCase() == 'PROCESSING';
  bool get isFailed =>
      status?.toUpperCase() == 'FAILED' || status?.toUpperCase() == 'CANCELLED';

  static MarketplacePaymentRecord? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return MarketplacePaymentRecord(
      id: (m['id'] ?? m['paymentId'] ?? m['publicId'])?.toString(),
      status: m['status']?.toString(),
      amount: m['amount'] is num ? m['amount'] as num : num.tryParse('${m['amount']}'),
      currency: m['currency']?.toString() ?? 'INR',
      provider: m['provider']?.toString(),
      providerOrderId: m['providerOrderId']?.toString(),
    );
  }
}

class MarketplacePayoutStatus {
  const MarketplacePayoutStatus({this.status});

  final String? status;

  static MarketplacePayoutStatus? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is! Map) return null;
    return MarketplacePayoutStatus(status: json['status']?.toString());
  }
}

class MarketplacePaymentTripInfo {
  const MarketplacePaymentTripInfo({
    this.id,
    this.tripId,
    this.status,
    this.tripType,
  });

  final String? id;
  final String? tripId;
  final String? status;
  final String? tripType;

  static MarketplacePaymentTripInfo? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return MarketplacePaymentTripInfo(
      id: (m['id'] ?? m['_id'])?.toString(),
      tripId: m['tripId']?.toString(),
      status: m['status']?.toString(),
      tripType: m['tripType']?.toString(),
    );
  }
}

class MarketplacePaymentBookingInfo {
  const MarketplacePaymentBookingInfo({
    this.id,
    this.status,
    this.agreedPrice,
    this.currency = 'INR',
    this.paymentStatus,
  });

  final String? id;
  final String? status;
  final num? agreedPrice;
  final String currency;
  final String? paymentStatus;

  static MarketplacePaymentBookingInfo? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return MarketplacePaymentBookingInfo(
      id: (m['id'] ?? m['_id'])?.toString(),
      status: m['status']?.toString(),
      agreedPrice: m['agreedPrice'] is num
          ? m['agreedPrice'] as num
          : num.tryParse('${m['agreedPrice']}'),
      currency: m['currency']?.toString() ?? 'INR',
      paymentStatus: m['paymentStatus']?.toString(),
    );
  }
}

class MarketplacePaymentStatusResponse {
  const MarketplacePaymentStatusResponse({
    this.trip,
    this.booking,
    this.payment,
    this.payout,
    this.eligibility = const MarketplacePaymentEligibility(),
  });

  final MarketplacePaymentTripInfo? trip;
  final MarketplacePaymentBookingInfo? booking;
  final MarketplacePaymentRecord? payment;
  final MarketplacePayoutStatus? payout;
  final MarketplacePaymentEligibility eligibility;

  static MarketplacePaymentStatusResponse? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return MarketplacePaymentStatusResponse(
      trip: MarketplacePaymentTripInfo.fromJson(m['trip']),
      booking: MarketplacePaymentBookingInfo.fromJson(m['booking']),
      payment: MarketplacePaymentRecord.fromJson(m['payment']),
      payout: MarketplacePayoutStatus.fromJson(m['payout']),
      eligibility: MarketplacePaymentEligibility.fromJson(m['eligibility']),
    );
  }
}

/// Razorpay checkout fields returned by POST .../razorpay/initiate.
class RazorpayCheckoutFields {
  const RazorpayCheckoutFields({
    required this.key,
    required this.orderId,
    required this.amount,
    this.currency = 'INR',
    this.name,
    this.description,
    this.prefillName,
    this.prefillEmail,
    this.prefillContact,
  });

  final String key;
  final String orderId;
  /// Gateway-ready smallest currency unit (paise). Do NOT multiply again.
  final int amount;
  final String currency;
  final String? name;
  final String? description;
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillContact;

  static RazorpayCheckoutFields? fromFieldsMap(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final key = m['key']?.toString();
    final orderId = (m['order_id'] ?? m['orderId'])?.toString();
    final amountRaw = m['amount'];
    int amount;
    if (amountRaw is num) {
      amount = amountRaw.toInt();
    } else {
      amount = int.tryParse('$amountRaw') ?? 0;
    }
    if (key == null || orderId == null || amount <= 0) return null;

    Map<String, dynamic>? prefill;
    if (m['prefill'] is Map) {
      prefill = Map<String, dynamic>.from(m['prefill'] as Map);
    }

    return RazorpayCheckoutFields(
      key: key,
      orderId: orderId,
      amount: amount,
      currency: m['currency']?.toString() ?? 'INR',
      name: m['name']?.toString(),
      description: m['description']?.toString(),
      prefillName: prefill?['name']?.toString(),
      prefillEmail: prefill?['email']?.toString(),
      prefillContact: prefill?['contact']?.toString(),
    );
  }
}

class RazorpayInitiateResponse {
  const RazorpayInitiateResponse({
    this.payment,
    this.fields,
  });

  final MarketplacePaymentRecord? payment;
  final RazorpayCheckoutFields? fields;

  static RazorpayInitiateResponse? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final paymentRaw = m['payment'];
    Map<String, dynamic>? paymentMap;
    if (paymentRaw is Map) {
      paymentMap = Map<String, dynamic>.from(paymentRaw);
    }
    final fieldsRaw = paymentMap?['fields'] ?? m['fields'];
    return RazorpayInitiateResponse(
      payment: MarketplacePaymentRecord.fromJson(paymentRaw),
      fields: RazorpayCheckoutFields.fromFieldsMap(fieldsRaw),
    );
  }
}

/// Derived UI state for payment cards (doc section 20).
enum MarketplacePaymentUiState {
  notReady,
  payNow,
  processing,
  paid,
  retry,
}

extension MarketplacePaymentStatusResponseUi on MarketplacePaymentStatusResponse {
  bool get waitingForBank =>
      eligibility.canInitiatePayment != true &&
      eligibility.milestoneOneCompleted &&
      eligibility.tripStarted &&
      eligibility.recipientBeneficiaryReady == false;

  MarketplacePaymentUiState get uiState {
    final payStatus = payment?.status?.toUpperCase();
    if (payStatus == 'SUCCESS') return MarketplacePaymentUiState.paid;

    // PROCESSING = Razorpay checkout submitted, awaiting webhook confirmation.
    if (payStatus == 'PROCESSING') {
      return MarketplacePaymentUiState.processing;
    }

    if (payStatus == 'FAILED' || payStatus == 'CANCELLED') {
      if (eligibility.canInitiatePayment) return MarketplacePaymentUiState.retry;
      return MarketplacePaymentUiState.notReady;
    }

    if (eligibility.canInitiatePayment) return MarketplacePaymentUiState.payNow;
    return MarketplacePaymentUiState.notReady;
  }

  bool get hasExistingPaymentOrder {
    final s = payment?.status?.toUpperCase();
    return s == 'PENDING' || s == 'CREATED' || s == 'PROCESSING';
  }

  String buyerSummaryLine() {
    switch (uiState) {
      case MarketplacePaymentUiState.paid:
        return 'Payment Completed';
      case MarketplacePaymentUiState.processing:
        return 'Payment pending';
      case MarketplacePaymentUiState.retry:
        return 'Previous payment did not complete';
      case MarketplacePaymentUiState.payNow:
        return hasExistingPaymentOrder ? 'Payment pending' : 'Payment required';
      case MarketplacePaymentUiState.notReady:
        return waitingForBank
            ? 'Waiting for seller bank setup'
            : 'Payment unlocks after first milestone';
    }
  }

  /// Null when the buyer should not see a Pay CTA.
  String? buyerCtaLabel() {
    switch (uiState) {
      case MarketplacePaymentUiState.retry:
        return 'Retry';
      case MarketplacePaymentUiState.payNow:
        return hasExistingPaymentOrder ? 'Pay Now' : 'Make Payment';
      case MarketplacePaymentUiState.notReady:
      case MarketplacePaymentUiState.processing:
      case MarketplacePaymentUiState.paid:
        return null;
    }
  }
}

String marketplacePaymentSummary(
  MarketplacePaymentUiState ui, {
  bool waitingForBank = false,
}) {
  switch (ui) {
    case MarketplacePaymentUiState.paid:
      return 'Payment Completed';
    case MarketplacePaymentUiState.processing:
      return 'Payment pending';
    case MarketplacePaymentUiState.retry:
      return 'Previous payment did not complete';
    case MarketplacePaymentUiState.payNow:
      return 'Payment required';
    case MarketplacePaymentUiState.notReady:
      return waitingForBank
          ? 'Waiting for seller bank setup'
          : 'Payment unlocks after first milestone';
  }
}

String marketplacePayoutSummary(String? status) {
  switch (status?.toUpperCase()) {
    case 'COMPLETED':
    case 'SUCCESS':
      return 'Payout sent to your bank account';
    case 'PROCESSING':
    case 'PENDING':
      return 'Payout processing';
    case 'FAILED':
      return 'Payout failed — contact support';
    default:
      return 'Payout pending buyer payment';
  }
}

/// Row from GET /marketplace-payments (payer or beneficiary of the logged-in transporter).
class MarketplacePaymentListItem {
  const MarketplacePaymentListItem({
    this.id,
    this.tripId,
    this.bookingId,
    this.amount = 0,
    this.status,
    this.currency = 'INR',
    this.role,
    this.provider,
    this.providerOrderId,
    this.providerTransactionId,
    this.createdAt,
    this.completedAt,
    this.initiatedAt,
  });

  final String? id;
  final String? tripId;
  final String? bookingId;
  final double amount;
  final String? status;
  final String currency;
  final String? role;
  final String? provider;
  final String? providerOrderId;
  final String? providerTransactionId;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final DateTime? initiatedAt;

  bool get isPayer => role?.toLowerCase() == 'payer';

  String get roleLabel => isPayer ? 'Payer' : 'Beneficiary';

  DateTime? get displayDate => completedAt ?? createdAt ?? initiatedAt;

  static MarketplacePaymentListItem fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return MarketplacePaymentListItem(
      id: (json['id'] ?? json['paymentId'] ?? json['publicId'])?.toString(),
      tripId: (json['tripId'] ??
              (json['trip'] is Map ? json['trip']['id'] : null))
          ?.toString(),
      bookingId: (json['bookingId'] ??
              (json['booking'] is Map ? json['booking']['id'] : null))
          ?.toString(),
      amount: json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse('${json['amount']}') ?? 0,
      status: json['status']?.toString(),
      currency: json['currency']?.toString() ?? 'INR',
      role: json['role']?.toString(),
      provider: json['provider']?.toString(),
      providerOrderId: json['providerOrderId']?.toString(),
      providerTransactionId: json['providerTransactionId']?.toString(),
      createdAt: parseDate(json['createdAt']),
      completedAt: parseDate(json['completedAt']),
      initiatedAt: parseDate(json['initiatedAt']),
    );
  }
}

class MarketplacePaymentListResult {
  const MarketplacePaymentListResult({
    this.payments = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.hasNext = false,
    this.hasPrevious = false,
  });

  final List<MarketplacePaymentListItem> payments;
  final int page;
  final int limit;
  final int total;
  final bool hasNext;
  final bool hasPrevious;

  static MarketplacePaymentListResult fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : <String, dynamic>{};
    final raw = json['payments'];
    final payments = raw is List
        ? raw
            .whereType<Map>()
            .map((row) => MarketplacePaymentListItem.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList()
        : const <MarketplacePaymentListItem>[];
    final page = pagination['page'] is num
        ? (pagination['page'] as num).toInt()
        : int.tryParse('${pagination['page']}') ?? 1;
    final limit = pagination['limit'] is num
        ? (pagination['limit'] as num).toInt()
        : int.tryParse('${pagination['limit']}') ?? 20;
    final total = pagination['total'] is num
        ? (pagination['total'] as num).toInt()
        : int.tryParse('${pagination['total']}') ?? payments.length;
    return MarketplacePaymentListResult(
      payments: payments,
      page: page,
      limit: limit,
      total: total,
      hasNext: pagination['hasNext'] == true,
      hasPrevious: pagination['hasPrevious'] == true,
    );
  }
}

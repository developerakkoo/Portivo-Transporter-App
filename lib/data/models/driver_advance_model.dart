/// Driver advance payment list + Razorpay checkout models.

class TripAdvanceTripInfo {
  const TripAdvanceTripInfo({
    required this.id,
    this.tripref,
    this.type,
    this.status,
    this.createdAt,
  });

  final String id;
  final String? tripref;
  final String? type;
  final String? status;
  final DateTime? createdAt;

  static TripAdvanceTripInfo? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final id = (m['id'] ?? m['_id'])?.toString();
    if (id == null || id.isEmpty) return null;
    return TripAdvanceTripInfo(
      id: id,
      tripref: (m['tripref'] ?? m['tripId'])?.toString(),
      type: m['type']?.toString(),
      status: m['status']?.toString(),
      createdAt: m['createdAt'] != null
          ? DateTime.tryParse(m['createdAt'].toString())
          : null,
    );
  }
}

class TripAdvancePartyInfo {
  const TripAdvancePartyInfo({this.name, this.mobile, this.company});

  final String? name;
  final String? mobile;
  final String? company;

  static TripAdvancePartyInfo? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return TripAdvancePartyInfo(
      name: m['name']?.toString(),
      mobile: m['mobile']?.toString(),
      company: m['company']?.toString(),
    );
  }
}

class TripAdvancePaymentInfo {
  const TripAdvancePaymentInfo({this.status, this.paidAt});

  final String? status;
  final DateTime? paidAt;

  static TripAdvancePaymentInfo fromJson(dynamic json) {
    if (json is! Map) return const TripAdvancePaymentInfo();
    final m = Map<String, dynamic>.from(json);
    return TripAdvancePaymentInfo(
      status: m['status']?.toString(),
      paidAt: m['paidAt'] != null
          ? DateTime.tryParse(m['paidAt'].toString())
          : null,
    );
  }
}

class TripAdvancePayoutInfo {
  const TripAdvancePayoutInfo({this.status, this.paidAt});

  final String? status;
  final DateTime? paidAt;

  static TripAdvancePayoutInfo fromJson(dynamic json) {
    if (json is! Map) return const TripAdvancePayoutInfo();
    final m = Map<String, dynamic>.from(json);
    return TripAdvancePayoutInfo(
      status: m['status']?.toString(),
      paidAt: m['paidAt'] != null
          ? DateTime.tryParse(m['paidAt'].toString())
          : null,
    );
  }
}

class TripAdvanceInfo {
  const TripAdvanceInfo({
    this.amount = 0,
    this.currency = 'INR',
    this.status,
    this.payment = const TripAdvancePaymentInfo(),
    this.payout = const TripAdvancePayoutInfo(),
  });

  final num amount;
  final String currency;
  final String? status;
  final TripAdvancePaymentInfo payment;
  final TripAdvancePayoutInfo payout;

  static TripAdvanceInfo fromJson(dynamic json) {
    if (json is! Map) return const TripAdvanceInfo();
    final m = Map<String, dynamic>.from(json);
    return TripAdvanceInfo(
      amount: m['amount'] is num ? m['amount'] as num : num.tryParse('${m['amount']}') ?? 0,
      currency: m['currency']?.toString() ?? 'INR',
      status: m['status']?.toString(),
      payment: TripAdvancePaymentInfo.fromJson(m['payment']),
      payout: TripAdvancePayoutInfo.fromJson(m['payout']),
    );
  }
}

class TripAdvanceListItem {
  const TripAdvanceListItem({
    required this.trip,
    this.driver,
    this.transporter,
    required this.advance,
  });

  final TripAdvanceTripInfo trip;
  final TripAdvancePartyInfo? driver;
  final TripAdvancePartyInfo? transporter;
  final TripAdvanceInfo advance;

  static TripAdvanceListItem? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final trip = TripAdvanceTripInfo.fromJson(m['trip']);
    if (trip == null) return null;
    return TripAdvanceListItem(
      trip: trip,
      driver: TripAdvancePartyInfo.fromJson(m['driver']),
      transporter: TripAdvancePartyInfo.fromJson(m['transporter']),
      advance: TripAdvanceInfo.fromJson(m['advance']),
    );
  }
}

class TripAdvanceListResult {
  const TripAdvanceListResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  final List<TripAdvanceListItem> items;
  final int page;
  final int limit;
  final int total;
  final int pages;
}

class DriverAdvanceRazorpayFields {
  const DriverAdvanceRazorpayFields({
    required this.keyId,
    required this.orderId,
    required this.amount,
    this.currency = 'INR',
  });

  final String keyId;
  final String orderId;
  /// Gateway-ready smallest currency unit (paise). Do NOT multiply again.
  final int amount;
  final String currency;

  static DriverAdvanceRazorpayFields? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final keyId = (m['keyId'] ?? m['key'])?.toString();
    final orderId = (m['orderId'] ?? m['order_id'])?.toString();
    final amountRaw = m['amount'];
    int amount;
    if (amountRaw is num) {
      amount = amountRaw.toInt();
    } else {
      amount = int.tryParse('$amountRaw') ?? 0;
    }
    if (keyId == null || orderId == null || amount <= 0) return null;
    return DriverAdvanceRazorpayFields(
      keyId: keyId,
      orderId: orderId,
      amount: amount,
      currency: m['currency']?.toString() ?? 'INR',
    );
  }
}

class DriverAdvanceInitiateResponse {
  const DriverAdvanceInitiateResponse({
    this.paymentSessionId,
    this.alreadyPaid = false,
    this.razorpay,
  });

  final String? paymentSessionId;
  final bool alreadyPaid;
  final DriverAdvanceRazorpayFields? razorpay;

  static DriverAdvanceInitiateResponse? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    var razorpay = DriverAdvanceRazorpayFields.fromJson(m['razorpay']);
    if (razorpay == null) {
      final paymentRequest = m['paymentRequest'];
      if (paymentRequest is Map) {
        final pr = Map<String, dynamic>.from(paymentRequest);
        razorpay = DriverAdvanceRazorpayFields.fromJson(pr['fields']);
      }
    }
    return DriverAdvanceInitiateResponse(
      paymentSessionId: m['paymentSessionId']?.toString(),
      alreadyPaid: m['alreadyPaid'] == true,
      razorpay: razorpay,
    );
  }
}

enum DriverAdvanceUiState {
  noAdvance,
  notPaid,
  processing,
  paid,
  failed,
}

extension TripAdvanceListItemUi on TripAdvanceListItem {
  DriverAdvanceUiState get uiState {
    switch (advance.status?.toUpperCase()) {
      case 'NO_ADVANCE':
        return DriverAdvanceUiState.noAdvance;
      case 'NOT_PAID':
        return DriverAdvanceUiState.notPaid;
      case 'PAID':
        return DriverAdvanceUiState.paid;
      case 'PAYMENT_FAILED':
      case 'PAYOUT_FAILED':
        return DriverAdvanceUiState.failed;
      // Order created but checkout was not completed. Payable again.
      case 'PAYMENT_PENDING':
        return DriverAdvanceUiState.notPaid;
      case 'PAYOUT_PENDING':
      case 'PAYOUT_PROCESSING':
      case 'PAYOUT_RETRY_PENDING':
        return DriverAdvanceUiState.processing;
      default:
        return DriverAdvanceUiState.notPaid;
    }
  }

  bool get canPayAdvance => uiState == DriverAdvanceUiState.notPaid ||
      uiState == DriverAdvanceUiState.failed;
}

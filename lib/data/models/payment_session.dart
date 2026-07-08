import '../../core/utils/json_parser.dart';

/// The gateway checkout request returned by the backend: where to POST and
/// which fields to submit (PayU: key, txnid, hash, surl, furl, udf1..5, ...).
class PaymentRequest {
  final String actionUrl;
  final String method;
  final String? provider;
  final String? mode;
  final Map<String, String> fields;

  PaymentRequest({
    required this.actionUrl,
    required this.method,
    this.provider,
    this.mode,
    required this.fields,
  });

  bool get isValid => actionUrl.isNotEmpty && fields.isNotEmpty;

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    final rawFields = (json['fields'] is Map) ? json['fields'] as Map : const {};
    final fields = <String, String>{};
    rawFields.forEach((key, value) {
      fields[key.toString()] = value?.toString() ?? '';
    });

    return PaymentRequest(
      actionUrl: JsonParser.extractString(json['actionUrl'], ''),
      method: JsonParser.extractString(json['method'], 'POST').toUpperCase(),
      provider: json['provider']?.toString(),
      mode: json['mode']?.toString(),
      fields: fields,
    );
  }
}

/// A payment session (`data.payment`) from `/api/payments/sessions`.
/// `status` is the authoritative source of truth for completion.
class PaymentSession {
  static const String statusCreated = 'CREATED';
  static const String statusPending = 'PENDING';
  static const String statusSuccess = 'SUCCESS';
  static const String statusFailed = 'FAILED';
  static const String statusCancelled = 'CANCELLED';
  static const String statusRefunded = 'REFUNDED';

  final String id;
  final String status;
  final String? provider;
  final double amount;
  final String currency;
  final String? merchantTransactionId;
  final String? failureReason;
  final PaymentRequest? paymentRequest;

  PaymentSession({
    required this.id,
    required this.status,
    this.provider,
    required this.amount,
    required this.currency,
    this.merchantTransactionId,
    this.failureReason,
    this.paymentRequest,
  });

  bool get isSuccess => status == statusSuccess;
  bool get isFailed => status == statusFailed || status == statusCancelled;
  bool get isRefunded => status == statusRefunded;

  /// A terminal status is one that no longer changes; stop polling once reached.
  bool get isTerminal => const {
        statusSuccess,
        statusFailed,
        statusCancelled,
        statusRefunded,
      }.contains(status);

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    final requestJson = json['paymentRequest'];
    return PaymentSession(
      id: JsonParser.extractString(json['id'] ?? json['_id'], ''),
      status: JsonParser.extractString(json['status'], statusPending).toUpperCase(),
      provider: json['provider']?.toString(),
      amount: JsonParser.extractDouble(json['amount'], 0),
      currency: JsonParser.extractString(json['currency'], 'INR'),
      merchantTransactionId: json['merchantTransactionId']?.toString(),
      failureReason: json['failureReason']?.toString(),
      paymentRequest: (requestJson is Map)
          ? PaymentRequest.fromJson(Map<String, dynamic>.from(requestJson))
          : null,
    );
  }
}

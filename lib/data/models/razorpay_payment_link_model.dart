import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

String formatInrAmount(num amount) => _inr.format(amount);

/// Created Payment Link. [id] is the Porttivo Mongo record id used for GET/cancel.
class RazorpayPaymentLinkCreated {
  const RazorpayPaymentLinkCreated({
    required this.id,
    this.publicId,
    this.paymentLinkId,
    this.shortUrl,
    this.paymentSessionId,
    required this.amount,
    this.currency = 'INR',
    this.status = 'CREATED',
  });

  final String id;
  final String? publicId;
  final String? paymentLinkId;
  final String? shortUrl;
  final String? paymentSessionId;
  final num amount;
  final String currency;
  final String status;

  static RazorpayPaymentLinkCreated? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final id = (m['id'] ?? m['_id'])?.toString();
    if (id == null || id.isEmpty) return null;
    return RazorpayPaymentLinkCreated(
      id: id,
      publicId: m['publicId']?.toString(),
      paymentLinkId: m['paymentLinkId']?.toString(),
      shortUrl: m['shortUrl']?.toString(),
      paymentSessionId: m['paymentSessionId']?.toString(),
      amount: m['amount'] is num ? m['amount'] as num : num.tryParse('${m['amount']}') ?? 0,
      currency: m['currency']?.toString() ?? 'INR',
      status: m['status']?.toString() ?? 'CREATED',
    );
  }
}

/// Status from GET /razorpay-payment-links/:mongoId.
/// [publicId] is `data.id` from the status payload (`rpl_...`), not the path id.
class RazorpayPaymentLinkStatus {
  const RazorpayPaymentLinkStatus({
    this.publicId,
    this.paymentLinkId,
    this.shortUrl,
    required this.amount,
    this.currency = 'INR',
    this.status = 'CREATED',
    this.razorpayPaymentId,
    this.transferStatus,
    this.transferredAmount = 0,
    this.razorpayTransferId,
  });

  final String? publicId;
  final String? paymentLinkId;
  final String? shortUrl;
  final num amount;
  final String currency;
  final String status;
  final String? razorpayPaymentId;
  final String? transferStatus;
  final num transferredAmount;
  final String? razorpayTransferId;

  String get normalizedStatus => status.trim().toUpperCase();
  String get normalizedTransfer => (transferStatus ?? '').trim().toUpperCase();

  bool get isCreated => normalizedStatus == 'CREATED';
  bool get isPaid => normalizedStatus == 'PAID';
  bool get isCancelled =>
      normalizedStatus == 'CANCELLED' ||
      normalizedStatus == 'EXPIRED' ||
      normalizedStatus == 'FAILED';
  bool get isPayoutProcessed => normalizedTransfer == 'PROCESSED';
  bool get isPayoutFailed =>
      normalizedTransfer == 'FAILED' || normalizedTransfer == 'REVERSED';
  bool get isPayoutPending =>
      isPaid && !isPayoutProcessed && !isPayoutFailed;

  bool get shouldKeepPolling =>
      isCreated || (isPaid && !isPayoutProcessed && !isPayoutFailed);

  static RazorpayPaymentLinkStatus? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return RazorpayPaymentLinkStatus(
      publicId: m['id']?.toString(),
      paymentLinkId: m['paymentLinkId']?.toString(),
      shortUrl: m['shortUrl']?.toString(),
      amount: m['amount'] is num ? m['amount'] as num : num.tryParse('${m['amount']}') ?? 0,
      currency: m['currency']?.toString() ?? 'INR',
      status: m['status']?.toString() ?? 'CREATED',
      razorpayPaymentId: m['razorpayPaymentId']?.toString(),
      transferStatus: m['transferStatus']?.toString(),
      transferredAmount: m['transferredAmount'] is num
          ? m['transferredAmount'] as num
          : num.tryParse('${m['transferredAmount']}') ?? 0,
      razorpayTransferId: m['razorpayTransferId']?.toString(),
    );
  }
}

/// Parseable TEXT body posted into marketplace/quote chat after create.
class ExtraChargePaymentRequest {
  const ExtraChargePaymentRequest({
    required this.recordId,
    required this.shortUrl,
    required this.amount,
    required this.description,
  });

  final String recordId;
  final String shortUrl;
  final num amount;
  final String description;

  static final RegExp _recordRe = RegExp(r'rplRecord:([A-Za-z0-9]+)');
  static final RegExp _urlRe = RegExp(r'https?://rzp\.io/\S+');
  static final RegExp _amountRe = RegExp(r'₹\s*([\d,]+(?:\.\d+)?)');

  static bool looksLike(String content) {
    final c = content.trim();
    return c.contains('rplRecord:') || c.contains('rzp.io');
  }

  static ExtraChargePaymentRequest? tryParse(String content) {
    final record = _recordRe.firstMatch(content)?.group(1);
    final url = _urlRe.firstMatch(content)?.group(0);
    if (record == null || record.isEmpty || url == null || url.isEmpty) {
      return null;
    }
    final rawAmount = _amountRe.firstMatch(content)?.group(1)?.replaceAll(',', '');
    final amount = num.tryParse(rawAmount ?? '') ?? 0;
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !l.startsWith('rplRecord:'))
        .where((l) => !l.contains('rzp.io'))
        .toList();
    String description = 'Extra charges';
    if (lines.length >= 2) {
      description = lines[1];
    } else if (lines.isNotEmpty && !lines.first.toLowerCase().startsWith('extra charges')) {
      description = lines.first;
    }
    return ExtraChargePaymentRequest(
      recordId: record,
      shortUrl: url.replaceAll(RegExp(r'[.,);]+$'), ''),
      amount: amount,
      description: description,
    );
  }

  static String encode({
    required num amount,
    required String description,
    required String shortUrl,
    required String recordId,
  }) {
    final desc = description.trim().isEmpty ? 'Extra charges' : description.trim();
    return 'Extra charges · ₹${formatInrAmount(amount)}\n$desc\n$shortUrl\nrplRecord:$recordId';
  }

  static String inboxPreview(String content) {
    final parsed = tryParse(content);
    if (parsed != null && parsed.amount > 0) {
      return 'Extra charges · ₹${formatInrAmount(parsed.amount)}';
    }
    if (looksLike(content)) return 'Extra charges';
    return content.trim();
  }
}

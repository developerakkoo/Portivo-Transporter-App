class TransporterPaymentPayout {
  final String? id;
  final String? status;
  final String? transferId;

  const TransporterPaymentPayout({
    this.id,
    this.status,
    this.transferId,
  });

  factory TransporterPaymentPayout.fromJson(Map<String, dynamic> json) {
    return TransporterPaymentPayout(
      id: json['id']?.toString(),
      status: json['status']?.toString(),
      transferId: json['transferId']?.toString(),
    );
  }
}

class TransporterPaymentHistoryItem {
  final String paymentId;
  final String? referenceId;
  final String? purpose;
  final String? providerTransactionId;
  final String? provider;
  final double amount;
  final String paymentStatus;
  final DateTime? paymentDate;
  final String payoutStatus;
  final TransporterPaymentPayout? payout;

  const TransporterPaymentHistoryItem({
    required this.paymentId,
    this.referenceId,
    this.purpose,
    this.providerTransactionId,
    this.provider,
    required this.amount,
    required this.paymentStatus,
    this.paymentDate,
    required this.payoutStatus,
    this.payout,
  });

  factory TransporterPaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final payoutJson = json['payout'];
    return TransporterPaymentHistoryItem(
      paymentId: json['paymentId']?.toString() ?? '',
      referenceId: json['referenceId']?.toString(),
      purpose: json['purpose']?.toString(),
      providerTransactionId: json['providerTransactionId']?.toString(),
      provider: json['provider']?.toString(),
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse('${json['amount']}') ?? 0,
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      paymentDate: parseDate(json['paymentDate']),
      payoutStatus: json['payoutStatus']?.toString() ?? 'NOT_CREATED',
      payout: payoutJson is Map<String, dynamic>
          ? TransporterPaymentPayout.fromJson(payoutJson)
          : null,
    );
  }

  bool get isDriverAdvance =>
      (purpose ?? '').toUpperCase() == 'DRIVER_ADVANCE';

  String get purposeLabel {
    switch ((purpose ?? '').toUpperCase()) {
      case 'DRIVER_ADVANCE':
        return 'Driver Advance';
      default:
        if (purpose == null || purpose!.isEmpty) return 'Payment';
        return purpose!
            .replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }
}

class TransporterPaymentHistoryResult {
  final List<TransporterPaymentHistoryItem> payments;
  final int page;
  final int limit;
  final int total;
  final int count;
  final bool hasNext;
  final bool hasPrevious;

  const TransporterPaymentHistoryResult({
    required this.payments,
    required this.page,
    required this.limit,
    required this.total,
    required this.count,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory TransporterPaymentHistoryResult.fromJson(Map<String, dynamic> json) {
    final raw = json['payments'];
    final payments = <TransporterPaymentHistoryItem>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          payments.add(TransporterPaymentHistoryItem.fromJson(item));
        } else if (item is Map) {
          payments.add(
            TransporterPaymentHistoryItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    int asInt(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? fallback;
    }

    return TransporterPaymentHistoryResult(
      payments: payments,
      page: asInt(json['page'], 1),
      limit: asInt(json['limit'], 20),
      total: asInt(json['total'], payments.length),
      count: asInt(json['count'], payments.length),
      hasNext: json['hasNext'] == true,
      hasPrevious: json['hasPrevious'] == true,
    );
  }
}

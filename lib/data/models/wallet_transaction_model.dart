class WalletTransactionModel {
  final String id;
  final String walletId;
  final String type; // 'CREDIT', 'DEBIT', 'TRANSFER'
  final double amount;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? reference;
  final String? referenceType;
  final String status;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    this.balanceBefore,
    this.balanceAfter,
    this.reference,
    this.referenceType,
    required this.status,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      walletId: json['walletId']?.toString() ?? '',
      type: json['type'] ?? 'CREDIT',
      amount: (json['amount'] ?? 0).toDouble(),
      balanceBefore: json['balanceBefore'] != null ? (json['balanceBefore'] as num).toDouble() : null,
      balanceAfter: json['balanceAfter'] != null ? (json['balanceAfter'] as num).toDouble() : null,
      reference: json['reference']?.toString(),
      referenceType: json['referenceType']?.toString(),
      status: json['status'] ?? 'COMPLETED',
      description: json['description'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'reference': reference,
      'description': description,
    };
  }

  bool get isCredit => type.toUpperCase() == 'CREDIT';
  bool get isDebit => type.toUpperCase() == 'DEBIT' || type.toUpperCase() == 'TRANSFER';
}

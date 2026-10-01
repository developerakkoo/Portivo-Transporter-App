import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/transporter_payment_history_model.dart';
import '../../providers/transporter_payment_history_provider.dart';

class PaymentHistoryList extends StatefulWidget {
  const PaymentHistoryList({super.key});

  @override
  State<PaymentHistoryList> createState() => _PaymentHistoryListState();
}

class _PaymentHistoryListState extends State<PaymentHistoryList> {
  final _scrollController = ScrollController();
  static final NumberFormat _inrFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransporterPaymentHistoryProvider>().loadHistory(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<TransporterPaymentHistoryProvider>().loadMore();
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return AppColors.success;
      case 'FAILED':
      case 'CANCELLED':
        return AppColors.error;
      case 'PENDING':
      case 'CREATED':
      case 'PROCESSING':
        return AppColors.warning;
      case 'REFUNDED':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    final raw = status.trim();
    if (raw.isEmpty || raw.toUpperCase() == 'NOT_CREATED') return 'Not created';
    return raw
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showDetails(TransporterPaymentHistoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dividerGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.purposeLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _inrFmt.format(item.amount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('Payment ID', item.paymentId),
                if (item.referenceId != null && item.referenceId!.isNotEmpty)
                  _detailRow('Reference', item.referenceId!),
                _detailRow('Provider', item.provider ?? '—'),
                if (item.providerTransactionId != null &&
                    item.providerTransactionId!.isNotEmpty)
                  _detailRow('Transaction ID', item.providerTransactionId!),
                _detailRow('Payment', _statusLabel(item.paymentStatus)),
                _detailRow('Payout', _statusLabel(item.payoutStatus)),
                if (item.payout?.transferId != null)
                  _detailRow('Transfer ID', item.payout!.transferId!),
                if (item.paymentDate != null)
                  _detailRow(
                    'Date',
                    _dateFmt.format(item.paymentDate!.toLocal()),
                  ),
                if (item.isDriverAdvance &&
                    item.referenceId != null &&
                    item.referenceId!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).pushNamed(
                        '/trip-detail',
                        arguments: item.referenceId,
                      );
                    },
                    child: const Text('Open trip'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransporterPaymentHistoryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.payments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null && provider.payments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => provider.loadHistory(refresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (provider.payments.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.loadHistory(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No payments yet')),
              ],
            ),
          );
        }

        final extra = provider.isLoadingMore ? 1 : 0;
        return RefreshIndicator(
          onRefresh: () => provider.loadHistory(refresh: true),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: provider.payments.length + extra,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= provider.payments.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final item = provider.payments[index];
              final txn = item.providerTransactionId;
              return InkWell(
                onTap: () => _showDetails(item),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.purposeLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            _inrFmt.format(item.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(
                            _statusLabel(item.paymentStatus),
                            _statusColor(item.paymentStatus),
                          ),
                          _chip(
                            'Payout: ${_statusLabel(item.payoutStatus)}',
                            _statusColor(item.payoutStatus),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (item.paymentDate != null)
                        Text(
                          _dateFmt.format(item.paymentDate!.toLocal()),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      if (item.provider != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          txn != null && txn.isNotEmpty
                              ? '${item.provider} · ${txn.length > 16 ? '${txn.substring(0, 16)}…' : txn}'
                              : item.provider!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

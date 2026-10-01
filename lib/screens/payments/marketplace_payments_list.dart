import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/marketplace_payment_model.dart';
import '../../providers/marketplace_payments_list_provider.dart';

class MarketplacePaymentsList extends StatefulWidget {
  const MarketplacePaymentsList({super.key});

  @override
  State<MarketplacePaymentsList> createState() =>
      _MarketplacePaymentsListState();
}

class _MarketplacePaymentsListState extends State<MarketplacePaymentsList> {
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
      context.read<MarketplacePaymentsListProvider>().loadPayments(refresh: true);
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
      context.read<MarketplacePaymentsListProvider>().loadMore();
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
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

  String _statusLabel(String? status) {
    final raw = (status ?? '').trim();
    if (raw.isEmpty) return 'Unknown';
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

  void _openTrip(MarketplacePaymentListItem item) {
    final tripId = item.tripId;
    if (tripId == null || tripId.isEmpty) return;
    Navigator.of(context).pushNamed('/trip-detail', arguments: tripId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplacePaymentsListProvider>(
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
                    onPressed: () => provider.loadPayments(refresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (provider.payments.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.loadPayments(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No marketplace payments yet')),
              ],
            ),
          );
        }

        final extra = provider.isLoadingMore ? 1 : 0;
        return RefreshIndicator(
          onRefresh: () => provider.loadPayments(refresh: true),
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
              final date = item.displayDate;
              final canOpenTrip = item.tripId != null && item.tripId!.isNotEmpty;
              return InkWell(
                onTap: canOpenTrip ? () => _openTrip(item) : null,
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
                          const Expanded(
                            child: Text(
                              'Marketplace payment',
                              style: TextStyle(
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
                            _statusLabel(item.status),
                            _statusColor(item.status),
                          ),
                          _chip(
                            item.roleLabel,
                            AppColors.info,
                          ),
                        ],
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _dateFmt.format(date.toLocal()),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/driver_advance_model.dart';
import '../../providers/driver_advance_payment_provider.dart';
import 'driver_advance_detail_screen.dart';
import 'driver_advance_razorpay_checkout_screen.dart';

/// Trip-centric driver advance list with Pay Advance (Razorpay).
class DriverAdvancesList extends StatefulWidget {
  const DriverAdvancesList({super.key});

  @override
  State<DriverAdvancesList> createState() => _DriverAdvancesListState();
}

class _DriverAdvancesListState extends State<DriverAdvancesList> {
  final _payingTripIds = <String>{};
  static final NumberFormat _inrFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverAdvancePaymentProvider>().loadPayments();
    });
  }

  Future<void> _payAdvance(TripAdvanceListItem item) async {
    final tripId = item.trip.id;
    if (_payingTripIds.contains(tripId)) return;
    setState(() => _payingTripIds.add(tripId));
    final provider = context.read<DriverAdvancePaymentProvider>();
    try {
      final initiate = await provider.initiatePayment(tripId);
      if (initiate.alreadyPaid) {
        if (mounted) {
          showUserSuccessSnackBar(context, 'Advance already paid');
          await provider.loadPayments(refresh: true);
        }
        return;
      }
      final fields = initiate.razorpay;
      if (fields == null || !mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => DriverAdvanceRazorpayCheckoutScreen(
            tripId: tripId,
            fields: fields,
          ),
        ),
      );
      if (paid == true && mounted) {
        showUserSuccessSnackBar(context, 'Advance payment successful');
      }
      if (mounted) await provider.loadPayments(refresh: true);
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _payingTripIds.remove(tripId));
    }
  }

  String _statusLabel(DriverAdvanceUiState ui) {
    switch (ui) {
      case DriverAdvanceUiState.noAdvance:
        return 'No advance';
      case DriverAdvanceUiState.notPaid:
        return 'Not paid';
      case DriverAdvanceUiState.processing:
        return 'Processing';
      case DriverAdvanceUiState.paid:
        return 'Paid';
      case DriverAdvanceUiState.failed:
        return 'Failed';
    }
  }

  Color _statusColor(DriverAdvanceUiState ui) {
    switch (ui) {
      case DriverAdvanceUiState.paid:
        return AppColors.success;
      case DriverAdvanceUiState.failed:
        return AppColors.error;
      case DriverAdvanceUiState.processing:
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverAdvancePaymentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null && provider.items.isEmpty) {
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
        final items = provider.items
            .where((e) => e.uiState != DriverAdvanceUiState.noAdvance)
            .toList();
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.loadPayments(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No trips with driver advance configured')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => provider.loadPayments(refresh: true),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final ui = item.uiState;
              final paying = _payingTripIds.contains(item.trip.id);
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DriverAdvanceDetailScreen(item: item),
                    ),
                  );
                },
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
                            item.trip.tripref ?? item.trip.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(ui).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(ui),
                            style: TextStyle(
                              color: _statusColor(ui),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (item.driver?.name != null)
                      Text(
                        'Driver: ${item.driver!.name}${item.driver!.mobile != null ? ' · ${item.driver!.mobile}' : ''}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    Text(
                      '${item.trip.type ?? 'Trip'} · ${item.trip.status ?? ''}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Advance: ${_inrFmt.format(item.advance.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (item.canPayAdvance) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: paying ? null : () => _payAdvance(item),
                          child: paying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Pay Advance'),
                        ),
                      ),
                    ] else if (ui == DriverAdvanceUiState.failed) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Payment failed. Please try again.',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ] else if (ui == DriverAdvanceUiState.processing) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Payment or payout processing…',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
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

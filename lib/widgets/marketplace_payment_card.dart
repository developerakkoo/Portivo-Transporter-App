import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/user_feedback.dart';
import '../data/models/marketplace_payment_model.dart';
import '../data/models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/beneficiary_provider.dart';
import '../providers/marketplace_payment_provider.dart';
import '../screens/payments/marketplace_razorpay_checkout_screen.dart';

/// Payment (buyer) and payout (seller) card for marketplace booking trips.
class MarketplacePaymentCard extends StatefulWidget {
  const MarketplacePaymentCard({
    super.key,
    required this.trip,
    this.onPaymentComplete,
  });

  final TripModel trip;
  final VoidCallback? onPaymentComplete;

  @override
  State<MarketplacePaymentCard> createState() => _MarketplacePaymentCardState();
}

class _MarketplacePaymentCardState extends State<MarketplacePaymentCard> {
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MarketplacePaymentProvider>().loadStatus(widget.trip.id);
      if (widget.trip.marketplaceRole == 'seller') {
        context.read<BeneficiaryProvider>().loadBeneficiary();
      }
    });
  }

  Future<void> _payNow(MarketplacePaymentProvider provider) async {
    if (_paying) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _paying = true);
    try {
      final name = (user.company?.trim().isNotEmpty == true
              ? user.company
              : user.name) ??
          'Transporter';
      final email = '${user.mobile}@porttivo.app';
      final initiate = await provider.initiatePayment(
        tripId: widget.trip.id,
        payerName: name,
        payerEmail: email,
        payerPhone: user.mobile,
      );
      if (!mounted || initiate.fields == null) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => MarketplaceRazorpayCheckoutScreen(
            tripId: widget.trip.id,
            fields: initiate.fields!,
          ),
        ),
      );
      if (paid == true && mounted) {
        showUserSuccessSnackBar(context, 'Payment successful');
        widget.onPaymentComplete?.call();
      }
      if (mounted) {
        await provider.loadStatus(widget.trip.id);
      }
    } catch (e) {
      if (!mounted) return;
      await provider.loadStatus(widget.trip.id, silent: true);
      if (!mounted) return;
      showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  String _formatAmount(num? amount) {
    if (amount == null) return '—';
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
        .format(amount);
  }

  String _payoutLabel(String? status) => marketplacePayoutSummary(status);

  bool get _tripClosed =>
      AppConstants.tripStatusesCompleted.contains(widget.trip.status);

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    if (!trip.isMarketplaceBookingTrip) return const SizedBox.shrink();

    final isBuyer = trip.isMarketplaceBuyerView;
    final isSeller = trip.marketplaceRole == 'seller';

    return Consumer<MarketplacePaymentProvider>(
      builder: (context, provider, _) {
        final status = provider.statusFor(trip.id);
        final loading = provider.isLoading(trip.id);
        final ui = provider.uiStateFor(trip.id);
        final agreed = status?.booking?.agreedPrice;
        final payAmount = status?.payment?.amount ?? agreed;

        return Container(
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
                  Icon(
                    isBuyer ? Icons.payment_outlined : Icons.account_balance_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBuyer ? 'Marketplace Payment' : 'Marketplace Payout',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (loading && status == null)
                const LinearProgressIndicator(minHeight: 2)
              else if (isBuyer) ...[
                Text(
                  'Agreed rate: ${_formatAmount(agreed)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                _buyerBody(context, provider, ui, payAmount, status),
              ] else if (isSeller) ...[
                Text(
                  'Agreed rate: ${_formatAmount(agreed)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  _payoutLabel(status?.payout?.status),
                  style: TextStyle(
                    color: status?.payout?.status?.toUpperCase() == 'COMPLETED'
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status?.payment?.isSuccess == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Buyer payment received',
                    style: TextStyle(color: AppColors.success, fontSize: 13),
                  ),
                ],
                Consumer<BeneficiaryProvider>(
                  builder: (context, beneficiary, _) {
                    if (_tripClosed || beneficiary.hasBankAccount) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/bank-account'),
                        icon: const Icon(Icons.account_balance_outlined, size: 18),
                        label: const Text('Add bank account to receive payout'),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buyerBody(
    BuildContext context,
    MarketplacePaymentProvider provider,
    MarketplacePaymentUiState ui,
    num? payAmount,
    MarketplacePaymentStatusResponse? status,
  ) {
    if (_tripClosed && ui != MarketplacePaymentUiState.paid) {
      return const Text(
        'Trip complete',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    switch (ui) {
      case MarketplacePaymentUiState.notReady:
        return Text(
          status?.buyerSummaryLine() ??
              'Payment unlocks after the driver completes the first milestone.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        );
      case MarketplacePaymentUiState.payNow:
      case MarketplacePaymentUiState.retry:
        final cta = status?.buyerCtaLabel() ??
            (ui == MarketplacePaymentUiState.retry ? 'Retry' : 'Make Payment');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ui == MarketplacePaymentUiState.retry)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Previous payment did not complete. You can try again.',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _paying ? null : () => _payNow(provider),
                child: _paying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        ui == MarketplacePaymentUiState.retry
                            ? cta
                            : '$cta ${_formatAmount(payAmount)}',
                      ),
              ),
            ),
          ],
        );
      case MarketplacePaymentUiState.processing:
        return const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Payment pending',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      case MarketplacePaymentUiState.paid:
        return Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Payment Completed · ${_formatAmount(payAmount)}',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
    }
  }
}

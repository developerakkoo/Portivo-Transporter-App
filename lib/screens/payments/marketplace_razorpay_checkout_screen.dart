import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/marketplace_payment_model.dart';
import '../../providers/marketplace_payment_provider.dart';

/// Opens Razorpay native checkout using backend-provided order fields only.
/// Returns `true` when backend confirms payment SUCCESS after polling.
/// On cancel/dismiss, pops immediately back to trip detail (no intermediate UI).
class MarketplaceRazorpayCheckoutScreen extends StatefulWidget {
  const MarketplaceRazorpayCheckoutScreen({
    super.key,
    required this.tripId,
    required this.fields,
  });

  final String tripId;
  final RazorpayCheckoutFields fields;

  @override
  State<MarketplaceRazorpayCheckoutScreen> createState() =>
      _MarketplaceRazorpayCheckoutScreenState();
}

class _MarketplaceRazorpayCheckoutScreenState
    extends State<MarketplaceRazorpayCheckoutScreen> {
  late final Razorpay _razorpay;
  bool _opened = false;
  bool _verifying = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCheckout());
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _exitToTrip({required bool success}) async {
    if (_exiting || !mounted) return;
    _exiting = true;
    try {
      await context
          .read<MarketplacePaymentProvider>()
          .loadStatus(widget.tripId, silent: true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context, success);
  }

  void _openCheckout() {
    if (_opened || _exiting) return;
    _opened = true;
    final f = widget.fields;
    final options = <String, dynamic>{
      'key': f.key,
      'amount': f.amount,
      'currency': f.currency,
      'order_id': f.orderId,
      if (f.name != null) 'name': f.name,
      if (f.description != null) 'description': f.description,
      'prefill': {
        if (f.prefillName != null) 'name': f.prefillName,
        if (f.prefillEmail != null) 'email': f.prefillEmail,
        if (f.prefillContact != null) 'contact': f.prefillContact,
      },
    };
    try {
      _razorpay.open(options);
    } catch (_) {
      unawaited(_exitToTrip(success: false));
    }
  }

  Future<void> _pollBackend() async {
    if (!mounted) return;
    setState(() => _verifying = true);
    final provider = context.read<MarketplacePaymentProvider>();
    final result = await provider.refreshAfterPayment(widget.tripId);
    if (!mounted) return;
    if (result?.payment?.isSuccess == true) {
      await _exitToTrip(success: true);
      return;
    }
    // Not confirmed — return to trip so Pay Now is available again.
    await _exitToTrip(success: false);
  }

  void _onSuccess(PaymentSuccessResponse response) {
    unawaited(_pollBackend());
  }

  void _onError(PaymentFailureResponse response) {
    // User dismissed Razorpay or payment failed — go straight back to trip.
    unawaited(_exitToTrip(success: false));
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // Keep Razorpay open; no intermediate screen.
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_exiting) {
          unawaited(_exitToTrip(success: false));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _verifying
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Verifying payment…',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

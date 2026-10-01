import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/driver_advance_model.dart';
import '../../providers/driver_advance_payment_provider.dart';

/// Razorpay checkout for driver advance PayIN. Verifies with backend on success.
class DriverAdvanceRazorpayCheckoutScreen extends StatefulWidget {
  const DriverAdvanceRazorpayCheckoutScreen({
    super.key,
    required this.tripId,
    required this.fields,
  });

  final String tripId;
  final DriverAdvanceRazorpayFields fields;

  @override
  State<DriverAdvanceRazorpayCheckoutScreen> createState() =>
      _DriverAdvanceRazorpayCheckoutScreenState();
}

class _DriverAdvanceRazorpayCheckoutScreenState
    extends State<DriverAdvanceRazorpayCheckoutScreen> {
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

  Future<void> _exit({required bool success}) async {
    if (_exiting || !mounted) return;
    _exiting = true;
    try {
      await context
          .read<DriverAdvancePaymentProvider>()
          .loadPayments(refresh: true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context, success);
  }

  void _openCheckout() {
    if (_opened || _exiting) return;
    _opened = true;
    final f = widget.fields;
    try {
      _razorpay.open({
        'key': f.keyId,
        'amount': f.amount,
        'currency': f.currency,
        'order_id': f.orderId,
        'name': 'Porttivo',
        'description': 'Driver advance payment',
      });
    } catch (_) {
      unawaited(_exit(success: false));
    }
  }

  Future<void> _verifyAndRefresh(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _verifying = true);
    final provider = context.read<DriverAdvancePaymentProvider>();
    try {
      await provider.verifyPayment(
        widget.tripId,
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? widget.fields.orderId,
        razorpaySignature: response.signature ?? '',
      );
      await provider.refreshAfterPayment(widget.tripId);
      if (!mounted) return;
      await _exit(success: true);
    } catch (_) {
      await provider.refreshAfterPayment(widget.tripId);
      if (!mounted) return;
      await _exit(success: false);
    }
  }

  void _onSuccess(PaymentSuccessResponse response) {
    unawaited(_verifyAndRefresh(response));
  }

  void _onError(PaymentFailureResponse response) {
    unawaited(_exit(success: false));
  }

  void _onExternalWallet(ExternalWalletResponse response) {}

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_exiting) {
          unawaited(_exit(success: false));
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

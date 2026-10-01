import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/user_feedback.dart';
import '../data/models/razorpay_payment_link_model.dart';
import '../services/razorpay_payment_link_service.dart';

class PaymentRequestCard extends StatefulWidget {
  const PaymentRequestCard({
    super.key,
    required this.request,
    required this.isCreator,
  });

  final ExtraChargePaymentRequest request;
  final bool isCreator;

  @override
  State<PaymentRequestCard> createState() => _PaymentRequestCardState();
}

class _PaymentRequestCardState extends State<PaymentRequestCard> {
  final RazorpayPaymentLinkService _service = RazorpayPaymentLinkService();
  RazorpayPaymentLinkStatus? _status;
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _schedulePoll() {
    _poll?.cancel();
    final current = _status;
    if (current != null && !current.shouldKeepPolling) return;
    _poll = Timer(const Duration(seconds: 4), () {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    try {
      final status = await _service.getStatus(widget.request.recordId);
      if (!mounted) return;
      setState(() => _status = status);
      _schedulePoll();
    } catch (_) {
      if (!mounted) return;
      _schedulePoll();
    }
  }

  Future<void> _openPay() async {
    final url = _status?.shortUrl ?? widget.request.shortUrl;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await canLaunchUrl(uri);
      if (ok) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    }
    if (mounted) unawaited(_refresh());
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.cancel(widget.request.recordId);
      if (!mounted) return;
      setState(() {
        _status = RazorpayPaymentLinkStatus(
          publicId: _status?.publicId,
          paymentLinkId: _status?.paymentLinkId,
          shortUrl: _status?.shortUrl ?? widget.request.shortUrl,
          amount: _status?.amount ?? widget.request.amount,
          currency: _status?.currency ?? 'INR',
          status: 'CANCELLED',
          transferStatus: _status?.transferStatus,
          transferredAmount: _status?.transferredAmount ?? 0,
        );
      });
      _poll?.cancel();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusLabel() {
    final s = _status;
    if (s == null) return 'Checking status…';
    if (s.isCancelled) {
      if (s.normalizedStatus == 'EXPIRED') return 'Expired';
      if (s.normalizedStatus == 'FAILED') return 'Failed';
      return 'Cancelled';
    }
    if (s.isPaid && s.isPayoutProcessed) return 'Paid · Payout complete';
    if (s.isPaid && s.isPayoutFailed) return 'Paid · Payout failed';
    if (s.isPaid) return 'Paid · Payout in progress';
    return 'Awaiting payment';
  }

  Color _statusColor() {
    final s = _status;
    if (s == null) return AppColors.textSecondary;
    if (s.isCancelled) return AppColors.error;
    if (s.isPaid && s.isPayoutProcessed) return AppColors.success;
    if (s.isPaid && s.isPayoutFailed) return AppColors.error;
    if (s.isPaid) return AppColors.warning;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final amount = _status?.amount ?? widget.request.amount;
    final created = _status == null || _status!.isCreated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extra charges · ₹${formatInrAmount(amount)}',
            style: theme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.request.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.request.description,
              style: theme.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _statusLabel(),
            style: theme.labelMedium?.copyWith(
              color: _statusColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!widget.isCreator && created) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                onPressed: _openPay,
                child: const Text('Pay'),
              ),
            ),
          ],
          if (widget.isCreator && created) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: _busy ? null : _cancel,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel link'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/payment_session.dart';
import '../../services/payment_service.dart';

/// Hosts the PayU checkout inside an in-app WebView.
///
/// The screen auto-submits the gateway [PaymentRequest] fields as an HTML form
/// to the PayU `actionUrl`. When PayU posts back to the surl/furl webhook (which
/// we detect by matching [ApiConfig.payuWebhookPath] in the navigation URL), the
/// WebView is stopped and the backend is polled for the authoritative status.
///
/// Returns the terminal [PaymentSession] (or `null` if the user aborted) via
/// [Navigator.pop].
class PayUCheckoutScreen extends StatefulWidget {
  final PaymentSession session;

  const PayUCheckoutScreen({super.key, required this.session});

  @override
  State<PayUCheckoutScreen> createState() => _PayUCheckoutScreenState();
}

enum _CheckoutPhase { loading, checkout, verifying, result }

class _PayUCheckoutScreenState extends State<PayUCheckoutScreen> {
  final PaymentService _paymentService = PaymentService();

  late final WebViewController _controller;

  _CheckoutPhase _phase = _CheckoutPhase.loading;
  bool _gatewayReturned = false;
  PaymentSession? _result;
  String? _errorMessage;

  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPollAttempts = 30; // ~60s

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final request = widget.session.paymentRequest;
    if (request == null || !request.isValid) {
      // Nothing to submit; surface an error rather than a blank WebView.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showResult(null, error: 'Payment could not be initialised.');
      });
      _controller = WebViewController();
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (navRequest) {
            if (_isGatewayReturnUrl(navRequest.url)) {
              _onGatewayReturn();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && _isGatewayReturnUrl(url)) {
              _onGatewayReturn();
            }
          },
          onPageStarted: (url) {
            if (_isGatewayReturnUrl(url)) {
              _onGatewayReturn();
            } else if (mounted && _phase == _CheckoutPhase.loading) {
              setState(() => _phase = _CheckoutPhase.checkout);
            }
          },
          onWebResourceError: (error) {
            // Ignore sub-resource errors (fonts, sentry, etc). Only the very
            // first main-frame failure before the gateway loads is fatal.
            if (!_gatewayReturned &&
                error.isForMainFrame == true &&
                _phase == _CheckoutPhase.loading) {
              _showResult(
                null,
                error: 'Unable to reach the payment gateway. '
                    'Please check your connection and try again.',
              );
            }
          },
        ),
      );

    _controller.loadHtmlString(
      _buildAutoSubmitForm(request.actionUrl, request.fields),
      baseUrl: _originOf(request.actionUrl),
    );
  }

  bool _isGatewayReturnUrl(String url) {
    // surl/furl point at the backend webhook; matching the path is host-agnostic.
    return url.contains(ApiConfig.payuWebhookPath);
  }

  /// Builds an HTML page that auto-submits all gateway fields as a POST form.
  /// This mirrors a real browser form submission, which PayU expects.
  String _buildAutoSubmitForm(String actionUrl, Map<String, String> fields) {
    final inputs = fields.entries
        .map((e) =>
            '<input type="hidden" name="${_esc(e.key)}" value="${_esc(e.value)}">')
        .join();
    return '<!doctype html><html><head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '</head><body onload="document.forms[0].submit()">'
        '<form method="POST" action="${_esc(actionUrl)}">$inputs</form>'
        '</body></html>';
  }

  /// Escapes values for safe use inside HTML attributes.
  String _esc(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String? _originOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    return '${uri.scheme}://${uri.host}';
  }

  void _onGatewayReturn() {
    if (_gatewayReturned) return;
    _gatewayReturned = true;
    if (mounted) {
      setState(() => _phase = _CheckoutPhase.verifying);
    }
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
      if (!mounted) return;
      try {
        final session = await _paymentService.getSessionStatus(widget.session.id);
        if (session.isTerminal) {
          _showResult(session);
          return;
        }
      } catch (_) {
        // Transient error while the webhook lands; keep retrying.
      }
      await Future.delayed(_pollInterval);
    }

    if (!mounted) return;
    // Timed out; do a best-effort final read for the message.
    try {
      final session = await _paymentService.getSessionStatus(widget.session.id);
      _showResult(
        session,
        error: session.isTerminal
            ? null
            : 'Payment is still processing. Please check again shortly.',
      );
    } catch (_) {
      _showResult(
        null,
        error: 'Could not confirm the payment status. Please check again shortly.',
      );
    }
  }

  void _showResult(PaymentSession? session, {String? error}) {
    if (!mounted) return;
    setState(() {
      _phase = _CheckoutPhase.result;
      _result = session;
      _errorMessage = error;
    });
  }

  Future<void> _confirmAndClose() async {
    if (_phase == _CheckoutPhase.result) {
      Navigator.of(context).pop(_result);
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
          'Your payment is not complete. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;

    // The user may have completed payment just before leaving; do one final read.
    PaymentSession? finalStatus;
    try {
      finalStatus = await _paymentService.getSessionStatus(widget.session.id);
    } catch (_) {
      finalStatus = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop(finalStatus);
  }

  @override
  Widget build(BuildContext context) {
    final isResult = _phase == _CheckoutPhase.result;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmAndClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('PayU Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmAndClose,
          ),
        ),
        body: isResult ? _buildResultView() : _buildCheckoutView(),
      ),
    );
  }

  Widget _buildCheckoutView() {
    final showOverlay = _phase != _CheckoutPhase.checkout;
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (showOverlay)
          Container(
            color: AppColors.background,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  _phase == _CheckoutPhase.verifying
                      ? 'Verifying payment...'
                      : 'Loading secure checkout...',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultView() {
    final session = _result;
    final isSuccess = session?.isSuccess ?? false;
    final isRefunded = session?.isRefunded ?? false;

    final IconData icon;
    final Color color;
    final String title;
    if (isSuccess) {
      icon = Icons.check_circle;
      color = AppColors.success;
      title = 'Payment Successful';
    } else if (isRefunded) {
      icon = Icons.replay_circle_filled;
      color = AppColors.info;
      title = 'Payment Refunded';
    } else if (session != null && session.isFailed) {
      icon = Icons.cancel;
      color = AppColors.error;
      title = 'Payment Failed';
    } else {
      icon = Icons.info;
      color = AppColors.warning;
      title = 'Payment Pending';
    }

    final message = _errorMessage ??
        session?.failureReason ??
        (isSuccess
            ? 'Your payment has been received successfully.'
            : 'The payment could not be completed.');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: color, size: 88),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (session != null) ...[
            const SizedBox(height: 24),
            _buildSummaryRow('Amount',
                '${session.currency} ${session.amount.toStringAsFixed(2)}'),
            _buildSummaryRow('Status', session.status),
            if (session.merchantTransactionId != null)
              _buildSummaryRow('Transaction', session.merchantTransactionId!),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_result),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

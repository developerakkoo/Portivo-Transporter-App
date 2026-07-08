import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/payment_session.dart';
import 'api_service.dart';

/// Client for the generic payment-session flow (`/api/payments/*`).
///
/// Flow:
/// 1. [createSession] -> backend creates a [PaymentSession] and returns the
///    gateway [PaymentRequest] (actionUrl + fields) to submit to PayU.
/// 2. The UI opens the PayU checkout in a WebView.
/// 3. [getSessionStatus] is polled for the authoritative final status once the
///    gateway posts back to the surl/furl webhook.
class PaymentService {
  final ApiService _api = ApiService();

  Never _throwApiFailure(dynamic data, {required String fallback}) {
    if (data is Map) {
      final message = data['message']?.toString();
      throw Exception(message ?? fallback);
    }
    throw Exception(fallback);
  }

  /// Convenience default success/failure URL pointing at the reachable
  /// deployed webhook, so completion is detectable regardless of server env.
  static String get payuWebhookUrl =>
      '${ApiConfig.baseUrl}${ApiConfig.payuWebhookPath}';

  Future<PaymentSession> createSession(Map<String, dynamic> body) async {
    try {
      if (kDebugMode) {
        print('PaymentService: Creating payment session');
      }

      final response = await _api.post(
        ApiConfig.paymentsSessions,
        data: body,
      );

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final payment = (data['data'] as Map)['payment'];
        if (payment is Map) {
          return PaymentSession.fromJson(Map<String, dynamic>.from(payment));
        }
      }
      _throwApiFailure(data, fallback: 'Failed to create payment session');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('PaymentService: Error creating session: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<PaymentSession> getSessionStatus(String id) async {
    try {
      final response = await _api.get(ApiConfig.paymentSessionById(id));

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final payment = (data['data'] as Map)['payment'];
        if (payment is Map) {
          return PaymentSession.fromJson(Map<String, dynamic>.from(payment));
        }
      }
      _throwApiFailure(data, fallback: 'Failed to fetch payment status');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('PaymentService: Error fetching status: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

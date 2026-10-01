import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/marketplace_payment_model.dart';
import '../services/marketplace_payment_service.dart';
import '../services/socket_service.dart';
import '../utils/error_utils.dart';

/// Caches marketplace payment status per trip and drives Pay Now / payout UI.
class MarketplacePaymentProvider with ChangeNotifier {
  final MarketplacePaymentService _service = MarketplacePaymentService();
  final SocketService _socket = SocketService();

  final Map<String, MarketplacePaymentStatusResponse> _byTripId = {};
  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};
  final Set<String> _initiatingTripIds = {};

  MarketplacePaymentProvider() {
    _socket.addMarketplacePaymentReadyListener(_onPaymentReady);
  }

  MarketplacePaymentStatusResponse? statusFor(String tripId) => _byTripId[tripId];

  bool isLoading(String tripId) => _loading[tripId] ?? false;

  String? errorFor(String tripId) => _errors[tripId];

  MarketplacePaymentUiState uiStateFor(String tripId) {
    final s = _byTripId[tripId];
    if (s == null) return MarketplacePaymentUiState.notReady;
    return s.uiState;
  }

  void _onPaymentReady(Map<String, dynamic> payload) {
    final payment = payload['payment'];
    String? tripId;
    if (payment is Map) {
      tripId = (payment['tripId'] ?? payment['trip']?['id'])?.toString();
    }
    tripId ??= payload['trip'] is Map
        ? (payload['trip'] as Map)['id']?.toString()
        : null;
    if (tripId != null && tripId.isNotEmpty) {
      loadStatus(tripId, silent: true);
    }
  }

  Future<MarketplacePaymentStatusResponse?> loadStatus(
    String tripId, {
    bool silent = false,
  }) async {
    if (!silent) {
      _loading[tripId] = true;
      _errors[tripId] = null;
      notifyListeners();
    }
    try {
      final status = await _service.getPaymentStatus(tripId);
      _byTripId[tripId] = status;
      _errors[tripId] = null;
      notifyListeners();
      return status;
    } catch (e) {
      _errors[tripId] = ErrorUtils.userMessage(e);
      if (kDebugMode) print('MarketplacePaymentProvider.loadStatus: $e');
      notifyListeners();
      return null;
    } finally {
      _loading[tripId] = false;
      notifyListeners();
    }
  }

  /// Poll backend until payment succeeds or timeout (authoritative, not Razorpay callback).
  Future<MarketplacePaymentStatusResponse?> refreshAfterPayment(
    String tripId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final status = await loadStatus(tripId, silent: true);
      if (status?.payment?.isSuccess == true) return status;
      if (status?.payment?.isFailed == true && !status!.eligibility.canInitiatePayment) {
        return status;
      }
      await Future<void>.delayed(interval);
    }
    return _byTripId[tripId];
  }

  Future<RazorpayInitiateResponse> initiatePayment({
    required String tripId,
    required String payerName,
    required String payerEmail,
    required String payerPhone,
  }) async {
    if (_initiatingTripIds.contains(tripId)) {
      throw Exception('Payment already in progress');
    }
    _initiatingTripIds.add(tripId);
    try {
      return await _service.initiateRazorpay(
        tripId: tripId,
        payerName: payerName,
        payerEmail: payerEmail,
        payerPhone: payerPhone,
      );
    } finally {
      _initiatingTripIds.remove(tripId);
    }
  }

  void clearTrip(String tripId) {
    _byTripId.remove(tripId);
    _loading.remove(tripId);
    _errors.remove(tripId);
    notifyListeners();
  }

  @override
  void dispose() {
    _socket.removeMarketplacePaymentReadyListener(_onPaymentReady);
    super.dispose();
  }
}

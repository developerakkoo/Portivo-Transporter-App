import 'package:flutter/foundation.dart';

import '../data/models/driver_advance_model.dart';
import '../services/driver_advance_payment_service.dart';
import '../utils/error_utils.dart';

class DriverAdvancePaymentProvider with ChangeNotifier {
  final DriverAdvancePaymentService _service = DriverAdvancePaymentService();

  List<TripAdvanceListItem> _items = [];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _pages = 1;
  int _total = 0;

  List<TripAdvanceListItem> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  String? get error => _error;
  int get total => _total;

  TripAdvanceListItem? itemForTrip(String tripId) {
    try {
      return _items.firstWhere((e) => e.trip.id == tripId);
    } catch (_) {
      return null;
    }
  }

  DriverAdvanceUiState uiStateFor(String tripId) =>
      itemForTrip(tripId)?.uiState ?? DriverAdvanceUiState.noAdvance;

  Future<void> loadPayments({bool refresh = false}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.fetchAdvancePayments(page: 1, limit: 50);
      _items = result.items;
      _page = result.page;
      _pages = result.pages;
      _total = result.total;
      _error = null;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) print('DriverAdvancePaymentProvider.loadPayments: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<DriverAdvanceInitiateResponse> initiatePayment(String tripId) =>
      _service.initiateAdvancePay(tripId);

  Future<void> verifyPayment(
    String tripId, {
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) =>
      _service.verifyAdvancePay(
        tripId,
        razorpayPaymentId: razorpayPaymentId,
        razorpayOrderId: razorpayOrderId,
        razorpaySignature: razorpaySignature,
      );

  Future<void> refreshAfterPayment(String tripId) async {
    for (var i = 0; i < 30; i++) {
      await loadPayments(refresh: true);
      final item = itemForTrip(tripId);
      final status = item?.advance.status?.toUpperCase();
      if (status == 'PAID' ||
          status == 'PAYOUT_PROCESSING' ||
          status == 'PAYOUT_PENDING' ||
          status == 'PAYMENT_PENDING') {
        return;
      }
      if (status == 'PAYMENT_FAILED' || status == 'PAYOUT_FAILED') {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}

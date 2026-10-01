import 'package:flutter/foundation.dart';

import '../data/models/marketplace_payment_model.dart';
import '../services/marketplace_payment_service.dart';
import '../utils/error_utils.dart';

class MarketplacePaymentsListProvider with ChangeNotifier {
  final MarketplacePaymentService _service = MarketplacePaymentService();

  List<MarketplacePaymentListItem> _payments = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasNext = false;
  int _total = 0;

  List<MarketplacePaymentListItem> get payments =>
      List.unmodifiable(_payments);
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  String? get error => _error;
  bool get hasNext => _hasNext;
  int get total => _total;

  Future<void> loadPayments({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && _payments.isNotEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.listPayments(page: 1, limit: 20);
      _payments = result.payments;
      _page = result.page;
      _hasNext = result.hasNext;
      _total = result.total;
      _error = null;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('MarketplacePaymentsListProvider.loadPayments: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasNext) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final nextPage = _page + 1;
      final result = await _service.listPayments(page: nextPage, limit: 20);
      _payments = [..._payments, ...result.payments];
      _page = result.page;
      _hasNext = result.hasNext;
      _total = result.total;
    } catch (e) {
      if (kDebugMode) {
        print('MarketplacePaymentsListProvider.loadMore: $e');
      }
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}

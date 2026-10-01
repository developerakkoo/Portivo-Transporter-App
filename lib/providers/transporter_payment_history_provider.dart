import 'package:flutter/foundation.dart';

import '../data/models/transporter_payment_history_model.dart';
import '../services/transporter_payment_history_service.dart';
import '../utils/error_utils.dart';

class TransporterPaymentHistoryProvider with ChangeNotifier {
  final TransporterPaymentHistoryService _service =
      TransporterPaymentHistoryService();

  List<TransporterPaymentHistoryItem> _payments = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasNext = false;
  int _total = 0;

  List<TransporterPaymentHistoryItem> get payments =>
      List.unmodifiable(_payments);
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  String? get error => _error;
  bool get hasNext => _hasNext;
  int get total => _total;

  Future<void> loadHistory({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && _payments.isNotEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.fetchHistory(page: 1, limit: 20);
      _payments = result.payments;
      _page = result.page;
      _hasNext = result.hasNext;
      _total = result.total;
      _error = null;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('TransporterPaymentHistoryProvider.loadHistory: $e');
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
      final result = await _service.fetchHistory(page: nextPage, limit: 20);
      _payments = [..._payments, ...result.payments];
      _page = result.page;
      _hasNext = result.hasNext;
      _total = result.total;
    } catch (e) {
      if (kDebugMode) {
        print('TransporterPaymentHistoryProvider.loadMore: $e');
      }
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}

import 'package:flutter/foundation.dart';
import '../data/models/transporter_customer_model.dart';
import '../services/customer_service.dart';
import '../utils/error_utils.dart';

class CustomerProvider with ChangeNotifier {
  final CustomerService _customerService = CustomerService();

  List<TransporterCustomerModel> _customers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<TransporterCustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<TransporterCustomerModel> get filteredCustomers {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadCustomers({String? q, bool refresh = false}) async {
    if (!refresh && _customers.isNotEmpty && (q == null || q.isEmpty)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _customerService.getCustomers(q: q);
      _customers = results;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CustomerProvider: Error loading customers: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TransporterCustomerModel?> addCustomer(String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final customer = await _customerService.createCustomer(name);
      if (customer != null) {
        final index = _customers.indexWhere((c) => c.id == customer.id);
        if (index >= 0) {
          _customers[index] = customer;
        } else {
          _customers.insert(0, customer);
        }
      }
      return customer;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('CustomerProvider: Error adding customer: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

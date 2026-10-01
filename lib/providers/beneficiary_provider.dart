import 'package:flutter/foundation.dart';
import '../data/models/beneficiary_model.dart';
import '../services/payout_service.dart';
import '../utils/error_utils.dart';

/// State for the Bank Account Details screen (Razorpay payout beneficiary).
class BeneficiaryProvider with ChangeNotifier {
  final PayoutService _payoutService = PayoutService();

  BeneficiaryModel? _beneficiary;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _hasLoaded = false;
  String? _error;

  BeneficiaryModel? get beneficiary => _beneficiary;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  bool get hasBankAccount => _beneficiary?.isActive == true;

  Future<void> loadBeneficiary({bool refresh = false}) async {
    if (_hasLoaded && !refresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _beneficiary = await _payoutService.getBeneficiary();
      _hasLoaded = true;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('BeneficiaryProvider: Error loading beneficiary: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers the bank account with Razorpay. Returns true on success;
  /// on failure [error] holds a user-facing message.
  Future<bool> addBeneficiary({
    required String name,
    required String phone,
    required String bankAccount,
    required String ifsc,
    String? email,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      _beneficiary = await _payoutService.addBeneficiary(
        name: name,
        phone: phone,
        bankAccount: bankAccount,
        ifsc: ifsc,
        email: email,
      );
      _hasLoaded = true;
      return true;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('BeneficiaryProvider: Error adding beneficiary: $e');
      }
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Removes the bank account from Razorpay. Returns true on success.
  Future<bool> deleteBeneficiary() async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _payoutService.deleteBeneficiary();
      if (success) {
        _beneficiary = null;
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('BeneficiaryProvider: Error deleting beneficiary: $e');
      }
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

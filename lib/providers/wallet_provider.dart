import 'package:flutter/foundation.dart';
import '../data/models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import '../utils/error_utils.dart';

class WalletProvider with ChangeNotifier {
  final WalletService _walletService = WalletService();

  double _balance = 0.0;
  List<WalletTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  double get balance => _balance;
  List<WalletTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBalance({bool refresh = false}) async {
    if (!refresh && _balance > 0) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('WalletProvider: Loading balance...');
      }
      
      final balance = await _walletService.getWalletBalance();
      _balance = balance;
      
      if (kDebugMode) {
        print('WalletProvider: Balance loaded: $_balance');
      }
    } catch (e, stackTrace) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('WalletProvider: Error loading balance: $e');
        print('Stack: $stackTrace');
      }
      // Set balance to 0 instead of throwing
      _balance = 0.0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactions({
    int page = 1,
    int limit = 20,
    bool refresh = false,
  }) async {
    if (!refresh && _transactions.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final transactions = await _walletService.getWalletTransactions(
        page: page,
        limit: limit,
      );

      if (refresh) {
        _transactions = transactions;
      } else {
        _transactions.addAll(transactions);
      }
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('WalletProvider: Error loading transactions: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMoney(double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _walletService.addMoney(amount);
      if (success) {
        await loadBalance(refresh: true);
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('WalletProvider: Error adding money: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMoney({
    required String recipientId,
    required double amount,
    String? description,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _walletService.sendMoney(
        recipientId: recipientId,
        amount: amount,
        description: description,
      );
      if (success) {
        await loadBalance(refresh: true);
        await loadTransactions(refresh: true);
      }
      return success;
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) {
        print('WalletProvider: Error sending money: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      loadBalance(refresh: true),
      loadTransactions(refresh: true),
    ]);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

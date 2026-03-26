import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/wallet_transaction_model.dart';
import 'api_service.dart';

class WalletService {
  final ApiService _api = ApiService();

  Future<double> getWalletBalance() async {
    try {
      if (kDebugMode) {
        print('WalletService: Fetching wallet balance');
      }
      
      // Try dedicated wallet endpoint first
      try {
        final response = await _api.get(ApiConfig.walletBalance);
        
        if (response.data['success'] == true) {
          final data = response.data['data'];
          if (data != null && data['wallet'] != null) {
            final walletBalance = data['wallet']['balance'];
            return (walletBalance ?? 0).toDouble();
          }
        }
      } catch (e) {
        // Fallback to transporter profile if wallet endpoint fails
        if (kDebugMode) {
          print('WalletService: Wallet endpoint failed, trying transporter profile: $e');
        }
        final response = await _api.get(ApiConfig.transporterProfile);
        
        if (response.data['success'] == true) {
          final data = response.data['data'];
          if (data != null && data['transporter'] != null) {
            final walletBalance = data['transporter']['walletBalance'];
            return (walletBalance ?? 0).toDouble();
          }
        }
      }
      
      return 0.0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('WalletService: Error fetching balance: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<WalletTransactionModel>> getWalletTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? status,
  }) async {
    try {
      if (kDebugMode) {
        print('WalletService: Fetching wallet transactions (page: $page, limit: $limit)');
      }
      
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (type != null) queryParams['type'] = type;
      if (status != null) queryParams['status'] = status;
      
      final response = await _api.get(
        ApiConfig.walletTransactions,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['transactions'] != null) {
          final List<dynamic> transactionsData = data['transactions'];
          return transactionsData.map((json) => WalletTransactionModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('WalletService: Error fetching transactions: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> addMoney(double amount) async {
    try {
      if (kDebugMode) {
        print('WalletService: Adding money: $amount');
      }
      
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }
      
      final response = await _api.post(
        ApiConfig.walletAddMoney,
        data: {
          'amount': amount,
        },
      );

      return response.data['success'] == true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('WalletService: Error adding money: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<bool> sendMoney({
    required String recipientId,
    required double amount,
    String? description,
  }) async {
    try {
      if (kDebugMode) {
        print('WalletService: Sending money to $recipientId, amount: $amount');
      }

      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      final response = await _api.post(
        ApiConfig.walletTransfer,
        data: {
          'amount': amount,
          'recipientId': recipientId,
          if (description != null) 'description': description,
        },
      );

      return response.data['success'] == true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('WalletService: Error sending money: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

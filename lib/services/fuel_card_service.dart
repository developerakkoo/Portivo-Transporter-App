import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/fuel_card_model.dart';
import '../data/models/fuel_transaction_model.dart';
import 'api_service.dart';

class FuelCardService {
  final ApiService _api = ApiService();

  Future<List<FuelCardModel>> getFuelCards({
    String? status,
    bool? assigned,
  }) async {
    try {
      if (kDebugMode) {
        print('FuelCardService: Fetching fuel cards');
      }
      
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (assigned != null) queryParams['assigned'] = assigned.toString();

      final response = await _api.get(
        ApiConfig.fuelCards,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data is List) {
          return data.map((json) => FuelCardModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelCardService: Error fetching fuel cards: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<FuelCardModel>> getAssignedFuelCards() async {
    try {
      if (kDebugMode) {
        print('FuelCardService: Fetching assigned fuel cards');
      }
      
      final response = await _api.get(ApiConfig.fuelCardAssigned);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data is List) {
          return data.map((json) => FuelCardModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelCardService: Error fetching assigned cards: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<FuelTransactionModel>> getFuelCardTransactions(String cardId) async {
    try {
      if (kDebugMode) {
        print('FuelCardService: Fetching transactions for card: $cardId');
      }
      
      final response = await _api.get(ApiConfig.fuelCardTransactions(cardId));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['transactions'] != null) {
          final List<dynamic> transactionsData = data['transactions'];
          return transactionsData.map((json) => FuelTransactionModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelCardService: Error fetching transactions: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<FuelCardModel?> createFuelCard({
    required String cardNumber,
    double? balance,
    DateTime? expiryDate,
  }) async {
    try {
      if (kDebugMode) {
        print('FuelCardService: Creating fuel card: $cardNumber');
      }
      
      final response = await _api.post(
        ApiConfig.fuelCards,
        data: {
          'cardNumber': cardNumber,
          if (balance != null) 'balance': balance,
          if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null) {
          return FuelCardModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelCardService: Error creating fuel card: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<FuelCardModel?> assignFuelCard({
    required String cardId,
    required String driverId,
  }) async {
    try {
      if (kDebugMode) {
        print('FuelCardService: Assigning fuel card $cardId to driver $driverId');
      }
      
      final response = await _api.put(
        ApiConfig.fuelCardAssign(cardId),
        data: {
          'driverId': driverId,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null) {
          return FuelCardModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelCardService: Error assigning fuel card: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

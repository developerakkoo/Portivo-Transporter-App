import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/fuel_transaction_model.dart';
import 'api_service.dart';

class FuelTransactionService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>?> generateQR({
    required String vehicleNumber,
    required double amount,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
  }) async {
    try {
      if (kDebugMode) {
        print('FuelTransactionService: Generating QR code');
      }
      
      final response = await _api.post(
        ApiConfig.fuelGenerateQR,
        data: {
          'vehicleNumber': vehicleNumber,
          'amount': amount,
          'latitude': latitude,
          'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
          if (address != null) 'address': address,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelTransactionService: Error generating QR: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> scanQR({
    required String qrCode,
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (kDebugMode) {
        print('FuelTransactionService: Scanning QR code');
      }
      
      final response = await _api.post(
        ApiConfig.fuelScanQR,
        data: {
          'qrCode': qrCode,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelTransactionService: Error scanning QR: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<FuelTransactionModel>> getTransactions({
    String? status,
    String? fuelCardId,
    String? driverId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('FuelTransactionService: Fetching transactions');
      }
      
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (fuelCardId != null) queryParams['fuelCardId'] = fuelCardId;
      if (driverId != null) queryParams['driverId'] = driverId;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _api.get(
        ApiConfig.fuelTransactions,
        queryParameters: queryParams,
      );

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
        print('FuelTransactionService: Error fetching transactions: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<FuelTransactionModel?> getTransactionById(String id) async {
    try {
      if (kDebugMode) {
        print('FuelTransactionService: Fetching transaction by id: $id');
      }
      
      final response = await _api.get(ApiConfig.fuelTransactionById(id));

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['transaction'] != null) {
          return FuelTransactionModel.fromJson(data['transaction']);
        }
        // Fallback
        if (data != null) {
          return FuelTransactionModel.fromJson(data);
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FuelTransactionService: Error fetching transaction: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}

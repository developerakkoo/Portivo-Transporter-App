import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../data/models/marketplace_payment_model.dart';
import 'api_service.dart';

class MarketplacePaymentService {
  final ApiService _api = ApiService();

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Request failed';
  }

  Future<MarketplacePaymentStatusResponse> getPaymentStatus(String tripId) async {
    try {
      final response = await _api.get(ApiConfig.marketplacePaymentStatus(tripId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final parsed = MarketplacePaymentStatusResponse.fromJson(body['data']);
      if (parsed == null) throw Exception('Invalid payment status response');
      return parsed;
    } on DioException catch (e) {
      if (kDebugMode) print('MarketplacePaymentService.getPaymentStatus: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<RazorpayInitiateResponse> initiateRazorpay({
    required String tripId,
    required String payerName,
    required String payerEmail,
    required String payerPhone,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.marketplacePaymentInitiate(tripId),
        data: {
          'payerName': payerName,
          'payerEmail': payerEmail,
          'payerPhone': payerPhone,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final parsed = RazorpayInitiateResponse.fromJson(body['data']);
      if (parsed?.fields == null) {
        throw Exception('Invalid Razorpay initiate response');
      }
      return parsed!;
    } on DioException catch (e) {
      if (kDebugMode) print('MarketplacePaymentService.initiateRazorpay: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<MarketplacePaymentListResult> listPayments({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _api.get(
        ApiConfig.marketplacePayments,
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
        );
      }
      final data = body['data'];
      if (data is! Map) {
        return const MarketplacePaymentListResult();
      }
      return MarketplacePaymentListResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      if (kDebugMode) print('MarketplacePaymentService.listPayments: $e');
      throw Exception(_messageFromDio(e));
    }
  }
}

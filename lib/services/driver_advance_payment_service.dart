import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../data/models/driver_advance_model.dart';
import 'api_service.dart';

class DriverAdvancePaymentService {
  final ApiService _api = ApiService();

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['reason']?.toString() == 'RAZORPAY_FUND_ACCOUNT_NOT_READY') {
        return 'Driver must add a bank account in the Driver app before you can pay advance.';
      }
      if (data['message'] != null) {
        return data['message'].toString();
      }
    }
    return e.message ?? 'Request failed';
  }

  Future<TripAdvanceListResult> fetchAdvancePayments({
    int page = 1,
    int limit = 20,
    String? advanceStatus,
  }) async {
    try {
      final response = await _api.get(
        ApiConfig.tripAdvancePayments,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (advanceStatus != null && advanceStatus.isNotEmpty)
            'advanceStatus': advanceStatus,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      if (data is! Map) {
        return const TripAdvanceListResult(
          items: [],
          page: 1,
          limit: 20,
          total: 0,
          pages: 0,
        );
      }
      final rawList = data['trips'];
      final items = <TripAdvanceListItem>[];
      if (rawList is List) {
        for (final item in rawList) {
          final parsed = TripAdvanceListItem.fromJson(item);
          if (parsed != null) items.add(parsed);
        }
      }
      final pagination = data['pagination'];
      if (pagination is Map) {
        return TripAdvanceListResult(
          items: items,
          page: pagination['page'] is num ? (pagination['page'] as num).toInt() : page,
          limit: pagination['limit'] is num ? (pagination['limit'] as num).toInt() : limit,
          total: pagination['total'] is num ? (pagination['total'] as num).toInt() : items.length,
          pages: pagination['pages'] is num ? (pagination['pages'] as num).toInt() : 1,
        );
      }
      return TripAdvanceListResult(
        items: items,
        page: page,
        limit: limit,
        total: items.length,
        pages: 1,
      );
    } on DioException catch (e) {
      if (kDebugMode) print('DriverAdvancePaymentService.fetchAdvancePayments: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<DriverAdvanceInitiateResponse> initiateAdvancePay(String tripId) async {
    try {
      final response = await _api.post(ApiConfig.tripAdvancePay(tripId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final parsed = DriverAdvanceInitiateResponse.fromJson(body['data']);
      if (parsed == null) throw Exception('Invalid payment response');
      if (!parsed.alreadyPaid && parsed.razorpay == null) {
        throw Exception('Razorpay checkout fields missing');
      }
      return parsed;
    } on DioException catch (e) {
      if (kDebugMode) print('DriverAdvancePaymentService.initiateAdvancePay: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> verifyAdvancePay(
    String tripId, {
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.tripAdvanceVerify(tripId),
        data: {
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Verification failed' : 'Verification failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('DriverAdvancePaymentService.verifyAdvancePay: $e');
      throw Exception(_messageFromDio(e));
    }
  }
}

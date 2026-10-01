import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../data/models/razorpay_payment_link_model.dart';
import 'api_service.dart';

class RazorpayPaymentLinkService {
  final ApiService _api = ApiService();

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Request failed';
  }

  Future<RazorpayPaymentLinkCreated> create({
    required num amount,
    required String description,
    required String referenceType,
    required String referenceId,
    required String payerTransporterId,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.razorpayPaymentLinks,
        data: {
          'amount': amount,
          'description': description,
          'referenceType': referenceType,
          'referenceId': referenceId,
          'payerTransporterId': payerTransporterId,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
        );
      }
      final parsed = RazorpayPaymentLinkCreated.fromJson(body['data']);
      if (parsed == null || parsed.shortUrl == null || parsed.shortUrl!.isEmpty) {
        throw Exception('Invalid payment link response');
      }
      return parsed;
    } on DioException catch (e) {
      if (kDebugMode) print('RazorpayPaymentLinkService.create: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<RazorpayPaymentLinkStatus> getStatus(String recordId) async {
    try {
      final response = await _api.get(ApiConfig.razorpayPaymentLinkById(recordId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
        );
      }
      final parsed = RazorpayPaymentLinkStatus.fromJson(body['data']);
      if (parsed == null) throw Exception('Invalid payment link status');
      return parsed;
    } on DioException catch (e) {
      if (kDebugMode) print('RazorpayPaymentLinkService.getStatus: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> cancel(String recordId) async {
    try {
      final response = await _api.post(ApiConfig.razorpayPaymentLinkCancel(recordId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
        );
      }
    } on DioException catch (e) {
      if (kDebugMode) print('RazorpayPaymentLinkService.cancel: $e');
      throw Exception(_messageFromDio(e));
    }
  }
}

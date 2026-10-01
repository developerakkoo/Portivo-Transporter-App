import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../data/models/transporter_payment_history_model.dart';
import 'api_service.dart';

class TransporterPaymentHistoryService {
  final ApiService _api = ApiService();

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Request failed';
  }

  Future<TransporterPaymentHistoryResult> fetchHistory({
    int page = 1,
    int limit = 20,
    String? status,
    String? provider,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final response = await _api.get(
        ApiConfig.transporterPaymentHistory,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (status != null && status.isNotEmpty) 'status': status,
          if (provider != null && provider.isNotEmpty) 'provider': provider,
          if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
          if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
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
        return const TransporterPaymentHistoryResult(
          payments: [],
          page: 1,
          limit: 20,
          total: 0,
          count: 0,
          hasNext: false,
          hasPrevious: false,
        );
      }
      return TransporterPaymentHistoryResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('TransporterPaymentHistoryService.fetchHistory: $e');
      }
      throw Exception(_messageFromDio(e));
    }
  }
}

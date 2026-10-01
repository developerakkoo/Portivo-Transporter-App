import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import 'api_service.dart';

class QuoteService {
  final ApiService _api = ApiService();

  /// POST /api/requirements/:id/quotes — submit/update a quote.
  Future<void> submit({
    required String requirementId,
    required num price,
    String availability = 'TODAY',
    DateTime? availabilityDate,
    String? message,
  }) async {
    try {
      await _api.post(
        ApiConfig.requirementQuotes(requirementId),
        data: {
          'price': price,
          'availability': availability,
          if (availabilityDate != null)
            'availabilityDate': availabilityDate.toUtc().toIso8601String(),
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// PUT /api/quotes/:id/select — requester awards a quote. Returns tripId.
  Future<String?> select(String quoteId) async {
    try {
      final res = await _api.put(ApiConfig.quoteSelect(quoteId));
      final body = res.data;
      if (body is Map && body['data'] is Map) {
        return (body['data'] as Map)['tripId']?.toString();
      }
      return null;
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// PUT /api/quotes/:id/counter — requester proposes a counter price.
  Future<void> counter(String quoteId, num counterPrice) async {
    try {
      await _api.put(
        ApiConfig.quoteCounter(quoteId),
        data: {'counterPrice': counterPrice},
      );
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// GET /api/quotes/:quoteId/messages — quote-scoped chat history.
  Future<List<Map<String, dynamic>>> fetchMessages(String quoteId) async {
    try {
      final res = await _api.get(ApiConfig.quoteMessages(quoteId));
      final body = res.data;
      if (body is! Map || body['success'] != true) return [];
      final data = body['data'];
      final raw = data is Map ? data['messages'] : null;
      final out = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final m in raw) {
          if (m is Map) out.add(Map<String, dynamic>.from(m));
        }
      }
      return out;
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// POST /api/quotes/:quoteId/messages — send a chat message.
  Future<Map<String, dynamic>?> sendMessage(
    String quoteId,
    String content,
  ) async {
    try {
      final res = await _api.post(
        ApiConfig.quoteMessages(quoteId),
        data: {'content': content},
      );
      final body = res.data;
      if (body is Map && body['data'] is Map) {
        final msg = (body['data'] as Map)['message'];
        if (msg is Map) return Map<String, dynamic>.from(msg);
      }
      return null;
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  /// DELETE /api/quotes/:id — transporter withdraws own quote.
  Future<void> withdraw(String quoteId) async {
    try {
      await _api.delete(ApiConfig.quoteById(quoteId));
    } on DioException catch (e) {
      throw Exception(_msg(e));
    }
  }

  static String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? 'Request failed';
  }
}

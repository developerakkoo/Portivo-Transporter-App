import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import '../core/config/api_config.dart';
import '../data/models/marketplace_chat_models.dart';
import 'api_service.dart';

class VehicleBookingService {
  final ApiService _api = ApiService();

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Request failed';
  }

  /// Creates a DRAFT booking or returns existing (same post + assignment). POST 201 / 200.
  /// [direction] is 'EXPORT' or 'IMPORT'; [routeIndex] indexes the post's routes
  /// (-1 for the "Any Other Destination" negotiable catch-all).
  Future<Map<String, dynamic>> createOrGetBooking({
    required String postId,
    required String assignmentId,
    String? direction,
    int? routeIndex,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.vehicleBookings,
        data: {
          'postId': postId,
          'assignmentId': assignmentId,
          if (direction != null) 'direction': direction,
          if (routeIndex != null) 'routeIndex': routeIndex,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      if (data is! Map) throw Exception('Invalid response');
      final booking = data['booking'];
      if (booking is! Map) throw Exception('Invalid booking');
      return Map<String, dynamic>.from(booking);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final msg = _messageFromDio(e).toLowerCase();
        if (msg.contains('active booking')) {
          final existing = await _findDraftBookingForPost(postId);
          if (existing != null) return existing;
        }
      }
      if (kDebugMode) print('VehicleBookingService.createOrGetBooking: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<Map<String, dynamic>?> _findDraftBookingForPost(String postId) async {
    try {
      final response = await _api.get(
        ApiConfig.vehicleBookingsMine,
        queryParameters: {'status': 'DRAFT'},
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) return null;
      final data = body['data'];
      if (data is! Map) return null;
      final list = data['bookings'];
      if (list is! List) return null;
      for (final item in list) {
        if (item is! Map) continue;
        final p = item['postId'];
        final pid = p is Map ? p['_id']?.toString() ?? p['id']?.toString() : p?.toString();
        if (pid == postId) {
          return Map<String, dynamic>.from(item);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<MarketplaceConversation>> fetchConversations() async {
    try {
      final response = await _api.get(ApiConfig.vehicleBookingsConversations);
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      if (data is! Map) return [];
      final raw = data['conversations'];
      if (raw is! List) return [];
      final out = <MarketplaceConversation>[];
      for (final item in raw) {
        if (item is Map) {
          final c = MarketplaceConversation.fromJson(Map<String, dynamic>.from(item));
          if (c != null) out.add(c);
        }
      }
      return out;
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.fetchConversations: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> proposePrice({
    required String bookingId,
    required num proposedPrice,
    String? message,
  }) async {
    try {
      final response = await _api.put(
        ApiConfig.vehicleBookingProposePrice(bookingId),
        data: {
          'proposedPrice': proposedPrice,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.proposePrice: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> acceptProposal(String bookingId) async {
    try {
      final response = await _api.put(ApiConfig.vehicleBookingAcceptProposal(bookingId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.acceptProposal: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> declineProposal(String bookingId) async {
    try {
      final response = await _api.put(ApiConfig.vehicleBookingDeclineProposal(bookingId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.declineProposal: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> acceptBooking(String bookingId) async {
    try {
      final response = await _api.put(ApiConfig.vehicleBookingAccept(bookingId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.acceptBooking: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> rejectBooking(String bookingId, {String? reason}) async {
    try {
      final response = await _api.put(
        ApiConfig.vehicleBookingReject(bookingId),
        data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.rejectBooking: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    try {
      final response = await _api.delete(
        ApiConfig.vehicleBookingById(bookingId),
        data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.cancelBooking: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<List<MarketplaceMessage>> fetchMessages(
    String bookingId, {
    int page = 1,
    int limit = 100,
    String? afterMessageId,
    String? afterCreatedAt,
  }) async {
    try {
      final qp = <String, dynamic>{'limit': limit};
      if (afterMessageId != null && afterMessageId.isNotEmpty) {
        qp['afterMessageId'] = afterMessageId;
      } else if (afterCreatedAt != null && afterCreatedAt.isNotEmpty) {
        qp['afterCreatedAt'] = afterCreatedAt;
      } else {
        qp['page'] = page;
      }
      final response = await _api.get(
        ApiConfig.messagesBooking(bookingId),
        queryParameters: qp,
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      if (data is! Map) return [];
      final raw = data['messages'];
      if (raw is! List) return [];
      final out = <MarketplaceMessage>[];
      for (final item in raw) {
        if (item is Map) {
          final m = MarketplaceMessage.fromJson(Map<String, dynamic>.from(item));
          if (m != null) out.add(m);
        }
      }
      return out;
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.fetchMessages: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  /// Incremental fetch: messages with `createdAt` strictly after the anchor message.
  Future<List<MarketplaceMessage>> fetchMessagesAfter(
    String bookingId,
    String afterMessageId, {
    int limit = 100,
  }) =>
      fetchMessages(bookingId, afterMessageId: afterMessageId, limit: limit);

  /// Upload chat files (multipart). Same participant rules as send.
  Future<List<MarketplaceAttachment>> uploadChatAttachments({
    required String bookingId,
    required List<File> files,
  }) async {
    if (files.isEmpty) {
      throw Exception('No files to upload');
    }
    try {
      final form = FormData();
      form.fields.add(MapEntry('bookingId', bookingId));
      for (final f in files) {
        form.files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(
              f.path,
              filename: f.path.replaceAll('\\', '/').split('/').last,
            ),
          ),
        );
      }
      final response = await _api.postMultipart(
        ApiConfig.messagesUpload,
        formData: form,
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      if (data is! Map) return [];
      final raw = data['attachments'];
      if (raw is! List) return [];
      final out = <MarketplaceAttachment>[];
      for (final item in raw) {
        final a = MarketplaceAttachment.fromJson(item);
        if (a != null) out.add(a);
      }
      return out;
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.uploadChatAttachments: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  /// REST send (fallback when Socket.IO is unavailable).
  Future<MarketplaceMessage> sendMessageHttp({
    required String bookingId,
    required String content,
    String? messageType,
    num? proposedPrice,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.messages,
        data: {
          'bookingId': bookingId,
          'content': content,
          if (messageType != null) 'messageType': messageType,
          if (proposedPrice != null) 'proposedPrice': proposedPrice,
          if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
        },
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      if (data is! Map) throw Exception('Invalid response');
      final raw = data['message'];
      if (raw is! Map) throw Exception('Invalid message');
      final m = MarketplaceMessage.fromJson(Map<String, dynamic>.from(raw));
      if (m == null) throw Exception('Invalid message shape');
      return m;
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.sendMessageHttp: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<Map<String, dynamic>> fetchBookingDetail(String bookingId) async {
    try {
      final response = await _api.get(ApiConfig.vehicleBookingById(bookingId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
      final data = body['data'];
      if (data is! Map) throw Exception('Invalid response');
      final booking = data['booking'];
      if (booking is! Map) throw Exception('Invalid booking');
      return Map<String, dynamic>.from(booking);
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.fetchBookingDetail: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> markBookingReadAll(String bookingId) async {
    try {
      final response = await _api.post(ApiConfig.messagesBookingReadAll(bookingId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.markBookingReadAll: $e');
      throw Exception(_messageFromDio(e));
    }
  }

  /// Removes thread from this user's chat list on the server (booking unchanged).
  Future<void> hideConversationFromInbox(String bookingId) async {
    try {
      final response = await _api.patch(ApiConfig.vehicleBookingHideFromInbox(bookingId));
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed');
      }
    } on DioException catch (e) {
      if (kDebugMode) print('VehicleBookingService.hideConversationFromInbox: $e');
      throw Exception(_messageFromDio(e));
    }
  }
}

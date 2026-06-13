import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';
import '../models/support_ticket_category.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class SupportTicketModel {
  SupportTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.status,
    required this.unreadByTransporter,
    this.category = '',
    this.categoryDetail = '',
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.updatedAt,
    this.ratingScore,
    this.ratedAt,
    this.ratingComment = '',
  });

  final String id;
  final String ticketNumber;
  String subject;
  String status;
  String category;
  String categoryDetail;
  int unreadByTransporter;
  String lastMessagePreview;
  DateTime? lastMessageAt;
  DateTime? updatedAt;
  int? ratingScore;
  DateTime? ratedAt;
  String ratingComment;

  factory SupportTicketModel.fromJson(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id'])?.toString() ?? '';
    return SupportTicketModel(
      id: id,
      ticketNumber: j['ticketNumber']?.toString() ?? '',
      subject: j['subject']?.toString() ?? '',
      status: j['status']?.toString() ?? 'open',
      category: j['category']?.toString() ?? '',
      categoryDetail: j['categoryDetail']?.toString() ?? '',
      unreadByTransporter: _intField(j['unreadByTransporter']),
      lastMessagePreview: j['lastMessagePreview']?.toString() ?? '',
      lastMessageAt: _parseDate(j['lastMessageAt']),
      updatedAt: _parseDate(j['updatedAt']),
      ratingScore: j['ratingScore'] == null ? null : _intField(j['ratingScore']),
      ratedAt: _parseDate(j['ratedAt']),
      ratingComment: j['ratingComment']?.toString() ?? '',
    );
  }

  static int _intField(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  String get categoryLabel => SupportTicketCategory.labelForCode(category);

  void mergeTicketMap(Map<String, dynamic> t) {
    if (t['subject'] != null) subject = t['subject'].toString();
    if (t['status'] != null) status = t['status'].toString();
    if (t['category'] != null) category = t['category'].toString();
    if (t['categoryDetail'] != null) {
      categoryDetail = t['categoryDetail'].toString();
    }
    if (t['unreadByTransporter'] != null) {
      unreadByTransporter = _intField(t['unreadByTransporter']);
    }
    if (t['lastMessagePreview'] != null) {
      lastMessagePreview = t['lastMessagePreview'].toString();
    }
    final u = SupportTicketModel._parseDate(t['updatedAt']);
    if (u != null) updatedAt = u;
    final lm = SupportTicketModel._parseDate(t['lastMessageAt']);
    if (lm != null) lastMessageAt = lm;
    if (t.containsKey('ratingScore')) {
      final v = t['ratingScore'];
      ratingScore = v == null ? null : _intField(v);
    }
    if (t.containsKey('ratedAt')) {
      ratedAt = SupportTicketModel._parseDate(t['ratedAt']);
    }
    if (t['ratingComment'] != null) {
      ratingComment = t['ratingComment'].toString();
    }
  }

  bool get needsRating => status == 'resolved' && ratedAt == null;
}

class SupportMessageModel {
  SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.content,
    required this.createdAt,
    this.status = 'SENT',
    this.messageType = 'TEXT',
  });

  final String id;
  final String ticketId;
  final String senderType;
  final String content;
  final DateTime? createdAt;
  String status;
  final String messageType;

  factory SupportMessageModel.fromJson(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id'])?.toString() ?? '';
    return SupportMessageModel(
      id: id,
      ticketId: (j['ticketId'] ?? '').toString(),
      senderType: (j['senderType'] ?? '').toString(),
      content: (j['content'] ?? '').toString(),
      createdAt: SupportTicketModel._parseDate(j['createdAt']),
      status: (j['status'] ?? 'SENT').toString(),
      messageType: (j['messageType'] ?? 'TEXT').toString(),
    );
  }

  static SupportMessageModel? fromSocketEnvelope(Map<String, dynamic> envelope) {
    final msg = envelope['message'];
    if (msg is! Map) return null;
    final m = Map<String, dynamic>.from(msg);
    final senderType =
        (envelope['senderType'] ?? m['senderType'])?.toString() ?? 'transporter';
    final id = (m['_id'] ?? m['id'])?.toString();
    if (id == null || id.isEmpty) return null;
    return SupportMessageModel(
      id: id,
      ticketId: (envelope['ticketId'] ?? m['ticketId'])?.toString() ?? '',
      senderType: senderType,
      content: (m['content'] ?? '').toString(),
      createdAt: SupportTicketModel._parseDate(m['createdAt']),
      status: (m['status'] ?? 'SENT').toString(),
      messageType: (m['messageType'] ?? 'TEXT').toString(),
    );
  }

  bool get isSystem => senderType == 'system';
}

class SupportProvider extends ChangeNotifier {
  SupportProvider() {
    _socket.addSupportChatListener(_onSupportSocket);
    _socket.addReconnectedListener(_onReconnected);
  }

  static const _ratingDismissKeyPrefix = 'support_csat_dismiss_';

  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  List<SupportTicketModel> tickets = [];
  bool loadingTickets = false;
  String? ticketsError;

  final Map<String, List<SupportMessageModel>> _messages = {};
  final Map<String, bool> _loadingMessages = {};

  int get totalUnread =>
      tickets.fold<int>(0, (a, t) => a + t.unreadByTransporter);

  @override
  void dispose() {
    _socket.removeSupportChatListener(_onSupportSocket);
    _socket.removeReconnectedListener(_onReconnected);
    super.dispose();
  }

  void _onReconnected() {
    notifyListeners();
  }

  SupportTicketModel? ticketById(String id) {
    try {
      return tickets.firstWhere((x) => x.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isRatingDismissed(String ticketId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('$_ratingDismissKeyPrefix$ticketId') ?? false;
  }

  Future<void> dismissRatingSheet(String ticketId) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('$_ratingDismissKeyPrefix$ticketId', true);
  }

  /// Clears "Not now" preference so the user can open the CSAT sheet again (e.g. from the status bar).
  Future<void> clearRatingDismiss(String ticketId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_ratingDismissKeyPrefix$ticketId');
  }

  void _onSupportSocket(Map<String, dynamic> payload) {
    final event = payload['_event']?.toString();

    if (event == 'support:ticket:updated') {
      final ticketWrap = payload['ticket'];
      if (ticketWrap is Map) {
        _mergeTicket(Map<String, dynamic>.from(ticketWrap));
      }
      notifyListeners();
      return;
    }

    if (event == 'support:message:read') {
      final mid = payload['messageId']?.toString();
      final tid = payload['ticketId']?.toString();
      if (mid != null && tid != null && _messages[tid] != null) {
        for (final m in _messages[tid]!) {
          if (m.id == mid) {
            m.status = 'READ';
            break;
          }
        }
      }
      notifyListeners();
      return;
    }

    // support:message:new (no _event)
    final fromMsg = SupportMessageModel.fromSocketEnvelope(payload);
    if (fromMsg != null) {
      final list = _messages.putIfAbsent(fromMsg.ticketId, () => []);
      if (!list.any((x) => x.id == fromMsg.id)) {
        list.add(fromMsg);
        list.sort((a, b) {
          final ca = a.createdAt;
          final cb = b.createdAt;
          if (ca == null && cb == null) return 0;
          if (ca == null) return -1;
          if (cb == null) return 1;
          return ca.compareTo(cb);
        });
      }
      _bumpTicketPreview(fromMsg.ticketId, fromMsg.content);
      notifyListeners();
    }
  }

  void _bumpTicketPreview(String ticketId, String preview) {
    for (var i = 0; i < tickets.length; i++) {
      if (tickets[i].id == ticketId) {
        tickets[i].lastMessagePreview =
            preview.length > 120 ? '${preview.substring(0, 120)}…' : preview;
        break;
      }
    }
  }

  void _mergeTicket(Map<String, dynamic> t) {
    final id = (t['_id'] ?? t['id'])?.toString();
    if (id == null || id.isEmpty) return;
    final idx = tickets.indexWhere((x) => x.id == id);
    if (idx >= 0) {
      tickets[idx].mergeTicketMap(t);
      tickets.sort((a, b) {
        final ua = a.updatedAt;
        final ub = b.updatedAt;
        if (ua == null && ub == null) return 0;
        if (ua == null) return 1;
        if (ub == null) return -1;
        return ub.compareTo(ua);
      });
    } else {
      tickets.insert(0, SupportTicketModel.fromJson(t));
    }
  }

  Future<void> refreshTicket(String ticketId) async {
    try {
      final res = await _api.get(ApiConfig.supportTicketById(ticketId));
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final t = data['data']['ticket'];
        if (t is Map) {
          _mergeTicket(Map<String, dynamic>.from(t));
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('refreshTicket: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        print('refreshTicket: $e');
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchTickets() async {
    loadingTickets = true;
    ticketsError = null;
    notifyListeners();
    try {
      final res = await _api.get(ApiConfig.supportTickets);
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final list = (data['data']['tickets'] as List?) ?? [];
        tickets = list
            .map((e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        ticketsError = 'Could not load tickets';
      }
    } on DioException catch (e) {
      ticketsError = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? 'Network error')
          : 'Network error';
    } catch (e) {
      ticketsError = e.toString();
    } finally {
      loadingTickets = false;
      notifyListeners();
    }
  }

  Future<SupportTicketModel?> createTicket({
    required String subject,
    required String message,
    required String category,
    String categoryDetail = '',
    String priority = 'medium',
  }) async {
    try {
      final body = <String, dynamic>{
        'subject': subject,
        'message': message,
        'category': category,
        'priority': priority,
      };
      final detail = categoryDetail.trim();
      if (detail.isNotEmpty) {
        body['categoryDetail'] = detail;
      }
      final res = await _api.post(
        ApiConfig.supportTickets,
        data: body,
      );
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final t = data['data']['ticket'];
        if (t is Map) {
          final model = SupportTicketModel.fromJson(Map<String, dynamic>.from(t));
          tickets.removeWhere((x) => x.id == model.id);
          tickets.insert(0, model);
          final msg = data['data']['message'];
          if (msg is Map) {
            final m =
                SupportMessageModel.fromJson(Map<String, dynamic>.from(msg));
            _messages[model.id] = [m];
          }
          notifyListeners();
          return model;
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('createTicket: $e');
      }
      rethrow;
    }
    return null;
  }

  List<SupportMessageModel> messagesFor(String ticketId) =>
      _messages[ticketId] ?? [];

  Future<void> fetchMessages(String ticketId, {bool appendOlder = false}) async {
    if (_loadingMessages[ticketId] == true) return;
    _loadingMessages[ticketId] = true;
    notifyListeners();
    try {
      String? before;
      if (appendOlder && _messages[ticketId] != null && _messages[ticketId]!.isNotEmpty) {
        before = _messages[ticketId]!.first.id;
      }
      final q = <String, dynamic>{'limit': 50};
      if (before != null) q['before'] = before;
      final res = await _api.get(
        ApiConfig.supportTicketMessages(ticketId),
        queryParameters: q,
      );
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final list = (data['data']['messages'] as List?) ?? [];
        final incoming = list
            .map((e) => SupportMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (appendOlder && _messages[ticketId] != null) {
          final existing = _messages[ticketId]!.map((m) => m.id).toSet();
          for (final m in incoming) {
            if (!existing.contains(m.id)) {
              _messages[ticketId]!.insert(0, m);
            }
          }
          _messages[ticketId]!.sort((a, b) {
            final ca = a.createdAt;
            final cb = b.createdAt;
            if (ca == null || cb == null) return 0;
            return ca.compareTo(cb);
          });
        } else {
          _messages[ticketId] = incoming;
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('fetchMessages: $e');
      }
    } finally {
      _loadingMessages[ticketId] = false;
      notifyListeners();
    }
  }

  Future<void> sendMessageHttp(String ticketId, String content) async {
    await _api.post(
      ApiConfig.supportTicketMessages(ticketId),
      data: {'content': content},
    );
    await fetchTickets();
  }

  Future<void> submitTicketRating(
    String ticketId,
    int score,
    String? comment,
  ) async {
    await _api.post(
      ApiConfig.supportTicketRating(ticketId),
      data: {
        'score': score,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
    await refreshTicket(ticketId);
    await fetchMessages(ticketId);
    await fetchTickets();
  }

  bool sendMessageSocket(String ticketId, String content) {
    return _socket.sendSupportMessage(ticketId, content);
  }

  void joinRealtime(String ticketId) {
    _socket.joinSupportTicket(ticketId);
  }

  void leaveRealtime(String ticketId) {
    _socket.leaveSupportTicket(ticketId);
  }

  void emitTyping(String ticketId) => _socket.emitSupportTyping(ticketId);

  void markReadSocket(String messageId) => _socket.markSupportMessageRead(messageId);
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_url.dart';
import '../../data/models/marketplace_chat_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/marketplace_chat_provider.dart';
import '../../services/marketplace_message_cache.dart';
import '../../services/socket_service.dart';
import '../../services/vehicle_booking_service.dart';

class MarketplaceChatScreen extends StatefulWidget {
  const MarketplaceChatScreen({
    super.key,
    required this.bookingId,
    this.routeLabel,
    this.counterpartyLabel,
    this.counterpartyTransporterId,
  });

  final String bookingId;
  final String? routeLabel;
  final String? counterpartyLabel;
  final String? counterpartyTransporterId;

  @override
  State<MarketplaceChatScreen> createState() => _MarketplaceChatScreenState();
}

class _MarketplaceChatScreenState extends State<MarketplaceChatScreen> {
  final VehicleBookingService _api = VehicleBookingService();
  final SocketService _socket = SocketService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<MarketplaceMessage> _messages = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  Map<String, dynamic>? _bookingDetail;
  bool _bookingActionsBusy = false;
  Timer? _typingDebounce;
  Timer? _sendFallbackTimer;

  /// Coalesces overlapping syncs (e.g. reject + socket `booking:rejected`).
  Future<void>? _syncFromServerInFlight;
  /// Peer has this chat thread open (via [chat:peer:presence], not socket connect alone).
  bool _peerInThread = false;
  final List<File> _stagedAttachments = [];
  bool _uploadingAttachments = false;

  late void Function(Map<String, dynamic>) _socketListener;
  late void Function(Map<String, dynamic>) _presenceListener;
  late void Function(Map<String, dynamic>) _lifecycleListener;

  String? _actorId() {
    final u = context.read<AuthProvider>().user;
    return u?.transporterId ?? u?.id;
  }

  /// Resolves Mongo-style ids: ObjectId string, `{ _id }`, `{ $oid }`, etc.
  String? _refId(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final m = Map<dynamic, dynamic>.from(v);
      final oid = m[r'$oid'];
      if (oid != null) return oid.toString();
      return m['_id']?.toString() ?? m['id']?.toString();
    }
    return v.toString();
  }

  bool _sameActorId(String? a, String? b) {
    if (a == null || b == null) return false;
    return a.toLowerCase() == b.toLowerCase();
  }

  bool _sameProposalPrice(num? messagePrice, dynamic bookingPriceRaw) {
    if (messagePrice == null) return false;
    final bookingPrice = bookingPriceRaw is num
        ? bookingPriceRaw
        : num.tryParse('$bookingPriceRaw');
    if (bookingPrice == null) return false;
    return (messagePrice - bookingPrice).abs() < 1e-6;
  }

  Map<String, dynamic>? _canonicalLastPriceProposal(dynamic lp) {
    if (lp is! Map) return null;
    final m = Map<String, dynamic>.from(
      lp.map((k, v) => MapEntry(k.toString(), v)),
    );
    final id = _refId(m['proposedBy']);
    if (id != null) m['proposedBy'] = id;
    final pr = m['proposedPrice'];
    if (pr != null && pr is! num) {
      final n = num.tryParse('$pr');
      if (n != null) m['proposedPrice'] = n;
    }
    return m;
  }

  Map<String, dynamic> _normalizedBookingDetail(Map<String, dynamic> b) {
    final out = Map<String, dynamic>.from(b);
    final lp = _canonicalLastPriceProposal(out['lastPriceProposal']);
    if (lp != null) out['lastPriceProposal'] = lp;
    final ack = _refId(out['proposalAcknowledgedBy']);
    if (ack != null) out['proposalAcknowledgedBy'] = ack;
    return out;
  }

  Future<void> _loadConversationsNextFrame() async {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        c.complete();
        return;
      }
      try {
        await context.read<MarketplaceChatProvider>().loadConversations(
              silent: true,
            );
      } catch (_) {}
      c.complete();
    });
    return c.future;
  }

  String? _bookingStatus() => _bookingDetail?['status']?.toString();

  bool _statusAllowsNegotiation() {
    final s = _bookingStatus()?.toUpperCase() ?? '';
    return s == 'DRAFT' || s == 'REQUESTED' || s == 'NEGOTIATING';
  }

  bool _statusAllowsProposalActions() {
    final s = _bookingStatus()?.toUpperCase() ?? '';
    return s == 'REQUESTED' || s == 'NEGOTIATING';
  }

  bool _isLatestPriceProposal(MarketplaceMessage m) {
    if (m.messageType?.toUpperCase() != 'PRICE_PROPOSAL') return false;
    final lp = _bookingDetail?['lastPriceProposal'];
    if (lp is! Map) return false;
    final by = _refId(lp['proposedBy']);
    final pr = lp['proposedPrice'];
    final price = pr is num ? pr : num.tryParse('$pr');
    if (by == null || price == null || !_sameActorId(m.senderId, by)) {
      return false;
    }
    return _sameProposalPrice(m.proposedPrice, price);
  }

  bool _showIncomingProposalActions(MarketplaceMessage m, String? selfId) {
    if (selfId == null || _sameActorId(m.senderId, selfId)) return false;
    if (!_statusAllowsProposalActions()) return false;
    return _isLatestPriceProposal(m);
  }

  bool _isSeller(String? selfId) {
    if (selfId == null || _bookingDetail == null) return false;
    final sid = _refId(_bookingDetail!['sellerId']);
    return _sameActorId(sid, selfId);
  }

  bool _sellerCanConfirmBooking(String? selfId) {
    if (!_isSeller(selfId) || !_statusAllowsProposalActions()) return false;
    final lp = _bookingDetail?['lastPriceProposal'];
    if (lp is! Map) return false;
    final lastBy = _refId(lp['proposedBy']);
    final buyer = _refId(_bookingDetail!['buyerId']);
    final seller = _refId(_bookingDetail!['sellerId']);
    if (lastBy == null || buyer == null || seller == null) return false;
    final ack = _refId(_bookingDetail!['proposalAcknowledgedBy']);
    // Buyer proposed → seller must Accept first (API sets proposalAcknowledgedBy = seller).
    if (_sameActorId(lastBy, buyer)) {
      return _sameActorId(ack, seller);
    }
    // Seller proposed → buyer must Accept first (ack = buyer).
    return _sameActorId(ack, buyer);
  }

  bool _isTerminalBookingStatus() {
    final s = _bookingStatus()?.toUpperCase() ?? '';
    return s == 'REJECTED' || s == 'CANCELLED';
  }

  bool _showTripComplete() {
    final bs = _bookingStatus()?.toUpperCase() ?? '';
    if (bs == 'COMPLETED') return true;
    final trip = _bookingDetail?['tripId'];
    if (trip is Map) {
      final ts = trip['status']?.toString().toUpperCase() ?? '';
      return kMarketplaceClosedTripStatuses.contains(ts);
    }
    return false;
  }

  String? _bookingEndedBannerMessage() {
    switch (_bookingStatus()?.toUpperCase() ?? '') {
      case 'REJECTED':
        return 'This booking was rejected. Chat is read-only.';
      case 'CANCELLED':
        return 'This booking was cancelled. Chat is read-only.';
      default:
        return null;
    }
  }

  bool _sameAttachmentUrls(MarketplaceMessage a, MarketplaceMessage b) {
    final au = a.attachments.map((e) => e.url).toList()..sort();
    final bu = b.attachments.map((e) => e.url).toList()..sort();
    if (au.length != bu.length) return false;
    for (var i = 0; i < au.length; i++) {
      if (au[i] != bu[i]) return false;
    }
    return true;
  }

  bool _pendingMatchesServer(MarketplaceMessage local, MarketplaceMessage server) {
    if (!local.id.startsWith('local-')) return false;
    if (!_sameActorId(local.senderId, server.senderId)) return false;
    if (local.content != server.content) return false;
    return _sameAttachmentUrls(local, server);
  }

  bool _sellerCanReject(String? selfId) =>
      _isSeller(selfId) && _statusAllowsProposalActions();

  bool _buyerCanCancel(String? selfId) {
    if (selfId == null || _isSeller(selfId)) return false;
    final bid = _refId(_bookingDetail?['buyerId']);
    return _sameActorId(bid, selfId) && _statusAllowsNegotiation();
  }

  Future<void> _refreshBookingDetail() async {
    try {
      final b = await _api.fetchBookingDetail(widget.bookingId);
      if (!mounted) return;
      setState(() => _bookingDetail = _normalizedBookingDetail(b));
    } catch (_) {}
  }

  Future<void> _openNegotiateModal() async {
    final est = _bookingDetail?['estimatedPrice'];
    final listed = est is num ? est : num.tryParse('$est');
    final result = await showDialog<_NegotiateDialogResult>(
      context: context,
      builder: (ctx) => _NegotiatePriceDialog(referencePrice: listed),
    );
    if (result == null || !mounted) return;
    try {
      setState(() => _bookingActionsBusy = true);
      await _api.proposePrice(
        bookingId: widget.bookingId,
        proposedPrice: result.price,
        message: result.message,
      );
      await _refreshBookingDetail();
      await _syncFromServer();
      if (mounted) {
        await _loadConversationsNextFrame();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingActionsBusy = false);
    }
  }

  Future<void> _onAcceptProposal() async {
    try {
      setState(() => _bookingActionsBusy = true);
      await _api.acceptProposal(widget.bookingId);
      await _refreshBookingDetail();
      await _syncFromServer();
      if (mounted) {
        await _loadConversationsNextFrame();
      }
      if (!mounted) return;
      final self = _actorId();
      if (_isSeller(self)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sellerCanConfirmBooking(self)
                  ? 'Price accepted. Use "Confirm booking (create trip)" below to finish.'
                  : 'Price accepted.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You accepted the offer. The seller can confirm the booking to create the trip.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingActionsBusy = false);
    }
  }

  Future<void> _onDeclineProposal() async {
    try {
      setState(() => _bookingActionsBusy = true);
      await _api.declineProposal(widget.bookingId);
      await _refreshBookingDetail();
      await _syncFromServer();
      if (mounted) {
        await _loadConversationsNextFrame();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingActionsBusy = false);
    }
  }

  Future<void> _confirmBookingAsSeller() async {
    try {
      setState(() => _bookingActionsBusy = true);
      await _api.acceptBooking(widget.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking confirmed — trip created')),
      );
      await _refreshBookingDetail();
      await _syncFromServer();
      if (mounted) {
        await _loadConversationsNextFrame();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingActionsBusy = false);
    }
  }

  Future<void> _onRejectBooking() async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _RejectBookingDialog(),
    );
    if (reason == null || !mounted) return;
    try {
      setState(() => _bookingActionsBusy = true);
      await _api.rejectBooking(
        widget.bookingId,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking rejected')),
      );
      await _refreshBookingDetail();
      await _syncFromServer();
      if (mounted) {
        await _loadConversationsNextFrame();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingActionsBusy = false);
    }
  }

  Future<void> _onCancelBooking() async {
    final st = _bookingStatus()?.toUpperCase() ?? '';
    final isDraft = st == 'DRAFT';
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) => _CancelBookingDialog(isDraft: isDraft),
    );
    if (note == null || !mounted) return;
    try {
      setState(() => _bookingActionsBusy = true);
      await _api.cancelBooking(widget.bookingId, reason: note.isEmpty ? null : note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled')),
      );
      await _refreshBookingDetail();
      await _syncFromServer();
      if (mounted) {
        await _loadConversationsNextFrame();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingActionsBusy = false);
    }
  }

  Future<void> _handleBookingLifecycleRefresh() async {
    await _refreshBookingDetail();
    await _syncFromServer();
    if (mounted) {
      await _loadConversationsNextFrame();
    }
  }

  void _onBookingLifecycle(Map<String, dynamic> data) {
    final event = data['_event']?.toString();
    if (event != 'booking:rejected' &&
        event != 'booking:cancelled' &&
        event != 'booking:confirmed' &&
        event != 'booking:completed') {
      return;
    }
    final b = data['booking'];
    if (b is! Map) return;
    final bid = b['_id']?.toString() ?? b['id']?.toString();
    if (bid != widget.bookingId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_handleBookingLifecycleRefresh());
    });
  }

  MarketplaceMessage? _lastServerMessage() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (!_messages[i].id.startsWith('local-')) return _messages[i];
    }
    return null;
  }

  Future<void> _persistCache() async {
    final id = _actorId();
    if (id == null) return;
    await MarketplaceMessageCache.instance.putMessages(
      actorId: id,
      bookingId: widget.bookingId,
      messages: List<MarketplaceMessage>.from(_messages),
    );
  }

  @override
  void initState() {
    super.initState();
    _socketListener = _onChatSocket;
    _presenceListener = _onPeerPresence;
    _socket.addMarketplaceChatListener(_socketListener);
    _socket.addChatPeerPresenceListener(_presenceListener);
    _lifecycleListener = _onBookingLifecycle;
    _socket.addMarketplaceBookingLifecycleListener(_lifecycleListener);
    _socket.addMarketplaceChatErrorListener(_onMarketplaceSocketErrorFromServer);

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final actorId = _actorId();
    if (actorId != null) {
      final cached = await MarketplaceMessageCache.instance.getMessages(
        actorId: actorId,
        bookingId: widget.bookingId,
      );
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(cached);
          _loading = false;
        });
        _scrollToEnd();
      }
    }

    await _socket.connectUntilReady(timeout: const Duration(seconds: 12));
    if (!mounted) return;
    _socket.joinChatBooking(widget.bookingId);
    _socket.emitChatThreadJoin(widget.bookingId);
    await _syncFromServer();
    await _refreshBookingDetail();
  }

  /// Coalesces overlapping syncs (e.g. reject + socket `booking:rejected`).
  Future<void> _syncFromServer() {
    if (_syncFromServerInFlight != null) {
      return _syncFromServerInFlight!;
    }
    final f = _syncFromServerImpl();
    _syncFromServerInFlight = f;
    f.whenComplete(() {
      if (identical(_syncFromServerInFlight, f)) {
        _syncFromServerInFlight = null;
      }
    });
    return f;
  }

  Future<void> _syncFromServerImpl() async {
    final actorId = _actorId();
    if (!mounted) return;
    setState(() => _syncing = true);
    try {
      final anchor = _lastServerMessage();
      final List<MarketplaceMessage> incoming;
      if (anchor != null) {
        incoming = await _api.fetchMessagesAfter(widget.bookingId, anchor.id);
      } else {
        incoming = await _api.fetchMessages(widget.bookingId, limit: 100);
      }
      if (!mounted) return;
      final merged = MarketplaceMessageCache.mergeById(_messages, incoming);
      setState(() {
        _messages.clear();
        _messages.addAll(merged);
        _loading = false;
        _error = null;
      });
      if (actorId != null) {
        await MarketplaceMessageCache.instance.putMessages(
          actorId: actorId,
          bookingId: widget.bookingId,
          messages: merged,
        );
      }
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      if (_messages.isEmpty) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showSocketError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onMarketplaceSocketErrorFromServer(String msg) {
    _showSocketError(msg);
  }

  void _onPeerPresence(Map<String, dynamic> data) {
    final bid = data['bookingId']?.toString();
    if (bid != widget.bookingId) return;
    final peer = widget.counterpartyTransporterId;
    if (peer == null || peer.isEmpty) return;
    final uid = data['userId']?.toString();
    if (uid != peer) return;
    final active = data['state']?.toString() == 'active';
    if (!mounted) return;
    setState(() => _peerInThread = active);
  }

  @override
  void dispose() {
    _sendFallbackTimer?.cancel();
    _typingDebounce?.cancel();
    _socket.emitChatThreadLeave(widget.bookingId);
    _socket.removeMarketplaceChatErrorListener(_onMarketplaceSocketErrorFromServer);
    _socket.removeMarketplaceChatListener(_socketListener);
    _socket.removeChatPeerPresenceListener(_presenceListener);
    _socket.removeMarketplaceBookingLifecycleListener(_lifecycleListener);
    _socket.leaveChatBooking(widget.bookingId);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  /// Chat events use top-level [bookingId]; [booking:price-proposed] / [booking:requested] nest under `booking`.
  String? _socketPayloadBookingId(Map<String, dynamic> payload) {
    final top = payload['bookingId']?.toString();
    if (top != null && top.isNotEmpty) return top;
    final b = payload['booking'];
    if (b is Map) {
      final id = b['_id'] ?? b['id'];
      final s = id?.toString();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  void _applyBookingDetailFromSocketMap(Map<dynamic, dynamic> raw) {
    if (!mounted) return;
    setState(() {
      final detail = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      _bookingDetail = _normalizedBookingDetail(detail);
    });
  }

  void _onChatSocket(Map<String, dynamic> payload) {
    final bid = _socketPayloadBookingId(payload);
    if (bid != widget.bookingId) return;

    final event = payload['_event']?.toString();
    if (event == 'chat:typing') return;

    if (event == 'booking:price-proposed') {
      final b = payload['booking'];
      if (b is Map) {
        _applyBookingDetailFromSocketMap(Map<dynamic, dynamic>.from(b));
      }
      return;
    }

    if (event == 'booking:requested') {
      unawaited(_refreshBookingDetail());
      return;
    }

    if (event == 'chat:message:read') {
      final mid = payload['messageId']?.toString();
      final readAtStr = payload['readAt']?.toString();
      if (mid == null) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == mid);
        if (i >= 0) {
          _messages[i] = MarketplaceMessage(
            id: _messages[i].id,
            bookingId: _messages[i].bookingId,
            content: _messages[i].content,
            messageType: _messages[i].messageType,
            proposedPrice: _messages[i].proposedPrice,
            status: 'READ',
            readAt: readAtStr != null ? DateTime.tryParse(readAtStr) : DateTime.now(),
            createdAt: _messages[i].createdAt,
            senderId: _messages[i].senderId,
            senderName: _messages[i].senderName,
            receiverId: _messages[i].receiverId,
            attachments: _messages[i].attachments,
          );
        }
      });
      unawaited(_persistCache());
      return;
    }

    final raw = payload['message'];
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      map['bookingId'] ??= payload['bookingId']?.toString();
      final m = MarketplaceMessage.fromJson(map);
      if (m == null) return;
      if (_messages.any((x) => x.id == m.id)) return;
      final self = _actorId();
      setState(() {
        if (self != null) {
          final hadLocal = _messages.any((x) => _pendingMatchesServer(x, m));
          if (hadLocal) _sendFallbackTimer?.cancel();
          _messages.removeWhere((x) => _pendingMatchesServer(x, m));
        }
        _messages.add(m);
        _messages.sort((a, b) {
          final ca = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ca.compareTo(cb);
        });
      });
      _scrollToEnd();
      unawaited(_persistCache());
      if (m.messageType?.toUpperCase() == 'PRICE_PROPOSAL' ||
          m.messageType?.toUpperCase() == 'SYSTEM' ||
          m.messageType?.toUpperCase() == 'ATTACHMENT' ||
          m.attachments.isNotEmpty) {
        unawaited(_refreshBookingDetail());
      }
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final auth = context.read<AuthProvider>().user;
          final s = auth?.transporterId ?? auth?.id;
          final shouldMarkRead = s != null &&
              !m.isRead &&
              (m.receiverId != null
                  ? m.receiverId == s
                  : m.senderId != s);
          if (shouldMarkRead) {
            _socket.markChatMessageRead(m.id);
          }
          await context.read<MarketplaceChatProvider>().loadConversations(
                silent: true,
              );
        } catch (_) {}
      });
    }
  }

  Future<void> _openAttachmentUrl(String relativeOrAbsolute) async {
    final url = resolveUploadUrl(ApiConfig.baseUrl, relativeOrAbsolute);
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await canLaunchUrl(uri);
      if (ok) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  Future<void> _openImageFullscreen(String relativeOrAbsolute) async {
    final url = resolveUploadUrl(ApiConfig.baseUrl, relativeOrAbsolute);
    if (url.isEmpty || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => _ChatImageViewerPage(imageUrl: url),
      ),
    );
  }

  static const int _kMaxChatAttachments = 5;

  void _showAttachmentSheet() {
    if (_isTerminalBookingStatus() || _bookingActionsBusy) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickFromCamera());
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickFromGallery());
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickDocuments());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addStagedFiles(List<File> files) {
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        if (_stagedAttachments.length >= _kMaxChatAttachments) break;
        _stagedAttachments.add(f);
      }
    });
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    if (x == null) return;
    _addStagedFiles([File(x.path)]);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final list = await picker.pickMultiImage(imageQuality: 88);
    if (list.isEmpty) return;
    final files = <File>[];
    for (final x in list) {
      if (files.length + _stagedAttachments.length >= _kMaxChatAttachments) break;
      files.add(File(x.path));
    }
    _addStagedFiles(files);
  }

  Future<void> _pickDocuments() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (res == null) return;
    final files = <File>[];
    for (final f in res.files) {
      if (files.length + _stagedAttachments.length >= _kMaxChatAttachments) break;
      final p = f.path;
      if (p != null) files.add(File(p));
    }
    _addStagedFiles(files);
  }

  Future<void> _sendStagedAttachments(String caption) async {
    final self = _actorId();
    if (self == null || _stagedAttachments.isEmpty) return;
    final toSend = List<File>.from(_stagedAttachments);
    _textCtrl.clear();
    setState(() {
      _stagedAttachments.clear();
      _uploadingAttachments = true;
    });

    List<MarketplaceAttachment> uploaded;
    try {
      uploaded = await _api.uploadChatAttachments(
        bookingId: widget.bookingId,
        files: toSend,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _stagedAttachments.insertAll(0, toSend);
          _uploadingAttachments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }

    if (uploaded.isEmpty) {
      if (mounted) {
        setState(() {
          _stagedAttachments.insertAll(0, toSend);
          _uploadingAttachments = false;
        });
      }
      return;
    }

    final attMaps = uploaded.map((a) => a.toSendMap()).toList();
    final pendingId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final pending = MarketplaceMessage(
      id: pendingId,
      bookingId: widget.bookingId,
      content: caption,
      messageType: 'ATTACHMENT',
      status: 'SENT',
      createdAt: DateTime.now().toUtc(),
      senderId: self,
      senderName: null,
      attachments: uploaded,
    );
    if (mounted) {
      setState(() {
        _uploadingAttachments = false;
        _messages.add(pending);
      });
      unawaited(_persistCache());
    }

    final socketSent = _socket.sendChatMessage(
      widget.bookingId,
      caption,
      messageType: 'ATTACHMENT',
      attachments: attMaps,
    );
    if (socketSent) {
      _sendFallbackTimer?.cancel();
      _sendFallbackTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_messages.any((m) => m.id == pendingId)) {
          unawaited(_flushPendingViaHttp(pendingId, caption, attachments: attMaps));
        }
      });
    } else {
      unawaited(_flushPendingViaHttp(pendingId, caption, attachments: attMaps));
    }
  }

  void _send() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty && _stagedAttachments.isEmpty) return;

    if (_stagedAttachments.isNotEmpty) {
      unawaited(_sendStagedAttachments(t));
      return;
    }

    _textCtrl.clear();

    final self = _actorId();
    if (self == null) return;

    final pendingId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final pending = MarketplaceMessage(
      id: pendingId,
      bookingId: widget.bookingId,
      content: t,
      messageType: 'TEXT',
      status: 'SENT',
      createdAt: DateTime.now().toUtc(),
      senderId: self,
      senderName: null,
    );
    setState(() => _messages.add(pending));
    unawaited(_persistCache());

    final socketSent = _socket.sendChatMessage(widget.bookingId, t);
    if (socketSent) {
      _sendFallbackTimer?.cancel();
      _sendFallbackTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_messages.any((m) => m.id == pendingId)) {
          unawaited(_flushPendingViaHttp(pendingId, t));
        }
      });
    } else {
      unawaited(_flushPendingViaHttp(pendingId, t));
    }
  }

  Future<void> _flushPendingViaHttp(
    String pendingId,
    String content, {
    List<Map<String, dynamic>>? attachments,
  }) async {
    if (!mounted) return;
    try {
      final m = await _api.sendMessageHttp(
        bookingId: widget.bookingId,
        content: content,
        messageType: attachments != null && attachments.isNotEmpty ? 'ATTACHMENT' : null,
        attachments: attachments,
      );
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((x) => x.id == pendingId);
        if (i >= 0) {
          _messages[i] = m;
        } else if (!_messages.any((x) => x.id == m.id)) {
          _messages.add(m);
        }
        _messages.sort((a, b) {
          final ca = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ca.compareTo(cb);
        });
      });
      await _persistCache();
      if (mounted) {
        await _loadConversationsNextFrame();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((x) => x.id == pendingId));
      await _persistCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    }
  }

  void _onTyping() {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 400), () {
      _socket.emitChatTyping(widget.bookingId);
    });
  }

  Widget _buildMessageAttachments(MarketplaceMessage m, bool mine, TextTheme textTheme) {
    if (m.attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final a in m.attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: a.isImage
                ? GestureDetector(
                    onTap: () => unawaited(_openImageFullscreen(a.url)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 240),
                        child: Image.network(
                          resolveUploadUrl(ApiConfig.baseUrl, a.url),
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, prog) {
                            if (prog == null) return child;
                            return const SizedBox(
                              width: 120,
                              height: 120,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Icon(Icons.broken_image_outlined, size: 40),
                          ),
                        ),
                      ),
                    ),
                  )
                : Material(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => unawaited(_openAttachmentUrl(a.url)),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_rounded, color: AppColors.primary),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                a.originalName ?? 'Attachment',
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>().user;
    final selfId = auth?.transporterId ?? auth?.id;
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.counterpartyLabel ?? 'Chat',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (widget.routeLabel != null)
              Text(
                widget.routeLabel!,
                style: theme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _peerInThread ? Colors.green : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _peerInThread ? 'Online' : 'Away',
                    style: theme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_syncing) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _syncFromServer, child: const Text('Retry')),
              ],
            ),
          if (_bookingEndedBannerMessage() != null)
            Material(
              color: AppColors.offWhite,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _bookingEndedBannerMessage()!,
                        style: theme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showTripComplete())
            Material(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade800, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Trip complete. You can still use this chat if you need anything else.',
                        style: theme.bodyMedium?.copyWith(color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _syncFromServer,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine =
                            selfId != null && _sameActorId(m.senderId, selfId);
                        final isSystem = m.messageType?.toUpperCase() == 'SYSTEM';
                        if (isSystem) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.9,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.offWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.dividerGrey),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 20,
                                    color: AppColors.primary.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      m.content,
                                      textAlign: TextAlign.center,
                                      style: theme.bodySmall?.copyWith(
                                        color: AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                _buildMessageAttachments(m, mine, theme),
                                if (m.content.trim().isNotEmpty)
                                  Text(
                                    m.content,
                                    style: theme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                                  ),
                                if (m.proposedPrice != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '₹${m.proposedPrice}',
                                      style: theme.labelLarge?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (_showIncomingProposalActions(m, selfId)) ...[
                                  const SizedBox(height: 10),
                                  Material(
                                    type: MaterialType.transparency,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 48,
                                            child: OutlinedButton(
                                              onPressed: _bookingActionsBusy
                                                  ? null
                                                  : () {
                                                      unawaited(_onDeclineProposal());
                                                    },
                                              child: const Text('Decline'),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SizedBox(
                                            height: 48,
                                            child: FilledButton(
                                              onPressed: _bookingActionsBusy
                                                  ? null
                                                  : () {
                                                      unawaited(_onAcceptProposal());
                                                    },
                                              child: const Text('Accept'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (m.createdAt != null)
                                      Text(
                                        _timeFmt(m.createdAt!),
                                        style: theme.labelSmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    if (mine) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        m.isRead ? Icons.done_all : Icons.done,
                                        size: 14,
                                        color: m.isRead ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_sellerCanConfirmBooking(selfId))
            Material(
              color: AppColors.offWhite,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _bookingActionsBusy ? null : _confirmBookingAsSeller,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirm booking (create trip)'),
                  ),
                ),
              ),
            ),
          if (_sellerCanReject(selfId) || _buyerCanCancel(selfId))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_sellerCanReject(selfId))
                    OutlinedButton.icon(
                      onPressed: _bookingActionsBusy ? null : _onRejectBooking,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject booking'),
                    ),
                  if (_buyerCanCancel(selfId)) ...[
                    if (_sellerCanReject(selfId)) const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _bookingActionsBusy ? null : _onCancelBooking,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel booking'),
                    ),
                  ],
                ],
              ),
            ),
          if (_statusAllowsNegotiation())
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _bookingActionsBusy ? null : _openNegotiateModal,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Propose price'),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_uploadingAttachments)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_stagedAttachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _stagedAttachments.length; i++)
                          InputChip(
                            label: Text(
                              _stagedAttachments[i].path.replaceAll('\\', '/').split('/').last,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onDeleted: _isTerminalBookingStatus() || _uploadingAttachments
                                ? null
                                : () => setState(() => _stagedAttachments.removeAt(i)),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _isTerminalBookingStatus() ||
                                _bookingActionsBusy ||
                                _uploadingAttachments
                            ? null
                            : _showAttachmentSheet,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        color: AppColors.primary,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          onChanged: (_) {
                            setState(() {});
                            _onTyping();
                          },
                          readOnly: _isTerminalBookingStatus(),
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _isTerminalBookingStatus()
                                ? 'Chat closed'
                                : (_stagedAttachments.isNotEmpty
                                    ? 'Caption (optional)'
                                    : 'Message'),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isTerminalBookingStatus() ||
                                _bookingActionsBusy ||
                                _uploadingAttachments ||
                                (_textCtrl.text.trim().isEmpty && _stagedAttachments.isEmpty)
                            ? null
                            : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeFmt(DateTime d) {
    final t = TimeOfDay.fromDateTime(d.toLocal());
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatImageViewerPage extends StatelessWidget {
  const _ChatImageViewerPage({required this.imageUrl});

  final String imageUrl;

  Future<void> _save(BuildContext context) async {
    try {
      var allowed = await Gal.hasAccess(toAlbum: true);
      if (!context.mounted) return;
      if (!allowed) {
        allowed = await Gal.requestAccess(toAlbum: true);
      }
      if (!context.mounted) return;
      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo library permission is required to save')),
        );
        return;
      }
      final dio = Dio();
      final resp = await dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!context.mounted) return;
      final data = resp.data;
      if (data == null) {
        throw Exception('Empty image response');
      }
      await Gal.putImageBytes(
        Uint8List.fromList(data),
        name: 'porttivo_chat_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to gallery')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => unawaited(_save(context)),
            tooltip: 'Save to gallery',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () async {
              final uri = Uri.tryParse(imageUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}

class _NegotiateDialogResult {
  const _NegotiateDialogResult({required this.price, this.message});
  final num price;
  final String? message;
}

class _RejectBookingDialog extends StatefulWidget {
  const _RejectBookingDialog();

  @override
  State<_RejectBookingDialog> createState() => _RejectBookingDialogState();
}

class _RejectBookingDialogState extends State<_RejectBookingDialog> {
  late final TextEditingController _reasonCtrl;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject booking?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The buyer will be notified and the vehicle slot will be released.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reasonCtrl.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _CancelBookingDialog extends StatefulWidget {
  const _CancelBookingDialog({required this.isDraft});

  final bool isDraft;

  @override
  State<_CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<_CancelBookingDialog> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isDraft ? 'Cancel inquiry?' : 'Cancel booking request?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isDraft
                ? 'Your inquiry will close and the vehicle slot will be released.'
                : 'The seller will be notified and the vehicle slot will be released.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _noteCtrl.text.trim()),
          child: const Text('Cancel booking'),
        ),
      ],
    );
  }
}

class _NegotiatePriceDialog extends StatefulWidget {
  const _NegotiatePriceDialog({this.referencePrice});

  final num? referencePrice;

  @override
  State<_NegotiatePriceDialog> createState() => _NegotiatePriceDialogState();
}

class _NegotiatePriceDialogState extends State<_NegotiatePriceDialog> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _noteCtrl;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final p = num.tryParse(_priceCtrl.text.trim());
    if (p == null || p <= 0) {
      setState(() => _priceError = 'Enter a valid amount');
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.pop(
      context,
      _NegotiateDialogResult(
        price: p,
        message: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listed = widget.referencePrice;
    return AlertDialog(
      title: const Text('Propose price'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (listed != null)
              Text(
                'Reference: ₹$listed',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your offer (₹)',
                border: const OutlineInputBorder(),
                errorText: _priceError,
              ),
              onChanged: (_) {
                if (_priceError != null) {
                  setState(() => _priceError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Send'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/razorpay_payment_link_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/quote_service.dart';
import '../../services/razorpay_payment_link_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/collect_extra_charges_sheet.dart';
import '../../widgets/payment_request_card.dart';

/// Lightweight quote-scoped chat ("Chat with Requester" / "Chat" from a quote).
/// Reuses the transporter room push + `chat:message:new` socket event, filtered
/// by quoteId.
class QuoteChatScreen extends StatefulWidget {
  const QuoteChatScreen({
    super.key,
    required this.quoteId,
    this.title,
    this.counterpartyTransporterId,
    this.openCollectPayment = false,
    this.collectReferenceType,
    this.collectReferenceId,
  });

  final String quoteId;
  final String? title;
  final String? counterpartyTransporterId;
  final bool openCollectPayment;
  final String? collectReferenceType;
  final String? collectReferenceId;

  @override
  State<QuoteChatScreen> createState() => _QuoteChatScreenState();
}

class _QuoteMessage {
  _QuoteMessage({
    required this.id,
    required this.content,
    required this.mine,
    this.senderId,
    this.senderName,
    this.createdAt,
  });
  final String id;
  final String content;
  final bool mine;
  final String? senderId;
  final String? senderName;
  final DateTime? createdAt;
}

class _QuoteChatScreenState extends State<QuoteChatScreen> {
  final QuoteService _service = QuoteService();
  final RazorpayPaymentLinkService _paymentLinks = RazorpayPaymentLinkService();
  final SocketService _socket = SocketService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_QuoteMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _collectBusy = false;
  bool _autoCollectOpened = false;
  String? _myId;

  late final void Function(Map<String, dynamic>) _chatListener;

  @override
  void initState() {
    super.initState();
    _chatListener = _onSocketMessage;
    _socket.addMarketplaceChatListener(_chatListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u = context.read<AuthProvider>().user;
      _myId = u?.transporterId ?? u?.id;
      _load();
    });
  }

  @override
  void dispose() {
    _socket.removeMarketplaceChatListener(_chatListener);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String? _idOf(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['id']?.toString() ?? v['_id']?.toString();
    return v.toString();
  }

  _QuoteMessage? _parse(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['_id']?.toString();
    if (id == null || id.isEmpty) return null;
    final sender = json['senderId'];
    final senderId = _idOf(sender);
    String? senderName;
    if (sender is Map) senderName = sender['name']?.toString();
    return _QuoteMessage(
      id: id,
      content: json['content']?.toString() ?? '',
      mine: senderId != null && _myId != null &&
          senderId.toLowerCase() == _myId!.toLowerCase(),
      senderId: senderId,
      senderName: senderName,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Future<void> _load() async {
    try {
      final raw = await _service.fetchMessages(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(raw.map(_parse).whereType<_QuoteMessage>());
        _loading = false;
      });
      _scrollToBottom();
      if (widget.openCollectPayment && !_autoCollectOpened) {
        _autoCollectOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _collectExtraCharges();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showUserErrorSnackBar(context, e);
    }
  }

  void _onSocketMessage(Map<String, dynamic> payload) {
    if (!mounted) return;
    final qid = payload['quoteId']?.toString();
    if (qid != widget.quoteId) return;
    final msg = payload['message'];
    if (msg is! Map) return;
    final parsed = _parse(Map<String, dynamic>.from(msg));
    if (parsed == null) return;
    if (_messages.any((m) => m.id == parsed.id)) return;
    setState(() => _messages.add(parsed));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String? _counterpartyId() {
    final explicit = widget.counterpartyTransporterId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    for (final m in _messages.reversed) {
      if (!m.mine && m.senderId != null && m.senderId!.isNotEmpty) {
        return m.senderId;
      }
    }
    return null;
  }

  Future<int?> _pendingExtraChargeMessageIndex() async {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final parsed = ExtraChargePaymentRequest.tryParse(_messages[i].content);
      if (parsed == null) continue;
      try {
        final status = await _paymentLinks.getStatus(parsed.recordId);
        if (status.isCreated) return i;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _collectExtraCharges() async {
    if (_collectBusy) return;
    setState(() => _collectBusy = true);
    try {
      final pendingIndex = await _pendingExtraChargeMessageIndex();
      if (!mounted) return;
      if (pendingIndex != null) {
        showUserErrorSnackBar(
          context,
          'A payment link is already waiting. Ask the other transporter to pay it, or cancel it first.',
        );
        return;
      }

      final result = await CollectExtraChargesSheet.show(context);
      if (result == null || !mounted) return;

      final payerId = _counterpartyId();
      if (payerId == null || payerId.isEmpty) {
        showUserErrorSnackBar(
          context,
          'Could not find the other transporter for this chat.',
        );
        return;
      }

      final created = await _paymentLinks.create(
        amount: result.amount,
        description: result.description,
        referenceType: widget.collectReferenceType ?? 'QUOTE',
        referenceId: widget.collectReferenceId ?? widget.quoteId,
        payerTransporterId: payerId,
      );
      if (!mounted) return;

      final body = ExtraChargePaymentRequest.encode(
        amount: created.amount,
        description: result.description,
        shortUrl: created.shortUrl!,
        recordId: created.id,
      );
      await _sendContent(body);
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _collectBusy = false);
    }
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _textCtrl.clear();
    await _sendContent(text);
  }

  Future<void> _sendContent(String text) async {
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _service.sendMessage(widget.quoteId, text);
      if (sent != null) {
        final parsed = _parse(sent);
        if (parsed != null && !_messages.any((m) => m.id == parsed.id)) {
          setState(() => _messages.add(parsed));
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(widget.title ?? 'Chat'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Collect extra charges',
            onPressed: _collectBusy ? null : _collectExtraCharges,
            icon: const Icon(Icons.payments_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Say hello 👋',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _bubble(_messages[i]),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _collectBusy ? null : _collectExtraCharges,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Collect extra charges'),
              ),
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(_QuoteMessage m) {
    final extraCharge = ExtraChargePaymentRequest.tryParse(m.content);
    final align = m.mine ? Alignment.centerRight : Alignment.centerLeft;
    final color = extraCharge != null
        ? AppColors.card
        : (m.mine ? AppColors.primary : AppColors.card);
    final textColor = extraCharge != null
        ? AppColors.textPrimary
        : (m.mine ? Colors.white : AppColors.textPrimary);
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: m.mine && extraCharge == null
              ? null
              : Border.all(color: AppColors.dividerGrey),
        ),
        child: Column(
          crossAxisAlignment:
              m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (extraCharge != null)
              PaymentRequestCard(request: extraCharge, isCreator: m.mine)
            else
              Text(m.content, style: TextStyle(color: textColor)),
            if (m.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(m.createdAt!.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: extraCharge != null || !m.mine
                      ? AppColors.textMuted
                      : Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.dividerGrey)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: AppColors.offWhite,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

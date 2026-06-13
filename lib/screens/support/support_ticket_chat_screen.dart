import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/support_provider.dart';
import '../../widgets/support_category_badge.dart';
import '../../services/socket_service.dart';

class SupportTicketChatScreen extends StatefulWidget {
  const SupportTicketChatScreen({
    super.key,
    required this.ticketId,
    required this.subject,
    required this.ticketNumber,
    this.categoryCode = '',
    this.categoryDetail = '',
  });

  final String ticketId;
  final String subject;
  final String ticketNumber;
  final String categoryCode;
  final String categoryDetail;

  @override
  State<SupportTicketChatScreen> createState() => _SupportTicketChatScreenState();
}

class _SupportTicketChatScreenState extends State<SupportTicketChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _ratingSheetOpen = false;
  SupportProvider? _support;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<SupportProvider>();
    if (_support == null) {
      _support = s;
      s.addListener(_onSupportProviderChanged);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final support = _support;
      if (support == null) return;
      await SocketService().connect();
      support.joinRealtime(widget.ticketId);
      await support.refreshTicket(widget.ticketId);
      await support.fetchMessages(widget.ticketId);
      if (!mounted) return;
      _markAdminMessagesRead(support);
      _scrollToEnd();
      await _offerRatingIfNeeded();
    });
  }

  void _onSupportProviderChanged() {
    unawaited(_offerRatingIfNeeded());
  }

  Future<void> _offerRatingIfNeeded() async {
    if (!mounted) return;
    final support = context.read<SupportProvider>();
    final t = support.ticketById(widget.ticketId);
    if (t == null || !t.needsRating) return;
    if (_ratingSheetOpen) return;
    if (await support.isRatingDismissed(widget.ticketId)) return;
    _ratingSheetOpen = true;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _RatingBottomSheet(
        ticketId: widget.ticketId,
        support: support,
        onNotNow: () => support.dismissRatingSheet(widget.ticketId),
      ),
    );
    if (mounted) {
      setState(() => _ratingSheetOpen = false);
    } else {
      _ratingSheetOpen = false;
    }
  }

  Future<void> _openRatingSheetExplicit() async {
    final support = context.read<SupportProvider>();
    await support.clearRatingDismiss(widget.ticketId);
    if (!mounted) return;
    if (_ratingSheetOpen) return;
    final t = support.ticketById(widget.ticketId);
    if (t == null || !t.needsRating) return;
    _ratingSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _RatingBottomSheet(
        ticketId: widget.ticketId,
        support: support,
        onNotNow: () => support.dismissRatingSheet(widget.ticketId),
      ),
    );
    if (mounted) {
      setState(() => _ratingSheetOpen = false);
    } else {
      _ratingSheetOpen = false;
    }
  }

  void _markAdminMessagesRead(SupportProvider support) {
    for (final m in support.messagesFor(widget.ticketId)) {
      if (m.senderType == 'admin' && m.status != 'READ') {
        support.markReadSocket(m.id);
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    final support = _support;
    if (support != null) {
      support.removeListener(_onSupportProviderChanged);
      try {
        support.leaveRealtime(widget.ticketId);
      } catch (_) {}
    }
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    final support = context.read<SupportProvider>();
    try {
      final ok = support.sendMessageSocket(widget.ticketId, content);
      if (!ok) {
        await support.sendMessageHttp(widget.ticketId, content);
        await support.fetchMessages(widget.ticketId);
      }
      _text.clear();
      if (mounted) _scrollToEnd();
    } on DioException catch (e) {
      final m = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? 'Send failed')
          : 'Send failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _systemLabel(SupportMessageModel m) {
    switch (m.messageType) {
      case 'SYSTEM_RATING_THANKS':
        return 'Thanks';
      case 'SYSTEM_STATUS':
      default:
        return 'Update';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.ticketNumber,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (widget.categoryCode.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: SupportCategoryBadge(
                  categoryCode: widget.categoryCode,
                  categoryDetail: widget.categoryDetail,
                  compact: true,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Consumer<SupportProvider>(
            builder: (context, support, _) {
              final t = support.ticketById(widget.ticketId);
              final status = t?.status ?? 'open';
              final cat = t?.category.isNotEmpty == true
                  ? t!.category
                  : widget.categoryCode;
              final catDetail = t?.categoryDetail.isNotEmpty == true
                  ? t!.categoryDetail
                  : widget.categoryDetail;
              return Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      if (cat.isNotEmpty) ...[
                        SupportCategoryBadge(
                          categoryCode: cat,
                          categoryDetail: catDetail,
                          compact: true,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(status),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      if (t != null && t.needsRating) ...[
                        const Spacer(),
                        TextButton(
                          onPressed: _openRatingSheetExplicit,
                          child: const Text('Rate'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Consumer<SupportProvider>(
              builder: (context, support, _) {
                final msgs = support.messagesFor(widget.ticketId);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markAdminMessagesRead(support);
                  if (msgs.isNotEmpty) _scrollToEnd();
                });
                if (msgs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    if (m.isSystem) {
                      return Align(
                        alignment: Alignment.center,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.support_agent,
                                    size: 18,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _systemLabel(m),
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(m.content, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      );
                    }
                    final mine = m.senderType == 'transporter';
                    final bg = mine
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.white;
                    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
                    return Align(
                      alignment: align,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine ? 'You' : 'Support',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(m.content),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Consumer<SupportProvider>(
            builder: (context, support, _) {
              final t = support.ticketById(widget.ticketId);
              final resolved = t?.status == 'resolved';
              if (resolved) {
                return Material(
                  elevation: 8,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        'This ticket is resolved. You cannot send more messages here. '
                        'Open a new ticket from Support if you need further help.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }
              return Material(
                elevation: 8,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Message…',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) {
                              context.read<SupportProvider>().emitTyping(widget.ticketId);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RatingBottomSheet extends StatefulWidget {
  const _RatingBottomSheet({
    required this.ticketId,
    required this.support,
    required this.onNotNow,
  });

  final String ticketId;
  final SupportProvider support;
  final Future<void> Function() onNotNow;

  @override
  State<_RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<_RatingBottomSheet> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.support.submitTicketRating(
        widget.ticketId,
        _stars,
        _comment.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      final m = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? 'Could not submit')
          : 'Could not submit';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How was your support experience?',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final n = i + 1;
                  final filled = n <= _stars;
                  return IconButton(
                    iconSize: 36,
                    onPressed: _busy ? null : () => setState(() => _stars = n),
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled ? Colors.amber.shade700 : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                maxLines: 3,
                maxLength: 500,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Optional comment',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _stars == 0 || _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await widget.onNotNow();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

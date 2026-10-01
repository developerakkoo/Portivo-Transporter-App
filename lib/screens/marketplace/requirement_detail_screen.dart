import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/quote_model.dart';
import '../../data/models/requirement_model.dart';
import '../../services/quote_service.dart';
import '../../services/requirement_service.dart';
import 'quote_chat_screen.dart';

/// Requester view of a single inquiry: summary + "Quotes Received" with
/// Chat / Counter / Select actions, and an Awarded state once selected.
class RequirementDetailScreen extends StatefulWidget {
  const RequirementDetailScreen({super.key, required this.requirementId});

  final String requirementId;

  @override
  State<RequirementDetailScreen> createState() =>
      _RequirementDetailScreenState();
}

class _RequirementDetailScreenState extends State<RequirementDetailScreen> {
  final RequirementService _requirementService = RequirementService();
  final QuoteService _quoteService = QuoteService();

  RequirementModel? _requirement;
  List<QuoteModel> _quotes = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final req = await _requirementService.fetchById(widget.requirementId);
      List<QuoteModel> quotes = [];
      try {
        quotes = await _requirementService.fetchQuotes(widget.requirementId);
      } catch (_) {
        // Non-owner or no access to quotes; leave empty.
      }
      if (!mounted) return;
      setState(() {
        _requirement = req;
        _quotes = quotes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmSelect(QuoteModel quote) async {
    final agreed = quote.counterPrice ?? quote.price;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Selection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Award this inquiry to ${quote.transporter.displayName}?'),
            const SizedBox(height: 12),
            Text(
              'Agreed rate: ₹${NumberFormat.decimalPattern('en_IN').format(agreed)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'A trip will be created and the transporter notified. Other quotes '
              'will be marked Not Selected.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _quoteService.select(quote.id);
      if (mounted) {
        showUserSuccessSnackBar(context, 'Quote awarded. Trip created.');
      }
      await _load();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _counter(QuoteModel quote) async {
    final ctrl = TextEditingController(
      text: (quote.counterPrice ?? quote.price).toString(),
    );
    final value = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter Offer'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            labelText: 'Your counter price',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = num.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, n);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (value == null) return;

    setState(() => _busy = true);
    try {
      await _quoteService.counter(quote.id, value);
      if (mounted) showUserSuccessSnackBar(context, 'Counter offer sent');
      await _load();
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openChat(QuoteModel quote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteChatScreen(
          quoteId: quote.id,
          title: quote.transporter.displayName,
          counterpartyTransporterId: quote.transporter.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(_requirement?.ref ?? 'Inquiry'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 20),
                      _quotesHeader(),
                      const SizedBox(height: 12),
                      ..._buildQuotes(),
                    ],
                  ),
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Something went wrong',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _summaryCard() {
    final r = _requirement!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.origin}  →  ${r.destination}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _statusChip(r.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.local_shipping_outlined, r.vehicleType),
              _chip(Icons.swap_horiz, r.direction),
              _chip(Icons.numbers, '${r.noOfVehicles} vehicle(s)'),
              if (r.requiredBy != null)
                _chip(Icons.calendar_today_outlined,
                    DateFormat('d MMM yyyy').format(r.requiredBy!)),
            ],
          ),
          if (r.remarks != null && r.remarks!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              r.remarks!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quotesHeader() {
    final awarded = _requirement!.isAwarded;
    return Row(
      children: [
        Text(
          awarded ? 'Awarded' : 'Quotes Received',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(${_quotes.length})',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  List<Widget> _buildQuotes() {
    if (_quotes.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: const Text(
            'No quotes yet. Transporters on the network have been notified.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ];
    }
    final awarded = _requirement!.isAwarded;
    return _quotes
        .map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuoteCard(
                quote: q,
                awardedMode: awarded,
                busy: _busy,
                onChat: () => _openChat(q),
                onCounter: () => _counter(q),
                onSelect: () => _confirmSelect(q),
              ),
            ))
        .toList();
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _statusChip(String status) {
    Color color = status == 'AWARDED'
        ? AppColors.success
        : status == 'OPEN'
            ? AppColors.info
            : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.awardedMode,
    required this.busy,
    required this.onChat,
    required this.onCounter,
    required this.onSelect,
  });

  final QuoteModel quote;
  final bool awardedMode;
  final bool busy;
  final VoidCallback onChat;
  final VoidCallback onCounter;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('en_IN');
    final selected = quote.isSelected;
    final dimmed = awardedMode && !selected;

    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.success : AppColors.dividerGrey,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    quote.transporter.displayName.characters.first
                        .toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.transporter.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text(
                            quote.transporter.ratingLabel,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          if (quote.respondedInMinutes != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '· responded in ${_respondedLabel(quote.respondedInMinutes!)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.verified, color: AppColors.success),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${money.format(quote.price)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                if (quote.counterPrice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'countered ₹${money.format(quote.counterPrice)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              quote.availabilityLabel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (quote.message != null && quote.message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                quote.message!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            if (!awardedMode) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Chat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onCounter,
                      icon: const Icon(Icons.swap_vert, size: 16),
                      label: const Text('Counter'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Select'),
                    ),
                  ),
                ],
              ),
            ] else if (selected) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'AWARDED',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Not selected',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _respondedLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    if (h < 24) return '$h hr';
    return '${h ~/ 24} d';
  }
}

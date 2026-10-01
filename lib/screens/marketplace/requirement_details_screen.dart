import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/requirement_model.dart';
import '../../services/requirement_service.dart';
import 'quote_chat_screen.dart';
import 'submit_quote_screen.dart';

/// Transporter view of an incoming inquiry: route, vehicles, remarks, requester,
/// with Quote Price and (once quoted) Chat with Requester.
class RequirementDetailsScreen extends StatefulWidget {
  const RequirementDetailsScreen({super.key, required this.requirementId});

  final String requirementId;

  @override
  State<RequirementDetailsScreen> createState() =>
      _RequirementDetailsScreenState();
}

class _RequirementDetailsScreenState extends State<RequirementDetailsScreen> {
  final RequirementService _service = RequirementService();
  RequirementModel? _requirement;
  bool _loading = true;
  String? _error;

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
      final r = await _service.fetchById(widget.requirementId);
      if (!mounted) return;
      setState(() {
        _requirement = r;
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

  Future<void> _openQuoteForm() async {
    final r = _requirement!;
    final initialPrice = r.myQuote?.price;
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SubmitQuoteScreen(
          requirement: r,
          initialPrice: initialPrice,
        ),
      ),
    );
    if (submitted == true && mounted) {
      showUserSuccessSnackBar(context, 'Quote submitted');
      _load();
    }
  }

  void _openChat() {
    final quoteId = _requirement?.myQuote?.id;
    if (quoteId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteChatScreen(
          quoteId: quoteId,
          title: _requirement?.requester.displayName,
          counterpartyTransporterId: _requirement?.requester.id,
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
              : RefreshIndicator(onRefresh: _load, child: _content()),
      bottomNavigationBar: (_loading || _error != null || _requirement == null)
          ? null
          : _actionBar(),
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

  Widget _content() {
    final r = _requirement!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Requester
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.dividerGrey),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  r.requester.displayName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.requester.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (r.createdAt != null)
                      Text(
                        'Posted ${DateFormat('d MMM, h:mm a').format(r.createdAt!.toLocal())}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              _statusChip(r.status),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Route + details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.dividerGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _routeRow(Icons.trip_origin, 'Pickup', r.origin),
              const Padding(
                padding: EdgeInsets.only(left: 9),
                child: SizedBox(
                  height: 22,
                  child: VerticalDivider(
                    width: 2,
                    thickness: 1.5,
                    color: AppColors.dividerGrey,
                  ),
                ),
              ),
              _routeRow(Icons.location_on, 'Drop', r.destination),
              const Divider(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(Icons.local_shipping_outlined, r.vehicleType),
                  _chip(Icons.swap_horiz, r.direction),
                  _chip(Icons.numbers, '${r.noOfVehicles} vehicle(s)'),
                  if (r.requiredBy != null)
                    _chip(Icons.event,
                        'By ${DateFormat('d MMM').format(r.requiredBy!)}'),
                ],
              ),
              if (r.remarks != null && r.remarks!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Remarks',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.remarks!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (r.myQuote != null) ...[
          const SizedBox(height: 16),
          _myQuoteCard(r),
        ],
      ],
    );
  }

  Widget _myQuoteCard(RequirementModel r) {
    final q = r.myQuote!;
    final money = NumberFormat.decimalPattern('en_IN');
    final selected = q.status == 'SELECTED';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (selected ? AppColors.success : AppColors.info).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.success : AppColors.info,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selected ? Icons.verified : Icons.request_quote_outlined,
                color: selected ? AppColors.success : AppColors.info,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                selected ? 'You won this inquiry' : 'Your quote',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.success : AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${money.format(q.price ?? 0)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Status: ${q.status ?? '—'}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    final r = _requirement!;
    final hasQuote = r.myQuote != null;
    final canQuote = r.isOpen;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.dividerGrey)),
        ),
        child: Row(
          children: [
            if (hasQuote)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (hasQuote) const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canQuote ? _openQuoteForm : null,
                icon: const Icon(Icons.request_quote_outlined, size: 18),
                label: Text(hasQuote ? 'Update Quote' : 'Quote Price'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

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

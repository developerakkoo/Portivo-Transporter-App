import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/support_ticket_category.dart';
import '../../providers/support_provider.dart';
import '../../widgets/support_category_badge.dart';

class NewSupportTicketScreen extends StatefulWidget {
  const NewSupportTicketScreen({
    super.key,
    required this.category,
    this.categoryDetail = '',
  });

  final SupportTicketCategory category;
  final String categoryDetail;

  @override
  State<NewSupportTicketScreen> createState() => _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState extends State<NewSupportTicketScreen> {
  final _message = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String get _subject {
    if (widget.category.requiresDetail) {
      final detail = widget.categoryDetail.trim();
      if (detail.isNotEmpty) {
        final suffix =
            detail.length > 80 ? '${detail.substring(0, 77)}...' : detail;
        return 'Other: $suffix';
      }
    }
    return widget.category.label;
  }

  Future<void> _submit() async {
    final msg = _message.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your issue')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final support = context.read<SupportProvider>();
      final created = await support.createTicket(
        subject: _subject,
        message: msg,
        category: widget.category.code,
        categoryDetail: widget.categoryDetail.trim(),
      );
      if (!mounted) return;
      if (created != null) {
        Navigator.of(context).pop(created);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create ticket')),
        );
      }
    } on DioException catch (e) {
      final m = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? 'Request failed')
          : 'Request failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Describe your issue')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SupportCategoryBadge(
            categoryCode: widget.category.code,
            categoryDetail: widget.categoryDetail,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _message,
            decoration: const InputDecoration(
              labelText: 'Describe your issue',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Start chat'),
          ),
        ],
      ),
    );
  }
}

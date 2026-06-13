import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/support_ticket_category.dart';
import '../../providers/support_provider.dart';
import 'new_support_ticket_screen.dart';

class SupportCategorySelectionScreen extends StatefulWidget {
  const SupportCategorySelectionScreen({super.key});

  @override
  State<SupportCategorySelectionScreen> createState() =>
      _SupportCategorySelectionScreenState();
}

class _SupportCategorySelectionScreenState
    extends State<SupportCategorySelectionScreen> {
  SupportTicketCategory? _selected;
  bool _showComplaints = false;
  final _otherDetail = TextEditingController();

  @override
  void dispose() {
    _otherDetail.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_selected == null) return false;
    if (_selected!.requiresDetail) {
      return _otherDetail.text.trim().length >= 3;
    }
    return true;
  }

  void _select(SupportTicketCategory category) {
    setState(() {
      _selected = category;
      _showComplaints = false;
      if (!category.requiresDetail) {
        _otherDetail.clear();
      }
    });
  }

  void _openComplaints() {
    setState(() {
      _showComplaints = true;
      _selected = null;
    });
  }

  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null || !_canContinue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a support type to continue')),
      );
      return;
    }

    final detail =
        selected.requiresDetail ? _otherDetail.text.trim() : '';

    final created = await Navigator.of(context).push<SupportTicketModel?>(
      MaterialPageRoute(
        builder: (_) => NewSupportTicketScreen(
          category: selected,
          categoryDetail: detail,
        ),
      ),
    );

    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop(created);
    }
  }

  Widget _categoryChip(SupportTicketCategory category) {
    final selected = _selected == category;
    return Semantics(
      label: category.label,
      button: true,
      selected: selected,
      child: FilterChip(
        label: Text(category.label),
        selected: selected,
        onSelected: (_) => _select(category),
        selectedColor: category.badgeColor.withValues(alpha: 0.15),
        checkmarkColor: category.badgeColor,
        labelStyle: TextStyle(
          color: selected ? category.badgeColor : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        side: BorderSide(
          color: selected
              ? category.badgeColor
              : AppColors.dividerGrey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('What do you need help with?'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Choose the type of support you need',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps our team route your ticket faster.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in SupportTicketCategory.topLevelIssues)
                _categoryChip(c),
              Semantics(
                label: 'Complaints',
                button: true,
                selected: _showComplaints,
                child: FilterChip(
                  label: const Text('Complaints'),
                  selected: _showComplaints ||
                      (_selected?.isComplaint ?? false),
                  onSelected: (_) => _openComplaints(),
                  selectedColor:
                      const Color(0xFFE11D48).withValues(alpha: 0.12),
                  checkmarkColor: const Color(0xFFE11D48),
                  labelStyle: TextStyle(
                    fontWeight: (_showComplaints ||
                            (_selected?.isComplaint ?? false))
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_showComplaints) ...[
            const SizedBox(height: 20),
            Text(
              'Complaint type',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in SupportTicketCategory.complaintTypes)
                  _categoryChip(c),
              ],
            ),
          ],
          if (_selected?.requiresDetail == true) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _otherDetail,
              decoration: const InputDecoration(
                labelText: 'Describe your other issue',
                hintText: 'Brief summary (required)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canContinue ? _continue : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

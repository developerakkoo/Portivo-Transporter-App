import 'package:flutter/material.dart';

import '../models/support_ticket_category.dart';

class SupportCategoryBadge extends StatelessWidget {
  const SupportCategoryBadge({
    super.key,
    required this.categoryCode,
    this.categoryDetail = '',
    this.compact = false,
  });

  final String categoryCode;
  final String categoryDetail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = SupportTicketCategory.labelForCode(categoryCode);
    final color = SupportTicketCategory.colorForCode(categoryCode);
    final detail = categoryDetail.trim();
    final showDetail =
        categoryCode == SupportTicketCategory.otherIssue.code && detail.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        showDetail ? '$label · $detail' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
      ),
    );
  }
}

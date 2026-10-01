import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

/// A route row showing a destination with per-direction (Export/Import) rates.
/// Shared by the buyer listing detail and the owner listing detail screens.
class MarketplaceRouteRateTile extends StatelessWidget {
  const MarketplaceRouteRateTile({
    super.key,
    required this.destination,
    required this.exportRate,
    required this.importRate,
    this.alwaysNegotiable = false,
    this.highlight = false,
    this.onEdit,
  });

  final String destination;
  final num? exportRate;
  final num? importRate;
  final bool alwaysNegotiable;
  final bool highlight;

  /// Optional edit affordance (owner view). When null, no edit icon is shown.
  final VoidCallback? onEdit;

  static final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

  String _rate(num? v) =>
      (v == null || alwaysNegotiable) ? 'Negotiable' : '₹ ${_inr.format(v)}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withOpacity(0.08) : null,
        border: Border.all(
          color: highlight ? AppColors.primary : AppColors.dividerGrey,
          width: highlight ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  destination,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onEdit != null)
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Export: ${_rate(exportRate)}',
                  style: textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  'Import: ${_rate(importRate)}',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

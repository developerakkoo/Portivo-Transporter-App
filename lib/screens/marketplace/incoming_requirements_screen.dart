import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/requirement_model.dart';
import '../../providers/requirement_provider.dart';
import 'requirement_details_screen.dart';

/// Transporter feed of incoming inquiries matching their active listings.
class IncomingRequirementsScreen extends StatefulWidget {
  const IncomingRequirementsScreen({super.key});

  @override
  State<IncomingRequirementsScreen> createState() =>
      _IncomingRequirementsScreenState();
}

class _IncomingRequirementsScreenState
    extends State<IncomingRequirementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequirementProvider>().loadIncoming();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Incoming Inquiries'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: Consumer<RequirementProvider>(
        builder: (context, provider, _) {
          if (provider.loadingIncoming && provider.incoming.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.incoming.isEmpty) {
            return _empty(context);
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadIncoming(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.incoming.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _IncomingCard(
                requirement: provider.incoming[i],
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequirementDetailsScreen(
                        requirementId: provider.incoming[i].id,
                      ),
                    ),
                  );
                  if (mounted) provider.loadIncoming(silent: true);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox_outlined,
                        size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text('No incoming inquiries',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Inquiries matching your active listings will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({required this.requirement, required this.onTap});

  final RequirementModel requirement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quoted = requirement.myQuote != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                    requirement.requester.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (quoted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Quoted',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${requirement.origin}  →  ${requirement.destination}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${requirement.vehicleType} · ${requirement.direction} · ${requirement.noOfVehicles} vehicle(s)',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (requirement.createdAt != null)
                  Text(
                    DateFormat('d MMM, h:mm a')
                        .format(requirement.createdAt!.toLocal()),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                const Spacer(),
                Text(
                  quoted ? 'View / Update' : 'Quote now',
                  style: const TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.info),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

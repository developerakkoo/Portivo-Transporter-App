import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/requirement_model.dart';
import '../../providers/requirement_provider.dart';
import 'post_inquiry_screen.dart';
import 'requirement_detail_screen.dart';

/// Requester view: list of inquiries I've posted, with quote counts and status.
class MyRequirementsScreen extends StatefulWidget {
  const MyRequirementsScreen({super.key});

  @override
  State<MyRequirementsScreen> createState() => _MyRequirementsScreenState();
}

class _MyRequirementsScreenState extends State<MyRequirementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequirementProvider>().loadMine();
    });
  }

  Future<void> _newInquiry() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const PostInquiryScreen()),
    );
    if (created == true && mounted) {
      context.read<RequirementProvider>().loadMine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('My Inquiries'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newInquiry,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Inquiry', style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<RequirementProvider>(
        builder: (context, provider, _) {
          if (provider.loadingMine && provider.mine.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.mine.isEmpty) {
            return _emptyState();
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadMine(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: provider.mine.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _RequirementCard(
                requirement: provider.mine[i],
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequirementDetailScreen(
                        requirementId: provider.mine[i].id,
                      ),
                    ),
                  );
                  if (mounted) provider.loadMine(silent: true);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No inquiries yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Post an inquiry and receive quotes from transporters on the network.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.requirement, required this.onTap});

  final RequirementModel requirement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                Text(
                  requirement.ref,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: requirement.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.route_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${requirement.origin}  →  ${requirement.destination}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${requirement.vehicleType} · ${requirement.direction} · ${requirement.noOfVehicles} vehicle(s)',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${requirement.quoteCount} quote${requirement.quoteCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (requirement.createdAt != null)
                  Text(
                    DateFormat('d MMM').format(requirement.createdAt!),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'AWARDED':
        color = AppColors.success;
        break;
      case 'CANCELLED':
      case 'EXPIRED':
        color = AppColors.error;
        break;
      case 'CLOSED':
        color = AppColors.textMuted;
        break;
      default:
        color = AppColors.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

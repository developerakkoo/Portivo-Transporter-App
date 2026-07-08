import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'verified_badge.dart';

class TransporterHomeAppBarTitle extends StatelessWidget {
  const TransporterHomeAppBarTitle({super.key});

  String _greetingName(String? name, String mobile) {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName.split(RegExp(r'\s+')).first;
    }

    final trimmedMobile = mobile.trim();
    if (trimmedMobile.isNotEmpty) {
      return trimmedMobile;
    }

    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final greetingName = _greetingName(user?.name, user?.mobile ?? '');
        final company = user?.company?.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hello $greetingName',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (company != null && company.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      company,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const VerifiedBadge(),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

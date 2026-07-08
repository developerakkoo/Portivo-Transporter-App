import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_copy.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final permissionService = PermissionService(authProvider);
            final user = authProvider.user;
            final displayName = user?.name?.trim().isNotEmpty == true
                ? user!.name!.trim()
                : (user != null && user.mobile.trim().isNotEmpty
                    ? user.mobile.trim()
                    : 'Transporter');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DrawerHeader(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Prottivo Transporter',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      AppDrawerMenuTile(
                        icon: Icons.person_outline,
                        title: 'View Profile',
                        onTap: () => _navigate(context, '/profile'),
                      ),
                      AppDrawerMenuTile(
                        icon: Icons.map_outlined,
                        title: 'View Map',
                        onTap: () => _navigate(context, '/map'),
                      ),
                      if (permissionService.hasPermission('manageVehicles') ||
                          permissionService.isTransporter)
                        AppDrawerMenuTile(
                          icon: Icons.inventory_2_outlined,
                          title: 'Vehicles',
                          onTap: () => _navigate(context, '/vehicles'),
                        ),
                      if (permissionService.hasPermission('manageWallet') ||
                          permissionService.isTransporter)
                        AppDrawerMenuTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: AppCopy.earnings,
                          onTap: () => _navigate(context, '/wallet'),
                        ),
                      if (permissionService.hasPermission('manageFuelCards') ||
                          permissionService.isTransporter)
                        AppDrawerMenuTile(
                          icon: Icons.credit_card_outlined,
                          title: 'Fuel cards',
                          onTap: () => _navigate(context, '/fuel-cards'),
                        ),
                      if (permissionService.hasPermission('manageUsers') ||
                          permissionService.isTransporter)
                        AppDrawerMenuTile(
                          icon: Icons.business_outlined,
                          title: 'Company & users',
                          onTap: () => _navigate(context, '/company-users'),
                        ),
                      AppDrawerMenuTile(
                        icon: Icons.help_outline,
                        title: 'Support',
                        onTap: () => _navigate(context, '/support'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: AppDrawerLogoutButton(textTheme: textTheme),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppDrawerMenuTile extends StatelessWidget {
  const AppDrawerMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class AppDrawerLogoutButton extends StatelessWidget {
  const AppDrawerLogoutButton({super.key, required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: authProvider.isLoading
                ? null
                : () async {
                    Navigator.of(context).pop();
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                    ),
                  )
                : Text(
                    'Logout',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

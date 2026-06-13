import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_copy.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final permissionService = PermissionService(authProvider);
            
            return ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.person_outline,
                  title: 'View Profile',
                  onTap: () {
                    Navigator.of(context).pushNamed('/profile');
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.map_outlined,
                  title: 'View Map',
                  onTap: () {
                    Navigator.of(context).pushNamed('/map');
                  },
                ),
                // Vehicles - requires manageVehicles permission
                if (permissionService.hasPermission('manageVehicles') || permissionService.isTransporter)
                  _buildMenuItem(
                    context: context,
                    icon: Icons.inventory_2_outlined,
                    title: 'Vehicles',
                    onTap: () {
                      Navigator.of(context).pushNamed('/vehicles');
                    },
                  ),
                // Wallet - requires manageWallet permission
                if (permissionService.hasPermission('manageWallet') || permissionService.isTransporter)
                  _buildMenuItem(
                    context: context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: AppCopy.earnings,
                    onTap: () {
                      Navigator.of(context).pushNamed('/wallet');
                    },
                  ),
                // Fuel Cards - requires manageFuelCards permission
                if (permissionService.hasPermission('manageFuelCards') || permissionService.isTransporter)
                  _buildMenuItem(
                    context: context,
                    icon: Icons.credit_card_outlined,
                    title: 'Fuel cards',
                    onTap: () {
                      Navigator.of(context).pushNamed('/fuel-cards');
                    },
                  ),
                // Company Users - requires manageUsers permission
                if (permissionService.hasPermission('manageUsers') || permissionService.isTransporter)
                  _buildMenuItem(
                    context: context,
                    icon: Icons.business_outlined,
                    title: 'Company & users',
                    onTap: () {
                      Navigator.of(context).pushNamed('/company-users');
                    },
                  ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.help_outline,
                  title: 'Support',
                  onTap: () {
                    Navigator.of(context).pushNamed('/support');
                  },
                ),
                const SizedBox(height: 32.0),
                _buildLogoutButton(context, textTheme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.textPrimary,
              size: 24.0,
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, TextTheme textTheme) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          height: 52.0,
          child: OutlinedButton(
            onPressed: authProvider.isLoading
                ? null
                : () async {
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 20.0,
                    width: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
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


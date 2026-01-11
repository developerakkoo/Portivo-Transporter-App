import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            _buildMenuItem(
              context: context,
              icon: Icons.directions_car_outlined,
              title: 'Vehicles',
              onTap: () {
                // TODO: Navigate to vehicles
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet',
              onTap: () {
                Navigator.of(context).pushNamed('/wallet');
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.credit_card_outlined,
              title: 'Fuel cards',
              onTap: () {
                Navigator.of(context).pushNamed('/fuel-cards');
              },
            ),
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
                // TODO: Navigate to support
              },
            ),
            const SizedBox(height: 32.0),
            _buildLogoutButton(context, textTheme),
          ],
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
    return SizedBox(
      height: 52.0,
      child: OutlinedButton(
        onPressed: () {
          // TODO: Implement logout
          Navigator.of(context).pushReplacementNamed('/login');
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: Text(
          'Logout',
          style: textTheme.labelLarge?.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


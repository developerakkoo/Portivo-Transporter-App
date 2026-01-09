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
            _buildSectionHeader(textTheme, 'Account'),
            const SizedBox(height: 8.0),
            _buildMenuItem(
              context: context,
              icon: Icons.person_outline,
              title: 'Profile',
              onTap: () {
                // TODO: Navigate to profile
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.local_shipping_outlined,
              title: 'Vehicles',
              onTap: () {
                // TODO: Navigate to vehicles
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.people_outlined,
              title: 'Drivers',
              onTap: () {
                // TODO: Navigate to drivers
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.business_outlined,
              title: 'Company',
              onTap: () {
                // TODO: Navigate to company
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.group_outlined,
              title: 'Users',
              onTap: () {
                // TODO: Navigate to users
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
              title: 'Fuel Cards',
              onTap: () {
                Navigator.of(context).pushNamed('/fuel-cards');
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.local_gas_station_outlined,
              title: 'Fuel Partners',
              onTap: () {
                // TODO: Navigate to fuel partners
              },
            ),
            const SizedBox(height: 24.0),
            _buildSectionHeader(textTheme, 'Support'),
            const SizedBox(height: 8.0),
            _buildMenuItem(
              context: context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                // TODO: Navigate to help
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.info_outline,
              title: 'About',
              onTap: () {
                // TODO: Navigate to about
              },
            ),
            const SizedBox(height: 24.0),
            _buildSectionHeader(textTheme, 'Legal'),
            const SizedBox(height: 8.0),
            _buildMenuItem(
              context: context,
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () {
                // TODO: Navigate to terms
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () {
                // TODO: Navigate to privacy
              },
            ),
            const SizedBox(height: 32.0),
            _buildLogoutButton(context, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(TextTheme textTheme, String title) {
    return Text(
      title,
      style: textTheme.titleSmall?.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
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


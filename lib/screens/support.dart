import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  void _launchEmail(BuildContext context, String email) {
    // Show email in dialog or copy to clipboard
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Support'),
        content: Text('Send an email to: $email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _launchPhone(BuildContext context, String phone) {
    // Show phone in dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Support'),
        content: Text('Call us at: $phone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Support'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Need Help?',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'We\'re here to assist you with any questions or issues.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32.0),

              // Contact Information
              _buildContactCard(
                context: context,
                icon: Icons.email_outlined,
                title: 'Email Support',
                subtitle: 'support@porttivo.com',
                onTap: () => _launchEmail(context, 'support@porttivo.com'),
                textTheme: textTheme,
              ),
              const SizedBox(height: 16.0),
              _buildContactCard(
                context: context,
                icon: Icons.phone_outlined,
                title: 'Phone Support',
                subtitle: '+91 1800-XXX-XXXX',
                onTap: () => _launchPhone(context, '+911800XXXXXX'),
                textTheme: textTheme,
              ),
              const SizedBox(height: 16.0),
              _buildContactCard(
                context: context,
                icon: Icons.chat_bubble_outline,
                title: 'Live Chat',
                subtitle: 'Available 24/7',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Live chat feature coming soon'),
                    ),
                  );
                },
                textTheme: textTheme,
              ),
              const SizedBox(height: 32.0),

              // FAQ Section
              Text(
                'Frequently Asked Questions',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16.0),
              _buildFAQItem(
                question: 'How do I create a trip?',
                answer: 'Go to the Home tab and tap "Create Trip" button, or use the "+" button in the Trips tab.',
                textTheme: textTheme,
              ),
              _buildFAQItem(
                question: 'How do I add a vehicle?',
                answer: 'Go to the Home tab and tap "Add Vehicle" button, or navigate to Vehicles from the More tab and use the "+" button.',
                textTheme: textTheme,
              ),
              _buildFAQItem(
                question: 'How do I manage drivers?',
                answer: 'Drivers are automatically created when they first login. You can view all drivers in the Drivers tab.',
                textTheme: textTheme,
              ),
              _buildFAQItem(
                question: 'How do I check my wallet balance?',
                answer: 'Go to the More tab and tap "Wallet" to view your balance and transaction history.',
                textTheme: textTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required TextTheme textTheme,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
    required TextTheme textTheme,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: Text(
              answer,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textSecondary,
      ),
    );
  }
}

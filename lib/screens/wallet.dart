import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  // Placeholder data
  static const double availableBalance = 12500.00;
  static const double dailyTransferLimit = 50000.00;
  static const double monthlyTransferLimit = 500000.00;

  static final List<Map<String, dynamic>> transactions = [
    {
      'id': '1',
      'type': 'credit',
      'amount': 5000.00,
      'description': 'Trip Payment - CONT-2024-001',
      'date': '2024-01-15',
      'time': '14:30',
      'status': 'completed',
    },
    {
      'id': '2',
      'type': 'debit',
      'amount': 2500.00,
      'description': 'Fuel Payment',
      'date': '2024-01-14',
      'time': '10:15',
      'status': 'completed',
    },
    {
      'id': '3',
      'type': 'credit',
      'amount': 3000.00,
      'description': 'Trip Payment - CONT-2024-002',
      'date': '2024-01-13',
      'time': '16:45',
      'status': 'completed',
    },
    {
      'id': '4',
      'type': 'debit',
      'amount': 1500.00,
      'description': 'Driver Payment',
      'date': '2024-01-12',
      'time': '09:20',
      'status': 'completed',
    },
    {
      'id': '5',
      'type': 'credit',
      'amount': 7500.00,
      'description': 'Trip Payment - CONT-2024-003',
      'date': '2024-01-11',
      'time': '11:00',
      'status': 'completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wallet'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance Card
              _buildBalanceCard(textTheme),
              const SizedBox(height: 24.0),

              // Action Buttons
              _buildActionButtons(context, textTheme),
              const SizedBox(height: 32.0),

              // Recent Transactions
              _buildTransactionsSection(textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.background.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            '\$${availableBalance.toStringAsFixed(2)}',
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.background,
            ),
          ),
          const SizedBox(height: 24.0),
          const Divider(
            color: AppColors.background,
            thickness: 0.5,
            height: 1,
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Limit',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.background.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '\$${dailyTransferLimit.toStringAsFixed(0)}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.background,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.background.withOpacity(0.3),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Limit',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.background.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '\$${monthlyTransferLimit.toStringAsFixed(0)}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.background,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52.0,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to add money screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add Money feature coming soon')),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 20.0),
              label: Text(
                'Add Money',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: SizedBox(
            height: 52.0,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to send money screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Send Money feature coming soon')),
                );
              },
              icon: const Icon(Icons.send_outlined, size: 20.0),
              label: Text(
                'Send Money',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16.0),
        if (transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64.0,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'No transactions yet',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...transactions.map((transaction) => _buildTransactionCard(
                transaction,
                textTheme,
              )),
      ],
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> transaction,
    TextTheme textTheme,
  ) {
    final isCredit = transaction['type'] == 'credit';
    final amount = transaction['amount'] as double;
    final description = transaction['description'] as String;
    final date = transaction['date'] as String;
    final time = transaction['time'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Transaction Type Icon
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: isCredit
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? AppColors.success : AppColors.error,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 16.0),
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  '$date at $time',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  'Completed',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontSize: 10.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

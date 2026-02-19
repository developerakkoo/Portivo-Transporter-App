import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/wallet_provider.dart';
import '../data/models/wallet_transaction_model.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = context.read<WalletProvider>();
      walletProvider.loadBalance();
      walletProvider.loadTransactions();
    });
  }

  // Placeholder limits (can be fetched from backend if available)
  static const double dailyTransferLimit = 50000.00;
  static const double monthlyTransferLimit = 500000.00;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, authChild) {
        final permissionService = PermissionService(authProvider);
        
        // Check permission - redirect if unauthorized
        if (!permissionService.hasPermission('manageWallet') && !permissionService.isTransporter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to access wallet'),
                backgroundColor: Colors.red,
              ),
            );
          });
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Wallet')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final balance = walletProvider.balance;
        final transactions = walletProvider.transactions;
        final isLoading = walletProvider.isLoading;
        final error = walletProvider.error;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Wallet'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading ? null : () => walletProvider.refresh(),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => walletProvider.refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Text(
                                error,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => walletProvider.refresh(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    // Balance Card
                    _buildBalanceCard(balance, textTheme),
                    const SizedBox(height: 24.0),

                    // Action Buttons
                    _buildActionButtons(context, textTheme),
                    const SizedBox(height: 32.0),

                    // Recent Transactions
                    _buildTransactionsSection(transactions, isLoading, textTheme),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
      },
    );
  }

  Widget _buildBalanceCard(double balance, TextTheme textTheme) {
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
            '₹${balance.toStringAsFixed(2)}',
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
                      '₹${dailyTransferLimit.toStringAsFixed(0)}',
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
                      '₹${monthlyTransferLimit.toStringAsFixed(0)}',
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

  Widget _buildTransactionsSection(
    List<WalletTransactionModel> transactions,
    bool isLoading,
    TextTheme textTheme,
  ) {
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
        if (isLoading && transactions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (transactions.isEmpty)
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
    WalletTransactionModel transaction,
    TextTheme textTheme,
  ) {
    final isCredit = transaction.isCredit;
    final amount = transaction.amount;
    final description = transaction.description ?? 'Transaction';
    final date = transaction.createdAt;

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
                  '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
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
                '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
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
                  color: (transaction.status == 'completed'
                          ? AppColors.success
                          : AppColors.warning)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  transaction.status.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: transaction.status == 'completed'
                        ? AppColors.success
                        : AppColors.warning,
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

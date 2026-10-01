import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/main_shell_scope.dart';
import '../../widgets/open_app_drawer_button.dart';
import 'driver_advances_list.dart';
import 'marketplace_payments_list.dart';
import 'payment_history_list.dart';

/// Payments hub: Driver Advances, Payment History, Marketplace Payments.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  /// 0 = Driver Advances, 1 = Payment History, 2 = Marketplace Payments.
  final int initialTabIndex;

  static int tabIndexFromRouteArgs(Object? args) {
    if (args is Map) {
      final tab = args['tab']?.toString();
      if (tab == 'history') return 1;
      if (tab == 'marketplace') return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final fromArgs = tabIndexFromRouteArgs(
      ModalRoute.of(context)?.settings.arguments,
    );
    final index = fromArgs != 0 ? fromArgs : initialTabIndex.clamp(0, 2);

    final inShell = MainShellScope.maybeOf(context) != null;

    return DefaultTabController(
      length: 3,
      initialIndex: index,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: !inShell,
          leading: inShell ? const OpenAppDrawerButton() : null,
          title: const Text('Payments'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Driver Advances'),
              Tab(text: 'Payment History'),
              Tab(text: 'Marketplace Payments'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DriverAdvancesList(),
            PaymentHistoryList(),
            MarketplacePaymentsList(),
          ],
        ),
      ),
    );
  }
}

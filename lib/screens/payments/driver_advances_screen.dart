import 'package:flutter/material.dart';

import 'payments_screen.dart';

/// Alias kept so `/driver-advances` still opens the Payments hub
/// on the Driver Advances tab.
class DriverAdvancesScreen extends StatelessWidget {
  const DriverAdvancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaymentsScreen(initialTabIndex: 0);
  }
}

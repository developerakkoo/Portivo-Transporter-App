import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/driver_advance_model.dart';

class DriverAdvanceDetailScreen extends StatelessWidget {
  const DriverAdvanceDetailScreen({super.key, required this.item});

  final TripAdvanceListItem item;

  static final NumberFormat _inrFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final paidAt = item.advance.payment.paidAt;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Driver Advance')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            item.transporter?.name ?? item.trip.tripref ?? item.trip.id,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Trip ID: ${item.trip.tripref ?? item.trip.id}'),
          Text('Type: ${item.trip.type ?? '—'} · ${item.trip.status ?? ''}'),
          const SizedBox(height: 16),
          Text(
            'Driver: ${item.driver?.name ?? '—'}'
            '${item.driver?.mobile != null ? ' · ${item.driver!.mobile}' : ''}',
          ),
          const SizedBox(height: 24),
          Text(
            _inrFmt.format(item.advance.amount),
            style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Status: ${item.advance.payment.status ?? item.advance.status ?? '—'}'),
          if (paidAt != null)
            Text('Paid on ${DateFormat('dd MMM yyyy, hh:mm a').format(paidAt)}'),
          const SizedBox(height: 24),
          Text('Payment Details', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Requested: ${item.trip.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(item.trip.createdAt!) : '—'}'),
          Text('Transaction ID: ${item.trip.id}'),
          Text('Payment Mode: Razorpay'),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/support'),
            icon: const Icon(Icons.help_outline),
            label: const Text('Need Help?'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';

class CollectExtraChargesResult {
  const CollectExtraChargesResult({
    required this.amount,
    required this.description,
  });

  final num amount;
  final String description;
}

class CollectExtraChargesSheet extends StatefulWidget {
  const CollectExtraChargesSheet({super.key});

  static Future<CollectExtraChargesResult?> show(BuildContext context) {
    return showModalBottomSheet<CollectExtraChargesResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CollectExtraChargesSheet(),
    );
  }

  @override
  State<CollectExtraChargesSheet> createState() =>
      _CollectExtraChargesSheetState();
}

class _CollectExtraChargesSheetState extends State<CollectExtraChargesSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String? _amountError;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = num.tryParse(_amountCtrl.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => _amountError = 'Enter a valid amount in rupees');
      return;
    }
    final desc = _descCtrl.text.trim();
    Navigator.pop(
      context,
      CollectExtraChargesResult(
        amount: parsed,
        description: desc.isEmpty ? 'Extra charges' : desc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Collect extra charges',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'A Razorpay payment link will be sent in this chat. The other transporter pays the link. Status comes from the backend, not the payment page.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount (INR)',
              hintText: '1000',
              prefixText: '₹ ',
              errorText: _amountError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Extra charges',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Create payment link'),
            ),
          ),
        ],
      ),
    );
  }
}

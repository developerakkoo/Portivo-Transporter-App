import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class FuelCardsScreen extends StatefulWidget {
  const FuelCardsScreen({super.key});

  @override
  State<FuelCardsScreen> createState() => _FuelCardsScreenState();
}

class _FuelCardsScreenState extends State<FuelCardsScreen> {
  // Placeholder fuel cards data
  List<Map<String, dynamic>> fuelCards = [
    {
      'id': '1',
      'name': 'Shell Premium',
      'cardNumber': '**** **** **** 1234',
      'balance': 2500.00,
      'qrCode': 'FC-2024-001',
    },
    {
      'id': '2',
      'name': 'BP Standard',
      'cardNumber': '**** **** **** 5678',
      'balance': 1800.00,
      'qrCode': 'FC-2024-002',
    },
    {
      'id': '3',
      'name': 'Exxon Mobil',
      'cardNumber': '**** **** **** 9012',
      'balance': 3200.00,
      'qrCode': 'FC-2024-003',
    },
  ];

  void _addFuelCard() {
    showDialog(
      context: context,
      builder: (context) => _AddFuelCardDialog(
        onAdd: (name) {
          setState(() {
            final newCard = {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'name': name,
              'cardNumber': '**** **** **** ${(1000 + fuelCards.length).toString()}',
              'balance': 0.00,
              'qrCode': 'FC-2024-${(100 + fuelCards.length + 1).toString()}',
            };
            fuelCards.add(newCard);
          });
        },
      ),
    );
  }

  void _renameFuelCard(int index) {
    final currentName = fuelCards[index]['name'] as String;
    showDialog(
      context: context,
      builder: (context) => _RenameFuelCardDialog(
        currentName: currentName,
        onRename: (newName) {
          setState(() {
            fuelCards[index]['name'] = newName;
          });
        },
      ),
    );
  }

  void _viewQRCode(Map<String, dynamic> card) {
    Navigator.of(context).pushNamed(
      '/fuel-card-qr',
      arguments: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fuel Cards'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Add Fuel Card Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 52.0,
                child: ElevatedButton.icon(
                  onPressed: _addFuelCard,
                  icon: const Icon(Icons.add_circle_outline, size: 20.0),
                  label: Text(
                    'Add Fuel Card',
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

            // Fuel Cards List
            Expanded(
              child: fuelCards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card_outlined,
                            size: 64.0,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16.0),
                          Text(
                            'No fuel cards yet',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: fuelCards.length,
                      itemBuilder: (context, index) {
                        return _buildFuelCard(
                          fuelCards[index],
                          index,
                          textTheme,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelCard(
    Map<String, dynamic> card,
    int index,
    TextTheme textTheme,
  ) {
    final name = card['name'] as String;
    final cardNumber = card['cardNumber'] as String;
    final balance = card['balance'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Stack(
        children: [
          // Fuel Card (styled like wallet card)
          Container(
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
                // Card Name with Rename Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.background,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.background,
                        size: 20.0,
                      ),
                      onPressed: () => _renameFuelCard(index),
                      tooltip: 'Rename',
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),
                Text(
                  'Card Number',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.background.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  cardNumber,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.background,
                    letterSpacing: 2.0,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.background.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '\$${balance.toStringAsFixed(2)}',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.background,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // QR Code Icon Button (positioned at top-right)
          Positioned(
            top: 16.0,
            right: 16.0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.qr_code,
                  color: AppColors.background,
                  size: 24.0,
                ),
                onPressed: () => _viewQRCode(card),
                tooltip: 'View QR Code',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Add Fuel Card Dialog
class _AddFuelCardDialog extends StatefulWidget {
  final Function(String) onAdd;

  const _AddFuelCardDialog({required this.onAdd});

  @override
  State<_AddFuelCardDialog> createState() => _AddFuelCardDialogState();
}

class _AddFuelCardDialogState extends State<_AddFuelCardDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: Text(
        'Add Fuel Card',
        style: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Fuel Card Name',
          hintText: 'Enter fuel card name',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              widget.onAdd(_nameController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.background,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Rename Fuel Card Dialog
class _RenameFuelCardDialog extends StatefulWidget {
  final String currentName;
  final Function(String) onRename;

  const _RenameFuelCardDialog({
    required this.currentName,
    required this.onRename,
  });

  @override
  State<_RenameFuelCardDialog> createState() => _RenameFuelCardDialogState();
}

class _RenameFuelCardDialogState extends State<_RenameFuelCardDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: Text(
        'Rename Fuel Card',
        style: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Fuel Card Name',
          hintText: 'Enter fuel card name',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              widget.onRename(_nameController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.background,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

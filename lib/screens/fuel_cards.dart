import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../data/models/fuel_card_model.dart';
import '../data/models/driver_model.dart';
import '../providers/fuel_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

class FuelCardsScreen extends StatefulWidget {
  const FuelCardsScreen({super.key});

  @override
  State<FuelCardsScreen> createState() => _FuelCardsScreenState();
}

class _FuelCardsScreenState extends State<FuelCardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FuelProvider>().loadFuelCards();
      context.read<DriverProvider>().loadDrivers(refresh: true);
    });
  }

  void _viewQRCode(FuelCardModel card) {
    Navigator.of(context).pushNamed(
      '/fuel-card-qr',
      arguments: card,
    );
  }

  Future<void> _showAssignDialog(FuelCardModel card) async {
    final driverProvider = context.read<DriverProvider>();
    await driverProvider.loadDrivers(refresh: true);
    final drivers = driverProvider.drivers;

    if (!mounted) return;
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drivers available. Add drivers first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<DriverModel>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Driver to Assign',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final driver = drivers[index];
                  return ListTile(
                    title: Text(driver.name ?? ''),
                    subtitle: Text(driver.mobile),
                    onTap: () => Navigator.of(context).pop(driver),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      final fuelProvider = context.read<FuelProvider>();
      final result = await fuelProvider.assignFuelCard(
        cardId: card.id,
        driverId: selected.id,
      );
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fuel card assigned successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(fuelProvider.error ?? 'Failed to assign'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, authChild) {
        final permissionService = PermissionService(authProvider);
        
        // Check permission - redirect if unauthorized
        if (!permissionService.hasPermission('manageFuelCards') && !permissionService.isTransporter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to access fuel cards'),
                backgroundColor: Colors.red,
              ),
            );
          });
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Fuel Cards')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Consumer<FuelProvider>(
          builder: (context, fuelProvider, child) {
        final fuelCards = fuelProvider.fuelCards;
        final isLoading = fuelProvider.isLoading;
        final error = fuelProvider.error;

        if (isLoading && fuelCards.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Fuel Cards'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (error != null && fuelCards.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Fuel Cards'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.0,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Error loading fuel cards',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    error,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () => fuelProvider.loadFuelCards(refresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Fuel Cards'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading
                    ? null
                    : () => fuelProvider.loadFuelCards(refresh: true),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => fuelProvider.loadFuelCards(refresh: true),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      itemCount: fuelCards.length,
                      itemBuilder: (context, index) {
                        return _buildFuelCard(
                          fuelCards[index],
                          textTheme,
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
      },
    );
  }

  Widget _buildFuelCard(
    FuelCardModel card,
    TextTheme textTheme,
  ) {
    final cardNumber = card.cardNumber.length > 4
        ? '**** **** **** ${card.cardNumber.substring(card.cardNumber.length - 4)}'
        : card.cardNumber;

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
                // Card Number
                Text(
                  'Fuel Card',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.background,
                  ),
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
                          '₹${card.balance.toStringAsFixed(2)}',
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
          // Action buttons (top-right)
          Positioned(
            top: 16.0,
            right: 16.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (card.status == 'active')
                  Container(
                    margin: const EdgeInsets.only(right: 8.0),
                    decoration: BoxDecoration(
                      color: AppColors.background.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.person_add,
                        color: AppColors.background,
                        size: 22.0,
                      ),
                      onPressed: () => _showAssignDialog(card),
                      tooltip: 'Assign to Driver',
                    ),
                  ),
                Container(
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
              ],
            ),
          ),
          if (card.driverId != null)
            Positioned(
              bottom: 16.0,
              left: 24.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Assigned to driver',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.background,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_colors.dart';
import '../data/models/fuel_card_model.dart';

class FuelCardQRScreen extends StatelessWidget {
  const FuelCardQRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final args = ModalRoute.of(context)?.settings.arguments;
    
    // Support both old Map format and new FuelCardModel
    String cardNumber;
    String qrData;
    
    if (args is FuelCardModel) {
      cardNumber = args.cardNumber;
      qrData = args.id; // Use card ID as QR data, or generate QR code
    } else if (args is Map) {
      cardNumber = args['cardNumber'] ?? args['name'] ?? 'Fuel Card';
      qrData = args['qrCode'] ?? args['id'] ?? '';
    } else {
      cardNumber = 'Fuel Card';
      qrData = '';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('QR Code'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Card Number
                Text(
                  cardNumber,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 32.0),

                // QR Code Display
                Container(
                  width: 280,
                  height: 280,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: AppColors.dividerGrey,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 12.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: qrData.isNotEmpty
                      ? QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 232.0,
                          backgroundColor: AppColors.background,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 120.0,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 16.0),
                            Text(
                              'No QR data available',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 32.0),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.offWhite,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20.0,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'Scan this QR code at the fuel station',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

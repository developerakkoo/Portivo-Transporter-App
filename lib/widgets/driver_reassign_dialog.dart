import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/driver_already_assigned_exception.dart';

Future<bool> showDriverReassignDialog({
  required BuildContext context,
  required DriverAlreadyAssignedException conflict,
  required String newVehicleNumber,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final name = conflict.displayName;
      final mobile = conflict.formattedMobile;
      final oldVehicle = conflict.currentVehicleNumber ?? 'another vehicle';
      final identity = mobile.isNotEmpty ? '$name ($mobile)' : name;

      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Expanded(
              child: Text('Driver Already Assigned'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$identity is already assigned to $oldVehicle.',
            ),
            if (conflict.currentVehicleType != null &&
                conflict.currentVehicleType!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Vehicle type: ${conflict.currentVehicleType}'),
            ],
            if (conflict.currentCargoWeightMt != null) ...[
              const SizedBox(height: 4),
              Text('Cargo: ${conflict.currentCargoWeightMt} MT'),
            ],
            const SizedBox(height: 12),
            Text(
              'Do you want to move $name to $newVehicleNumber?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$name will be removed from $oldVehicle and assigned to $newVehicleNumber.',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Move Driver'),
          ),
        ],
      );
    },
  );
  return result == true;
}

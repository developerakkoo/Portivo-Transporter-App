import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme/app_colors.dart';
import '../services/device_permission_service.dart';

/// Bottom sheet modal explaining app permissions and allowing the user to grant them.
class PermissionModal extends StatefulWidget {
  const PermissionModal({super.key});

  /// Show the permission modal as a bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PermissionModal(),
    );
  }

  @override
  State<PermissionModal> createState() => _PermissionModalState();
}

class _PermissionModalState extends State<PermissionModal> {
  final DevicePermissionService _permissionService = DevicePermissionService();
  bool _isRequesting = false;
  bool _hasPermanentlyDenied = false;

  static const List<({String title, String reason, IconData icon})> _permissions = [
    (
      title: 'Location',
      reason: 'To show your position on the map and for trip tracking',
      icon: Icons.location_on_outlined,
    ),
    (
      title: 'Camera',
      reason: 'To capture documents and photos',
      icon: Icons.camera_alt_outlined,
    ),
  ];

  Future<void> _requestPermissions() async {
    final navigator = Navigator.of(context);
    setState(() => _isRequesting = true);

    final statuses = await _permissionService.requestLoginPromptPermissions();

    if (mounted) {
      final hasPermanentlyDenied = DevicePermissionService.loginPromptPermissions.any(
        (p) => statuses[p]?.isPermanentlyDenied ?? false,
      );
      setState(() {
        _isRequesting = false;
        _hasPermanentlyDenied = hasPermanentlyDenied;
      });

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final allOk = await _permissionService.areLoginGatePermissionsGranted();

      if (!mounted) return;
      if (allOk || !hasPermanentlyDenied) {
        navigator.pop();
      }
    }
  }

  Future<void> _openSettings() async {
    await _permissionService.openSettings();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: AppColors.dividerGrey,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              Text(
                'Permissions Needed',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'The app needs the following permissions to work properly. Contacts access is only requested when you add a driver from your contacts.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20.0),
              ..._permissions.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Icon(
                          p.icon,
                          color: AppColors.primary,
                          size: 24.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              p.reason,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              if (_hasPermanentlyDenied) ...[
                SizedBox(
                  height: 52.0,
                  child: OutlinedButton(
                    onPressed: _isRequesting ? null : _openSettings,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: const Text('Open Settings'),
                  ),
                ),
                const SizedBox(height: 12.0),
              ],
              SizedBox(
                height: 52.0,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          height: 24.0,
                          width: 24.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.background,
                            ),
                          ),
                        )
                      : Text(_hasPermanentlyDenied ? 'Try Again' : 'Allow Permissions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

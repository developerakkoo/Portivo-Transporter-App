import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/driver_model.dart';
import '../../widgets/open_app_drawer_button.dart';
import '../../providers/driver_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';

class DriversTab extends StatefulWidget {
  const DriversTab({super.key});

  @override
  State<DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<DriversTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().loadDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverProvider>(
      builder: (context, driverProvider, child) {
        final drivers = driverProvider.drivers;
        final isLoading = driverProvider.isLoading;
        final error = driverProvider.error;

        if (isLoading && drivers.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: const OpenAppDrawerButton(),
              title: const Text('Drivers'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (error != null && drivers.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: const OpenAppDrawerButton(),
              title: const Text('Drivers'),
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
                    'Error loading drivers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () => driverProvider.loadDrivers(refresh: true),
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
            leading: const OpenAppDrawerButton(),
            title: const Text('Drivers'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading
                    ? null
                    : () => driverProvider.loadDrivers(refresh: true),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => driverProvider.loadDrivers(refresh: true),
            child: drivers.isEmpty
                ? _buildEmptyState(Theme.of(context).textTheme)
                : _buildDriversList(drivers, Theme.of(context).textTheme, driverProvider),
          ),
          floatingActionButton: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final permissionService = PermissionService(authProvider);
              // Only show "Add Driver" button if user has manageDrivers permission or is transporter
              if (permissionService.hasPermission('manageDrivers') || permissionService.isTransporter) {
                return FloatingActionButton(
                  heroTag: 'fab_drivers_add',
                  onPressed: () {
                    Navigator.of(context).pushNamed('/add-driver').then((result) {
                      if (result == true) {
                        driverProvider.loadDrivers(refresh: true);
                      }
                    });
                  },
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: AppColors.background),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildDriversList(List<DriverModel> drivers, TextTheme textTheme, DriverProvider driverProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        return _buildDriverCard(driver, textTheme, driverProvider);
      },
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outlined,
              size: 64.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 24.0),
            Text(
              'No drivers yet',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              'Drivers are automatically created when they first login via OTP',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAccessToggleChanged(DriverModel driver, bool granted, DriverProvider driverProvider) async {
    if (driver.status == 'active' && !granted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Block Driver'),
          content: Text('Block ${driver.name ?? 'this driver'}? They will not be able to log in.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Block', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final newStatus = granted ? 'active' : 'blocked';
    final updated = await driverProvider.updateDriver(id: driver.id, status: newStatus);
    if (!mounted) return;
    if (updated != null) {
      showUserSuccessSnackBar(
        context,
        granted
            ? 'Access granted to ${driver.name ?? 'driver'}'
            : '${driver.name ?? 'Driver'} has been blocked',
      );
    } else {
      showUserErrorSnackBar(
        context,
        driverProvider.error,
        fallback: 'Failed to update driver',
      );
    }
  }

  Widget _buildDriverCard(DriverModel driver, TextTheme textTheme, DriverProvider driverProvider) {
    final isAccessGranted = driver.status.toLowerCase() == 'active';
    final isBlocked = driver.status.toLowerCase() == 'blocked';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.offWhite,
              child: Text(
                (driver.name?.isNotEmpty == true) ? driver.name![0].toUpperCase() : 'D',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          driver.name ?? 'Driver',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isBlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            'Blocked',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    driver.mobile,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    children: [
                      Text(
                        'Access',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Semantics(
                        label: isAccessGranted ? 'Access granted' : 'Access blocked',
                        child: Switch(
                          value: isAccessGranted,
                          onChanged: driverProvider.isLoading
                              ? null
                              : (granted) => _onAccessToggleChanged(driver, granted, driverProvider),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'edit') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit driver feature coming soon')),
                  );
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Driver'),
                      content: Text('Are you sure you want to delete ${driver.name ?? 'this driver'}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    final success = await driverProvider.deleteDriver(driver.id);
                    if (mounted) {
                      if (success) {
                        showUserSuccessSnackBar(context, 'Driver deleted successfully');
                      } else {
                        showUserErrorSnackBar(
                          context,
                          driverProvider.error,
                          fallback: 'Failed to delete driver',
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

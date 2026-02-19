import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/driver_model.dart';
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
              title: const Text('Drivers'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (error != null && drivers.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
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
                : _buildDriversList(drivers, Theme.of(context).textTheme),
          ),
          floatingActionButton: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final permissionService = PermissionService(authProvider);
              // Only show "Add Driver" button if user has manageDrivers permission or is transporter
              if (permissionService.hasPermission('manageDrivers') || permissionService.isTransporter) {
                return FloatingActionButton(
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

  Widget _buildDriversList(List<DriverModel> drivers, TextTheme textTheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        return _buildDriverCard(driver, textTheme);
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

  Widget _buildDriverCard(DriverModel driver, TextTheme textTheme) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.offWhite,
          child: Text(
            (driver.name?.isNotEmpty == true) ? driver.name![0].toUpperCase() : 'D',
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          driver.name ?? 'Driver',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            driver.mobile,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusChip(driver.status),
            const SizedBox(width: 8.0),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                final driverProvider = context.read<DriverProvider>();
                if (value == 'edit') {
                  // TODO: Navigate to edit driver screen
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Driver deleted successfully' : driverProvider.error ?? 'Failed to delete driver'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
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

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String label;
    
    switch (status.toLowerCase()) {
      case 'active':
        chipColor = AppColors.success;
        label = 'Active';
        break;
      case 'inactive':
        chipColor = AppColors.warning;
        label = 'Inactive';
        break;
      case 'pending':
        chipColor = AppColors.info;
        label = 'Pending';
        break;
      case 'blocked':
        chipColor = AppColors.error;
        label = 'Blocked';
        break;
      default:
        chipColor = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: chipColor.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

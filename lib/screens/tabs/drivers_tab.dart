import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/driver.dart';

class DriversTab extends StatefulWidget {
  const DriversTab({super.key});

  @override
  State<DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<DriversTab> {
  List<Driver> _drivers = [];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Drivers'),
      ),
      body: _drivers.isEmpty
          ? _buildEmptyState(textTheme)
          : _buildDriversList(textTheme),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/add-driver').then((result) {
            if (result != null && result is Driver) {
              setState(() {
                _drivers.add(result);
              });
            }
          });
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
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
              'Add your first driver to get started',
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

  Widget _buildDriversList(TextTheme textTheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return _buildDriverCard(driver, textTheme);
      },
    );
  }

  Widget _buildDriverCard(Driver driver, TextTheme textTheme) {
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
            driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'D',
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          driver.name,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            driver.phone,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: _buildStatusChip(driver.status),
      ),
    );
  }

  Widget _buildStatusChip(DriverStatus status) {
    Color chipColor;
    switch (status) {
      case DriverStatus.active:
        chipColor = AppColors.success;
        break;
      case DriverStatus.notInstalled:
        chipColor = AppColors.warning;
        break;
      case DriverStatus.pending:
        chipColor = AppColors.info;
        break;
    }

    String label;
    switch (status) {
      case DriverStatus.active:
        label = 'Active';
        break;
      case DriverStatus.notInstalled:
        label = 'Not Installed';
        break;
      case DriverStatus.pending:
        label = 'Pending';
        break;
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

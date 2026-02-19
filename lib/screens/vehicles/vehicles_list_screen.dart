import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vehicle_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';

class VehiclesListScreen extends StatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  State<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all';
  String _filterOwnerType = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().loadVehicles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVehicles() {
    final vehicleProvider = context.read<VehicleProvider>();
    String? status = _filterStatus != 'all' ? _filterStatus : null;
    String? ownerType = _filterOwnerType != 'all' ? _filterOwnerType : null;
    vehicleProvider.loadVehicles(status: status, ownerType: ownerType, refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, authChild) {
        final permissionService = PermissionService(authProvider);
        
        // Check permission - redirect if unauthorized
        if (!permissionService.hasPermission('manageVehicles') && !permissionService.isTransporter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to access vehicles'),
                backgroundColor: Colors.red,
              ),
            );
          });
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Vehicles')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Consumer<VehicleProvider>(
        builder: (context, vehicleProvider, child) {
          final vehicles = vehicleProvider.vehicles;
          final isLoading = vehicleProvider.isLoading;
          final error = vehicleProvider.error;

          // Filter by search query
          final query = _searchController.text.toLowerCase();
          final filteredVehicles = query.isEmpty
              ? vehicles
              : vehicles.where((v) =>
                  v.vehicleNumber.toLowerCase().contains(query) ||
                  (v.trailerType?.toLowerCase().contains(query) ?? false)).toList();

          if (isLoading && vehicles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null && vehicles.isEmpty) {
            return Center(
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
                    'Error loading vehicles',
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
                    onPressed: () => vehicleProvider.loadVehicles(refresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by vehicle number or trailer type',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // Vehicles List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => vehicleProvider.loadVehicles(refresh: true),
                  child: filteredVehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                size: 64.0,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 16.0),
                              Text(
                                vehicles.isEmpty
                                    ? 'No vehicles yet'
                                    : 'No vehicles match your search',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredVehicles[index];
                            return _buildVehicleCard(vehicle, textTheme);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .pushNamed('/add-vehicle')
              .then((_) => context.read<VehicleProvider>().loadVehicles(refresh: true));
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
    );
      },
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle, TextTheme textTheme) {
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
      child: InkWell(
        onTap: () {
          Navigator.of(context)
              .pushNamed('/edit-vehicle', arguments: vehicle.id)
              .then((_) => context.read<VehicleProvider>().loadVehicles(refresh: true));
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.primary,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.vehicleNumber,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '${vehicle.ownerType}${vehicle.trailerType != null ? ' • ${vehicle.trailerType}' : ''}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(vehicle.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status.toLowerCase()) {
      case 'active':
        chipColor = AppColors.success;
        break;
      case 'inactive':
        chipColor = AppColors.warning;
        break;
      default:
        chipColor = AppColors.textMuted;
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
        status.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Vehicles'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _filterStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value ?? 'all';
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  value: _filterOwnerType,
                  decoration: const InputDecoration(
                    labelText: 'Owner Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'OWN', child: Text('Own')),
                    DropdownMenuItem(value: 'HIRED', child: Text('Hired')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterOwnerType = value ?? 'all';
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _filterVehicles();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

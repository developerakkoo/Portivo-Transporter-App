import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/vehicle_driver_resolver.dart';
import '../../data/models/driver_model.dart';
import '../../data/models/rc_verification.dart';
import '../../data/models/vehicle_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';

class VehiclesListScreen extends StatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  State<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().loadVehicles();
      context.read<DriverProvider>().loadDrivers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _filterVehicles() {
    final vehicleProvider = context.read<VehicleProvider>();
    String? status = _filterStatus != 'all' ? _filterStatus : null;
    vehicleProvider.loadVehicles(status: status, refresh: true);
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
        title: const Text('Fleet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Vehicles'),
            Tab(text: 'Drivers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Consumer2<VehicleProvider, DriverProvider>(
        builder: (context, vehicleProvider, driverProvider, child) {
          final vehicles = vehicleProvider.vehicles;
          final isLoading = vehicleProvider.isLoading;
          final error = vehicleProvider.error;
          final drivers = driverProvider.drivers;

          final query = _searchController.text.toLowerCase().trim();
          final filteredVehicles = query.isEmpty
              ? vehicles
              : vehicles
                  .where((v) => _vehicleMatchesQuery(v, query, drivers))
                  .toList();

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
                    hintText: 'Search by vehicle number, trailer type, or driver',
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
                                Icons.inventory_2_outlined,
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
          Consumer<DriverProvider>(
            builder: (context, driverProvider, _) {
              final drivers = driverProvider.drivers;
              if (driverProvider.isLoading && drivers.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (drivers.isEmpty) {
                return const Center(child: Text('No drivers yet'));
              }
              return RefreshIndicator(
                onRefresh: () => driverProvider.loadDrivers(refresh: true),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.dividerGrey),
                      ),
                      child: ListTile(
                        title: Text(driver.name ?? 'Driver'),
                        subtitle: Text(
                          '${driver.mobile}${driver.status.isNotEmpty ? ' · ${driver.status}' : ''}',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .pushNamed('/add-fleet')
              .then((_) {
                context.read<VehicleProvider>().loadVehicles(refresh: true);
                context.read<DriverProvider>().loadDrivers(refresh: true);
              });
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
    );
      },
    );
  }

  bool _vehicleMatchesQuery(
    VehicleModel vehicle,
    String query,
    List<DriverModel> drivers,
  ) {
    if (vehicle.vehicleNumber.toLowerCase().contains(query)) return true;
    if (vehicle.vehicleType?.toLowerCase().contains(query) ?? false) {
      return true;
    }
    if (vehicle.trailerType?.toLowerCase().contains(query) ?? false) {
      return true;
    }
    final nested = vehicle.driver;
    if (nested != null) {
      if (nested.name?.toLowerCase().contains(query) ?? false) return true;
      if (nested.mobile.toLowerCase().contains(query)) return true;
    }
    final resolved = resolveDriverForVehicle(vehicle, drivers);
    if (resolved != null) {
      if (resolved.name?.toLowerCase().contains(query) ?? false) return true;
      if (resolved.mobile.toLowerCase().contains(query)) return true;
    }
    return false;
  }

  Widget _buildVehicleCard(VehicleModel vehicle, TextTheme textTheme) {
    context.watch<DriverProvider>();
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
                      Icons.inventory_2,
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
                        if ([
                          if (vehicle.vehicleType != null &&
                              vehicle.vehicleType!.isNotEmpty)
                            vehicle.vehicleType,
                          if (vehicle.trailerType != null &&
                              vehicle.trailerType!.isNotEmpty)
                            vehicle.trailerType,
                        ].isNotEmpty)
                          Text(
                            [
                              if (vehicle.vehicleType != null &&
                                  vehicle.vehicleType!.isNotEmpty)
                                vehicle.vehicleType,
                              if (vehicle.trailerType != null &&
                                  vehicle.trailerType!.isNotEmpty)
                                vehicle.trailerType,
                            ].join(' • '),
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (vehicle.rcVerification != null)
                          Text(
                            'RC: ${rcStatusShortLabel(vehicle.rcVerification!.status)}',
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
              if (_driverSubtitle(vehicle) != null) ...[
                const SizedBox(height: 10.0),
                Text(
                  _driverSubtitle(vehicle)!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _driverSubtitle(VehicleModel vehicle) {
    final nested = vehicle.driver;
    if (nested != null) {
      final name = nested.name?.trim().isNotEmpty == true ? nested.name!.trim() : 'Driver';
      return '$name · ${nested.mobile}';
    }
    final drivers = context.read<DriverProvider>().drivers;
    final resolved = resolveDriverForVehicle(vehicle, drivers);
    if (resolved == null) return null;
    final name = resolved.name?.trim().isNotEmpty == true ? resolved.name!.trim() : 'Driver';
    return '$name · ${resolved.mobile}';
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    var label = status;
    switch (status.toLowerCase()) {
      case 'active':
        chipColor = AppColors.success;
        label = 'Active';
        break;
      case 'inactive':
        chipColor = AppColors.warning;
        label = 'In Maintenance';
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
        label,
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

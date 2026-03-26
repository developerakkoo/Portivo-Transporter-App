import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../data/models/vehicle_model.dart';
import '../providers/vehicle_provider.dart';

class SearchVehicleScreen extends StatefulWidget {
  const SearchVehicleScreen({super.key});

  @override
  State<SearchVehicleScreen> createState() => _SearchVehicleScreenState();
}

class _SearchVehicleScreenState extends State<SearchVehicleScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().loadVehicles();
    });
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectVehicle(VehicleModel vehicle) {
    Navigator.of(context).pop(vehicle);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search Vehicle'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by vehicle number',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),

            // Vehicle List
            Expanded(
              child: Consumer<VehicleProvider>(
                builder: (context, vehicleProvider, child) {
                  final vehicles = vehicleProvider.vehicles;
                  final query = _searchController.text.toLowerCase();
                  final filteredVehicles = query.isEmpty
                      ? vehicles
                      : vehicles.where((v) =>
                          v.vehicleNumber.toLowerCase().contains(query) ||
                          (v.trailerType?.toLowerCase().contains(query) ?? false)).toList();

                  if (vehicleProvider.isLoading && vehicles.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (filteredVehicles.isEmpty) {
                    return Center(
                      child: Text(
                        vehicles.isEmpty ? 'No vehicles yet' : 'No vehicles match your search',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    itemCount: filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = filteredVehicles[index];
                      return _buildVehicleItem(vehicle, textTheme);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleItem(VehicleModel vehicle, TextTheme textTheme) {
    return InkWell(
      onTap: () => _selectVehicle(vehicle),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: AppColors.dividerGrey,
            width: 1.0,
          ),
        ),
        child: Row(
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
            const SizedBox(width: 16.0),
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
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

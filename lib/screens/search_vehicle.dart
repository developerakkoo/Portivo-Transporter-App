import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class SearchVehicleScreen extends StatefulWidget {
  const SearchVehicleScreen({super.key});

  @override
  State<SearchVehicleScreen> createState() => _SearchVehicleScreenState();
}

class _SearchVehicleScreenState extends State<SearchVehicleScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredVehicles = [];

  // Placeholder vehicle data
  final List<Map<String, String>> _allVehicles = [
    {'number': 'ABC-1234', 'type': 'Truck', 'model': 'Mercedes Actros'},
    {'number': 'XYZ-5678', 'type': 'Van', 'model': 'Ford Transit'},
    {'number': 'DEF-9012', 'type': 'Truck', 'model': 'Volvo FH16'},
    {'number': 'GHI-3456', 'type': 'Van', 'model': 'Mercedes Sprinter'},
    {'number': 'JKL-7890', 'type': 'Truck', 'model': 'Scania R450'},
    {'number': 'MNO-2345', 'type': 'Van', 'model': 'Iveco Daily'},
    {'number': 'PQR-6789', 'type': 'Truck', 'model': 'MAN TGX'},
    {'number': 'STU-0123', 'type': 'Van', 'model': 'Renault Master'},
  ];

  @override
  void initState() {
    super.initState();
    _filteredVehicles = _allVehicles;
    _searchController.addListener(_filterVehicles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVehicles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredVehicles = _allVehicles;
      } else {
        _filteredVehicles = _allVehicles
            .where((vehicle) =>
                vehicle['number']!.toLowerCase().contains(query) ||
                vehicle['type']!.toLowerCase().contains(query) ||
                vehicle['model']!.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _selectVehicle(Map<String, String> vehicle) {
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
              child: _filteredVehicles.isEmpty
                  ? Center(
                      child: Text(
                        'No vehicles found',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: _filteredVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _filteredVehicles[index];
                        return _buildVehicleItem(vehicle, textTheme);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleItem(Map<String, String> vehicle, TextTheme textTheme) {
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
                Icons.directions_car,
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
                    vehicle['number']!,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    '${vehicle['type']} • ${vehicle['model']}',
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

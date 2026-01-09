import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Placeholder trip data
  final Map<String, List<Map<String, dynamic>>> _tripsData = {
    'Running': [
      {
        'id': '1',
        'containerId': 'CONT-2024-001',
        'reference': 'REF-001',
        'driverName': 'John Doe',
        'vehicleNumber': 'ABC-1234',
        'origin': 'Warehouse A',
        'destination': 'Distribution Center B',
        'status': 'Running',
        'eta': '2h 30m',
        'isPinned': false,
      },
      {
        'id': '2',
        'containerId': 'CONT-2024-002',
        'reference': 'REF-002',
        'driverName': 'Jane Smith',
        'vehicleNumber': 'XYZ-5678',
        'origin': 'Port Terminal',
        'destination': 'Warehouse C',
        'status': 'Running',
        'eta': '1h 15m',
        'isPinned': true,
      },
      {
        'id': '3',
        'containerId': 'CONT-2024-003',
        'reference': null,
        'driverName': 'Mike Johnson',
        'vehicleNumber': 'DEF-9012',
        'origin': 'Factory X',
        'destination': 'Port Terminal',
        'status': 'Running',
        'eta': '3h 45m',
        'isPinned': false,
      },
    ],
    'Completed': [
      {
        'id': '4',
        'containerId': 'CONT-2024-004',
        'reference': 'REF-003',
        'driverName': 'Sarah Williams',
        'vehicleNumber': 'GHI-3456',
        'origin': 'Warehouse B',
        'destination': 'Customer Site',
        'status': 'Completed',
        'eta': null,
        'isPinned': false,
      },
      {
        'id': '5',
        'containerId': 'CONT-2024-005',
        'reference': 'REF-004',
        'driverName': 'Tom Brown',
        'vehicleNumber': 'JKL-7890',
        'origin': 'Distribution Center',
        'destination': 'Retail Store',
        'status': 'Completed',
        'eta': null,
        'isPinned': true,
      },
    ],
    'POD Pending': [
      {
        'id': '6',
        'containerId': 'CONT-2024-006',
        'reference': 'REF-005',
        'driverName': 'Emily Davis',
        'vehicleNumber': 'MNO-2345',
        'origin': 'Warehouse A',
        'destination': 'Customer Location',
        'status': 'POD Pending',
        'eta': null,
        'isPinned': false,
      },
      {
        'id': '7',
        'containerId': 'CONT-2024-007',
        'reference': 'REF-006',
        'driverName': 'David Wilson',
        'vehicleNumber': 'PQR-6789',
        'origin': 'Port Terminal',
        'destination': 'Distribution Hub',
        'status': 'POD Pending',
        'eta': null,
        'isPinned': true,
      },
    ],
  };

  // Store pinned state and order per segment
  final Map<String, Set<String>> _pinnedTrips = {
    'Running': {'2'},
    'Completed': {'5'},
    'POD Pending': {'7'},
  };
  
  final Map<String, List<String>> _tripOrder = {
    'Running': ['2', '1', '3'],
    'Completed': ['5', '4'],
    'POD Pending': ['7', '6'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentSegment {
    switch (_tabController.index) {
      case 0:
        return 'Running';
      case 1:
        return 'Completed';
      case 2:
        return 'POD Pending';
      default:
        return 'Running';
    }
  }

  List<Map<String, dynamic>> get _filteredTrips {
    final segment = _currentSegment;
    final allTrips = _tripsData[segment] ?? [];
    final searchQuery = _searchController.text.toLowerCase();
    
    // Filter by search query
    List<Map<String, dynamic>> filtered = allTrips.where((trip) {
      if (searchQuery.isEmpty) return true;
      final containerId = (trip['containerId'] as String).toLowerCase();
      final reference = (trip['reference'] as String? ?? '').toLowerCase();
      return containerId.contains(searchQuery) || reference.contains(searchQuery);
    }).toList();

    // Sort: pinned first, then by order
    final pinned = _pinnedTrips[segment] ?? {};
    final order = _tripOrder[segment] ?? [];
    
    filtered.sort((a, b) {
      final aPinned = pinned.contains(a['id']);
      final bPinned = pinned.contains(b['id']);
      
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      if (aPinned && bPinned) {
        final aIndex = order.indexOf(a['id'] as String);
        final bIndex = order.indexOf(b['id'] as String);
        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
      }
      
      final aIndex = order.indexOf(a['id'] as String);
      final bIndex = order.indexOf(b['id'] as String);
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      return 0;
    });

    return filtered;
  }

  void _togglePin(String tripId) {
    setState(() {
      final segment = _currentSegment;
      final pinned = _pinnedTrips[segment] ?? {};
      if (pinned.contains(tripId)) {
        pinned.remove(tripId);
      } else {
        pinned.add(tripId);
      }
      _pinnedTrips[segment] = pinned;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final segment = _currentSegment;
      final trips = _filteredTrips;
      final pinned = _pinnedTrips[segment] ?? {};
      
      // Separate pinned and unpinned
      final pinnedTrips = trips.where((t) => pinned.contains(t['id'])).toList();
      final unpinnedTrips = trips.where((t) => !pinned.contains(t['id'])).toList();
      
      // Determine which list the item is in
      if (oldIndex < pinnedTrips.length) {
        // Moving within pinned items
        if (newIndex < pinnedTrips.length) {
          final item = pinnedTrips.removeAt(oldIndex);
          pinnedTrips.insert(newIndex, item);
        } else {
          // Cannot move pinned item below unpinned
          return;
        }
      } else {
        // Moving within unpinned items
        final unpinnedIndex = oldIndex - pinnedTrips.length;
        final newUnpinnedIndex = newIndex - pinnedTrips.length;
        if (newUnpinnedIndex >= 0 && newUnpinnedIndex < unpinnedTrips.length) {
          final item = unpinnedTrips.removeAt(unpinnedIndex);
          unpinnedTrips.insert(newUnpinnedIndex, item);
        } else {
          return;
        }
      }
      
      // Update order
      final newOrder = [
        ...pinnedTrips.map((t) => t['id'] as String),
        ...unpinnedTrips.map((t) => t['id'] as String),
      ];
      _tripOrder[segment] = newOrder;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).pushNamed('/create-trip');
            },
            tooltip: 'Add Trip',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Running'),
            Tab(text: 'Completed'),
            Tab(text: 'POD Pending'),
          ],
          onTap: (index) => setState(() {}),
        ),
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
                  hintText: 'Search by Container number/reference number',
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
              ),
            ),

            // Trips List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTripsList('Running', textTheme),
                  _buildTripsList('Completed', textTheme),
                  _buildTripsList('POD Pending', textTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList(String segment, TextTheme textTheme) {
    final trips = _filteredTrips;

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 24.0),
            Text(
              'No trips found',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      itemCount: trips.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _buildTripCard(trip, textTheme, index);
      },
    );
  }

  Widget _buildTripCard(
    Map<String, dynamic> trip,
    TextTheme textTheme,
    int index,
  ) {
    final segment = _currentSegment;
    final isPinned = _pinnedTrips[segment]?.contains(trip['id']) ?? false;

    return Container(
      key: Key('trip_${trip['id']}'),
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isPinned ? AppColors.primary : AppColors.dividerGrey,
          width: isPinned ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Container ID and Pin Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trip['containerId'] as String,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? AppColors.primary : AppColors.textSecondary,
                ),
                onPressed: () => _togglePin(trip['id'] as String),
                tooltip: isPinned ? 'Unpin' : 'Pin',
              ),
            ],
          ),

          // Trip Reference (if available)
          if (trip['reference'] != null) ...[
            const SizedBox(height: 4.0),
            Text(
              trip['reference'] as String,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: 16.0),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(trip['status'] as String).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text(
              trip['status'] as String,
              style: textTheme.labelSmall?.copyWith(
                color: _getStatusColor(trip['status'] as String),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 16.0),

          // Driver Name
          _buildTripInfoRow(
            icon: Icons.person_outline,
            label: 'Driver',
            value: trip['driverName'] as String,
            textTheme: textTheme,
          ),

          const SizedBox(height: 12.0),

          // Vehicle Number
          _buildTripInfoRow(
            icon: Icons.directions_car_outlined,
            label: 'Vehicle',
            value: trip['vehicleNumber'] as String,
            textTheme: textTheme,
          ),

          const SizedBox(height: 12.0),

          // Origin → Destination
          Row(
            children: [
              Expanded(
                child: _buildTripInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Origin',
                  value: trip['origin'] as String,
                  textTheme: textTheme,
                ),
              ),
              const SizedBox(width: 16.0),
              Icon(
                Icons.arrow_forward,
                color: AppColors.textSecondary,
                size: 20.0,
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: _buildTripInfoRow(
                  icon: Icons.location_on,
                  label: 'Destination',
                  value: trip['destination'] as String,
                  textTheme: textTheme,
                ),
              ),
            ],
          ),

          // ETA (if available)
          if (trip['eta'] != null) ...[
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.primary,
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'ETA: ${trip['eta'] as String}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18.0, color: AppColors.textSecondary),
        const SizedBox(width: 8.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Running':
        return AppColors.info;
      case 'Completed':
        return AppColors.success;
      case 'POD Pending':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}

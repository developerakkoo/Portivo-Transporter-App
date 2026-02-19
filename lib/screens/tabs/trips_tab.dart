import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/helpers.dart';
import '../../data/models/trip_model.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../services/permission_service.dart';
import 'package:flutter/foundation.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> 
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final SocketService _socketService = SocketService();
  bool _hasInitialized = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(() {
      setState(() {});
    });
    
    // Load trips when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTripsTab();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app resumes
      _refreshTrips();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
    // Note: We don't refresh on status tab switch (Active/Completed/POD Pending)
    // because the data is already filtered correctly by status.
    // Real-time Socket.IO updates handle status changes automatically.
  }

  Future<void> _initializeTripsTab() async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    // Ensure Socket.IO is connected
    await _ensureSocketConnection();

    // Load trips
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    await tripProvider.loadTrips(refresh: true);
  }

  Future<void> _ensureSocketConnection() async {
    try {
      // Check if Socket.IO is connected
      if (!_socketService.isConnected) {
        if (kDebugMode) {
          print('TripsTab: Socket.IO not connected, connecting...');
        }
        await _socketService.connect();
      }

      // Ensure transporter room is joined
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        _socketService.joinTransporterRoom(authProvider.user!.id);
        if (kDebugMode) {
          print('TripsTab: Joined transporter room: ${authProvider.user!.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TripsTab: Error ensuring Socket.IO connection: $e');
      }
      // Don't fail if Socket.IO connection fails
    }
  }


  Future<void> _refreshTrips() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    await tripProvider.loadTrips(refresh: true);
  }

  List<TripModel> _getFilteredTrips(List<TripModel> trips) {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) return trips;
    
    return trips.where((trip) {
      final containerId = (trip.containerNumber ?? '').toLowerCase();
      final reference = (trip.reference ?? '').toLowerCase();
      return containerId.contains(searchQuery) || reference.contains(searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final permissionService = PermissionService(authProvider);
              // Only show "Add Trip" button if user has createTrips permission or is transporter
              // Note: hasPermission already returns true for transporters, so the OR is redundant but safe
              final canCreateTrip = permissionService.hasPermission('createTrips') || permissionService.isTransporter;
              
              if (kDebugMode) {
                print('TripsTab: canCreateTrip check - result: $canCreateTrip');
                print('TripsTab: User: ${authProvider.user?.id}, userType: ${authProvider.user?.userType}');
              }
              
              if (canCreateTrip) {
                return IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    // Navigate to create trip screen and wait for return
                    await Navigator.of(context).pushNamed('/create-trip');
                    // Refresh trips when returning from create trip screen
                    _refreshTrips();
                  },
                  tooltip: 'Add Trip',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Active'),
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
              child: Consumer<TripProvider>(
                builder: (context, tripProvider, child) {
                  if (tripProvider.isLoading && tripProvider.trips.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (tripProvider.error != null && tripProvider.trips.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tripProvider.error!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          ElevatedButton(
                            onPressed: () {
                              tripProvider.clearError();
                              tripProvider.loadTrips(refresh: true);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTripsList(AppConstants.tripStatusActive, textTheme),
                      _buildTripsList(AppConstants.tripStatusCompleted, textTheme),
                      _buildTripsList(AppConstants.tripStatusPodPending, textTheme),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList(String status, TextTheme textTheme) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        List<TripModel> trips;
        switch (status) {
          case AppConstants.tripStatusActive:
            // Show both ACTIVE and PLANNED trips in Active tab
            // (planned trips are queued for activation)
            trips = [
              ...tripProvider.activeTrips,
              ...tripProvider.plannedTrips,
            ];
            break;
          case AppConstants.tripStatusCompleted:
            trips = tripProvider.completedTrips;
            break;
          case AppConstants.tripStatusPodPending:
            trips = tripProvider.podPendingTrips;
            break;
          default:
            trips = [];
        }

        final filteredTrips = _getFilteredTrips(trips);

        if (filteredTrips.isEmpty) {
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

        return RefreshIndicator(
          onRefresh: () async {
            await tripProvider.loadTrips(refresh: true);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: filteredTrips.length,
            itemBuilder: (context, index) {
              final trip = filteredTrips[index];
              return _buildTripCard(trip, textTheme, index);
            },
          ),
        );
      },
    );
  }

  Widget _buildTripCard(
    TripModel trip,
    TextTheme textTheme,
    int index,
  ) {

    return Container(
      key: Key('trip_${trip.id}'),
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed('/trip-detail', arguments: trip.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Container ID and Trip ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trip.containerNumber != null)
                        Text(
                          trip.containerNumber!,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      if (trip.tripId.isNotEmpty) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          trip.tripId,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Trip Reference (if available)
            if (trip.reference != null) ...[
              const SizedBox(height: 4.0),
              Text(
                trip.reference!,
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
                color: _getStatusColor(trip.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                Helpers.getStatusLabel(trip.status),
                style: textTheme.labelSmall?.copyWith(
                  color: _getStatusColor(trip.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16.0),

            // Trip Type
            _buildTripInfoRow(
              icon: Icons.local_shipping_outlined,
              label: 'Type',
              value: Helpers.getTripTypeLabel(trip.tripType),
              textTheme: textTheme,
            ),

            const SizedBox(height: 12.0),

            // Origin → Destination
            if (trip.pickupLocation != null || trip.dropLocation != null)
              Row(
                children: [
                  if (trip.pickupLocation != null)
                    Expanded(
                      child: _buildTripInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Origin',
                        value: trip.pickupLocation!.address ?? 'Location',
                        textTheme: textTheme,
                      ),
                    ),
                  if (trip.pickupLocation != null && trip.dropLocation != null) ...[
                    const SizedBox(width: 16.0),
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.textSecondary,
                      size: 20.0,
                    ),
                    const SizedBox(width: 16.0),
                  ],
                  if (trip.dropLocation != null)
                    Expanded(
                      child: _buildTripInfoRow(
                        icon: Icons.location_on,
                        label: 'Destination',
                        value: trip.dropLocation!.address ?? 'Location',
                        textTheme: textTheme,
                      ),
                    ),
                ],
              ),

            // Created Date
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
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Created: ${Helpers.formatDateTime(trip.createdAt)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    switch (status.toUpperCase()) {
      case AppConstants.tripStatusActive:
        return AppColors.info;
      case AppConstants.tripStatusCompleted:
        return AppColors.success;
      case AppConstants.tripStatusPodPending:
        return AppColors.warning;
      case AppConstants.tripStatusPlanned:
        return AppColors.textSecondary;
      case AppConstants.tripStatusCancelled:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

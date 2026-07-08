import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_copy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/trip_model.dart';
import '../../core/utils/user_feedback.dart';
import '../../providers/trip_provider.dart';
import '../../providers/pinned_trips_provider.dart';
import '../../providers/navigation_state_provider.dart';
import '../../widgets/open_app_drawer_button.dart';
import '../../widgets/trip_expansion_card.dart';
import '../../providers/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../core/utils/create_trip_navigation.dart';
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
  String? _lastHighlightTripIdScheduled;
  int _lastHandledOpenTripsSubTabNonce = 0;
  int _lastScheduledOpenTripsSubTabNonce = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 5, vsync: this);
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
    if (!mounted) return;

    // Load trips and pinned IDs
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final pinnedProvider = Provider.of<PinnedTripsProvider>(context, listen: false);
    await tripProvider.bootstrapTripsIfNeeded();
    await pinnedProvider.load();
    await pinnedProvider.reconcileWithTripProvider(tripProvider);
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

      if (!mounted) return;

      // Ensure transporter room is joined
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        final u = authProvider.user!;
        final roomId = u.transporterId ?? u.id;
        _socketService.joinTransporterRoom(roomId);
        if (kDebugMode) {
          print('TripsTab: Joined transporter room: $roomId');
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
    await _onPullRefreshTrips();
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

  List<TripModel> _mergeTripsUniqueById(List<TripModel> items) {
    final seen = <String>{};
    final out = <TripModel>[];
    for (final t in items) {
      if (seen.add(t.id)) out.add(t);
    }
    return out;
  }

  Future<void> _onPullRefreshTrips() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final pinnedProvider = Provider.of<PinnedTripsProvider>(context, listen: false);
    await tripProvider.bootstrapTripsIfNeeded();
    if (!mounted) return;
    await pinnedProvider.reconcileWithTripProvider(tripProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const OpenAppDrawerButton(),
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
                    await openCreateTripFlow(context);
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: AppCopy.awaitingPod),
            Tab(text: AppCopy.completed),
            Tab(text: AppCopy.cancelled),
            Tab(text: 'Marketplace'),
          ],
          onTap: (index) => setState(() {}),
        ),
      ),
      body: Consumer<NavigationStateProvider>(
        builder: (context, navState, _) {
          if (navState.pendingHighlightTripId != null &&
              _lastHighlightTripIdScheduled != navState.pendingHighlightTripId) {
            _lastHighlightTripIdScheduled = navState.pendingHighlightTripId;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              final tripProvider = Provider.of<TripProvider>(context, listen: false);
              await tripProvider.loadAvailableTrips(refresh: true);
              if (!mounted) return;
              _tabController.animateTo(
                navState.pendingTripsSubTabIndex ?? 4,
              );
              _scheduleClearHighlight(navState);
            });
          } else if (navState.pendingHighlightTripId == null) {
            _lastHighlightTripIdScheduled = null;
          }

          if (navState.pendingOpenTripsSubTabOnly != null &&
              navState.openTripsSubTabNonce > _lastScheduledOpenTripsSubTabNonce) {
            _lastScheduledOpenTripsSubTabNonce = navState.openTripsSubTabNonce;
            final capturedNonce = navState.openTripsSubTabNonce;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final nav = context.read<NavigationStateProvider>();
              if (nav.openTripsSubTabNonce != capturedNonce) return;
              final idx = nav.pendingOpenTripsSubTabOnly;
              if (idx == null) return;
              if (idx >= 0 && idx < _tabController.length) {
                _tabController.animateTo(idx);
              }
              nav.clearPendingOpenTripsSubTab();
              _lastHandledOpenTripsSubTabNonce = capturedNonce;
            });
          } else if (navState.pendingOpenTripsSubTabOnly == null) {
            _lastScheduledOpenTripsSubTabNonce = _lastHandledOpenTripsSubTabNonce;
          }

          return SafeArea(
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
                    return RefreshIndicator(
                      onRefresh: _onPullRefreshTrips,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  tripProvider.error!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16.0),
                                ElevatedButton(
                                  onPressed: () {
                                    tripProvider.clearError();
                                    _onPullRefreshTrips();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTripsList(AppConstants.tripStatusActive, textTheme, highlightTripId: navState.pendingHighlightTripId),
                      _buildTripsList(AppConstants.tripStatusPodPending, textTheme, highlightTripId: navState.pendingHighlightTripId),
                      _buildTripsList(AppConstants.tripStatusCompleted, textTheme, highlightTripId: navState.pendingHighlightTripId),
                      _buildTripsList(AppConstants.tripStatusCancelled, textTheme, highlightTripId: navState.pendingHighlightTripId),
                      _buildTripsList(AppConstants.tripTabMarketplace, textTheme, highlightTripId: navState.pendingHighlightTripId),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
        },
      ),
    );
  }

  Widget _buildTripsList(String status, TextTheme textTheme, {String? highlightTripId}) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        List<TripModel> trips;
        final bool showAcceptButton;
        switch (status) {
          case AppConstants.tripStatusActive:
            // ACTIVE, PLANNED, ACCEPTED, and BOOKED (from main list — e.g. customer bookings)
            trips = _mergeTripsUniqueById([
              ...tripProvider.activeTrips,
              ...tripProvider.plannedTrips,
              ...tripProvider.acceptedTrips,
              ...tripProvider.bookedTrips,
            ]);
            showAcceptButton = false;
            break;
          case AppConstants.tripStatusPodPending:
            trips = tripProvider.podPendingTrips;
            showAcceptButton = false;
            break;
          case AppConstants.tripStatusCompleted:
            trips = tripProvider.completedTrips;
            showAcceptButton = false;
            break;
          case AppConstants.tripStatusCancelled:
            trips = tripProvider.cancelledTrips;
            showAcceptButton = false;
            break;
          case AppConstants.tripTabMarketplace:
            trips = tripProvider.availableTrips;
            showAcceptButton = true;
            break;
          default:
            trips = [];
            showAcceptButton = false;
        }

        final filteredTrips = _getFilteredTrips(trips);
        final isMarketplace = status == AppConstants.tripTabMarketplace;

        if (filteredTrips.isEmpty) {
          return RefreshIndicator(
            onRefresh: _onPullRefreshTrips,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64.0,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 24.0),
                      Text(
                        isMarketplace
                            ? 'No customer offers for now'
                            : 'No trips found',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isMarketplace) ...[
                        const SizedBox(height: 8.0),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            'Open trips from customers that your transporter can accept appear here.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onPullRefreshTrips,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: filteredTrips.length,
            itemBuilder: (context, index) {
              final trip = filteredTrips[index];
              return _buildTripCard(trip, textTheme, index, showAcceptButton: showAcceptButton, highlightTripId: highlightTripId);
            },
          ),
        );
      },
    );
  }

  void _scheduleClearHighlight(NavigationStateProvider navState) {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        navState.clearTripHighlight();
      }
    });
  }

  Widget _buildTripCard(
    TripModel trip,
    TextTheme textTheme,
    int index, {
    bool showAcceptButton = false,
    String? highlightTripId,
  }) {
    final isHighlighted = highlightTripId != null && trip.id == highlightTripId;
    return Consumer<PinnedTripsProvider>(
      builder: (context, pinned, _) {
        return TripExpansionCard(
          trip: trip,
          textTheme: textTheme,
          isHighlighted: isHighlighted,
          showAcceptButton: showAcceptButton,
          isPinned: pinned.isPinned(trip.id),
          onPinTap: () => pinned.togglePin(trip.id),
          onOpenDetail: () {
            Navigator.of(context).pushNamed('/trip-detail', arguments: trip.id);
          },
          onAcceptTrip: showAcceptButton ? () => _onAcceptTrip(trip.id) : null,
          onRejectTrip: showAcceptButton ? () => _onRejectTrip(trip.id) : null,
          onStartTrip: _canStartTripFromCard(trip) ? () => _onStartTrip(trip.id) : null,
          driverTrackingStatus:
              context.watch<TripProvider>().driverTrackingStatusFor(trip.id),
        );
      },
    );
  }

  bool _canStartTripFromCard(TripModel trip) {
    return trip.status == AppConstants.tripStatusPlanned &&
        trip.canStartTrip &&
        !trip.isQueuedBlocked;
  }

  Future<void> _onStartTrip(String tripId) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    try {
      final success = await tripProvider.startTrip(tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Trip started' : (tripProvider.error ?? 'Failed to start trip')),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
        if (success) {
          Navigator.of(context).pushNamed('/trip-detail', arguments: tripId);
        }
      }
    } catch (e) {
      if (mounted) {
        showUserErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _onAcceptTrip(String tripId) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    try {
      final success = await tripProvider.acceptTrip(tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Trip accepted' : 'Failed to accept trip'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
        if (success) {
          Navigator.of(context).pushNamed('/trip-detail', arguments: tripId);
        }
      }
    } catch (e) {
      if (mounted) {
        showUserErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _onRejectTrip(String tripId) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    try {
      final success = await tripProvider.rejectTrip(tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Trip rejected' : 'Failed to reject trip'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showUserErrorSnackBar(context, e);
      }
    }
  }

}

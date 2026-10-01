import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_copy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/helpers.dart';
import '../../data/models/trip_group.dart';
import '../../data/models/trip_model.dart';
import '../../core/utils/user_feedback.dart';
import '../../providers/trip_provider.dart';
import '../../providers/pinned_trips_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/navigation_state_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/open_app_drawer_button.dart';
import '../../widgets/transporter_home_app_bar_title.dart';
import '../../widgets/trip_expansion_card.dart';
import '../../core/utils/create_trip_navigation.dart';
import '../../services/permission_service.dart';
import '../kyc/kyc_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _currentBannerIndex = 0;
  bool _localKycCompleted = false;
  bool _kycBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    // Load trips, wallet, and notifications when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        final walletProvider = Provider.of<WalletProvider>(context, listen: false);
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        final pinnedProvider = Provider.of<PinnedTripsProvider>(context, listen: false);
        final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
        final driverProvider = Provider.of<DriverProvider>(context, listen: false);
        await tripProvider.bootstrapTripsIfNeeded();
        await walletProvider.loadBalance();
        await notificationProvider.loadNotifications(refresh: true);
        await pinnedProvider.load();
        await pinnedProvider.reconcileWithTripProvider(tripProvider);
        await vehicleProvider.loadVehicles();
        await driverProvider.loadDrivers();
        if (!mounted) return;
        await Provider.of<AuthProvider>(context, listen: false).refreshProfile();
        _localKycCompleted = await isLocalKycCompleted();
        _kycBannerDismissed = await isKycBannerDismissed();
        if (mounted) setState(() {});
      } catch (e) {
        if (kDebugMode) {
          print('HomeTab: Error loading initial data: $e');
        }
      }
    });
  }

  Future<void> _onHomeRefresh() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final pinnedProvider = Provider.of<PinnedTripsProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    await tripProvider.bootstrapTripsIfNeeded();
    await walletProvider.loadBalance();
    await notificationProvider.loadNotifications(refresh: true);
    await pinnedProvider.reconcileWithTripProvider(tripProvider);
    await vehicleProvider.loadVehicles(refresh: true);
    await driverProvider.loadDrivers(refresh: true);
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
        showUserErrorSnackBar(context, e, fallback: 'Failed to accept trip');
      }
    }
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
        showUserErrorSnackBar(context, e, fallback: 'Failed to start trip');
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
        showUserErrorSnackBar(context, e, fallback: 'Failed to reject trip');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 64,
        leading: const OpenAppDrawerButton(),
        title: const TransporterHomeAppBarTitle(),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/notifications');
                    },
                  ),
                  if (notificationProvider.unreadCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          notificationProvider.unreadCount > 99
                              ? '99+'
                              : notificationProvider.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer2<TripProvider, PinnedTripsProvider>(
          builder: (context, tripProvider, pinnedProvider, child) {
            // Show loading state
            if (tripProvider.isLoading && tripProvider.trips.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Show error state
            if (tripProvider.error != null && tripProvider.trips.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
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
                        'Error loading data',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        tripProvider.error!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24.0),
                      ElevatedButton(
                        onPressed: () {
                          tripProvider.loadTrips(refresh: true);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Normal UI
            return RefreshIndicator(
              onRefresh: _onHomeRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildKycBanner(context, textTheme),
                    _buildNewTripCard(context, textTheme),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildOverviewCards(context, textTheme, tripProvider),
                    ),

                    const SizedBox(height: 24.0),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildFleetOverview(context, textTheme),
                    ),

                    const SizedBox(height: 24.0),

                    Builder(
                      builder: (context) {
                        final activeTrips = tripProvider.activeTrips;
                        if (activeTrips.isNotEmpty) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: _buildActiveTripCard(textTheme, activeTrips.first),
                              ),
                              const SizedBox(height: 24.0),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    _buildPinnedTripsSection(textTheme, tripProvider, pinnedProvider),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPinnedTripsSection(
    TextTheme textTheme,
    TripProvider tripProvider,
    PinnedTripsProvider pinnedProvider,
  ) {
    if (pinnedProvider.pinnedIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final byId = <String, TripModel>{};
    for (final t in tripProvider.trips) {
      byId[t.id] = t;
    }
    for (final t in tripProvider.availableTrips) {
      byId[t.id] = t;
    }

    final ordered = <TripModel>[];
    for (final id in pinnedProvider.pinnedIds) {
      final t = byId[id];
      if (t != null) ordered.add(t);
    }
    if (ordered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Pinned trips',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: ordered.map((trip) {
              final showAccept =
                  trip.status.toUpperCase() == AppConstants.tripStatusBooked;
              final canStart = trip.status == AppConstants.tripStatusPlanned &&
                  trip.canStartTrip &&
                  !trip.isQueuedBlocked;
              return TripExpansionCard(
                trip: trip,
                textTheme: textTheme,
                showAcceptButton: showAccept,
                isPinned: pinnedProvider.isPinned(trip.id),
                onPinTap: () => pinnedProvider.togglePin(trip.id),
                onOpenDetail: () {
                  Navigator.of(context).pushNamed('/trip-detail', arguments: trip.id);
                },
                onAcceptTrip: showAccept ? () => _onAcceptTrip(trip.id) : null,
                onRejectTrip: showAccept ? () => _onRejectTrip(trip.id) : null,
                onStartTrip: canStart ? () => _onStartTrip(trip.id) : null,
                driverTrackingStatus:
                    tripProvider.driverTrackingStatusFor(trip.id),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildBannerCarousel(TextTheme textTheme) {
    final banners = [
      _buildBannerPlaceholder(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        title: 'Welcome to Prottivo',
        subtitle: 'Efficient Logistics Management',
        textTheme: textTheme,
      ),
      _buildBannerPlaceholder(
        gradient: LinearGradient(
          colors: [
            AppColors.textPrimary,
            AppColors.textPrimary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        title: 'Track Your Trips',
        subtitle: 'Real-time Updates & Monitoring',
        textTheme: textTheme,
      ),
      _buildBannerPlaceholder(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.8), AppColors.textPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        title: 'Manage Operations',
        subtitle: 'Streamlined Workflow',
        textTheme: textTheme,
      ),
    ];

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 200.0,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
          ),
          items: banners.map((banner) => banner).toList(),
        ),
        const SizedBox(height: 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _currentBannerIndex == index
                        ? AppColors.primary
                        : AppColors.dividerGrey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerPlaceholder({
    required Gradient gradient,
    required String title,
    required String subtitle,
    required TextTheme textTheme,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.background,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.background.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(
    BuildContext context,
    TextTheme textTheme,
    TripProvider tripProvider,
  ) {
    void openTrips(int subTabIndex) {
      context.read<NavigationStateProvider>().requestOpenTripsSubTab(subTabIndex);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Summary',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16.0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.inventory_2,
                value: tripProvider.activeTrips.length.toString(),
                label: 'Active',
                textTheme: textTheme,
                onTap: () => openTrips(0),
                tooltip: 'Open Active trips',
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.schedule,
                value: tripProvider.plannedTrips.length.toString(),
                label: 'Planned',
                textTheme: textTheme,
                onTap: () => openTrips(0),
                tooltip: 'Open Active trips (includes planned)',
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.check_circle_outline,
                value: tripProvider.completedTrips.length.toString(),
                label: 'Completed',
                textTheme: textTheme,
                onTap: () => openTrips(2),
                tooltip: 'Open Completed trips',
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.pending_actions,
                value: tripProvider.podPendingTrips.length.toString(),
                label: AppCopy.awaitingPod,
                textTheme: textTheme,
                onTap: () => openTrips(1),
                tooltip: 'Open ${AppCopy.awaitingPod} trips',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
    required TextTheme textTheme,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20.0, color: AppColors.primary),
          const SizedBox(height: 8.0),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11.0,
              height: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: tooltip ?? label,
      child: Tooltip(
        message: tooltip ?? 'Open $label in Trips',
        child: Material(
          color: AppColors.offWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
            side: const BorderSide(color: AppColors.dividerGrey, width: 1.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14.0),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTripCard(TextTheme textTheme, TripModel trip) {
    final title = _activeTripTitle(trip);
    final isMarketplace =
        trip.isMarketplaceBookingTrip || trip.isMarketplaceInquiryTrip;
    final origin = trip.pickupLocation?.address?.trim() ?? '';
    final destination = trip.dropLocation?.address?.trim() ?? '';
    final vehicle = _firstNonEmpty([
      trip.vehicleNumber,
      ...?trip.assignments?.map((a) => a.vehicleNumber),
    ]);
    final driver = _firstNonEmpty([
      trip.driverName,
      ...?trip.assignments?.map((a) => a.driverName),
    ]);
    final movement = movementCategoryForTrip(trip);
    final statusColor = switch (movement) {
      VehicleMovementCategory.inTransit => AppColors.success,
      VehicleMovementCategory.loading => AppColors.warning,
      VehicleMovementCategory.delivered => AppColors.textSecondary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Active Trip',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context
                  .read<NavigationStateProvider>()
                  .requestOpenTripsSubTab(0),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2.0),
                  const Icon(Icons.arrow_forward, size: 16.0),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Material(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(color: AppColors.dividerGrey, width: 1.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).pushNamed(
              '/trip-detail',
              arguments: trip.id,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 14.0, 12.0, 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                softWrap: true,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (isMarketplace) ...[
                              const SizedBox(width: 8.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.offWhite,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  'Marketplace',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 10.0,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 5.0,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          movement.label,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 10.0,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1.0),
                        child: Icon(
                          Icons.location_on,
                          size: 14.0,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          origin.isEmpty ? 'Pickup' : origin,
                          softWrap: true,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11.0,
                            height: 1.25,
                            color: origin.isEmpty
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 12.0,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 1.0),
                        child: Icon(
                          Icons.location_on,
                          size: 14.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          destination.isEmpty ? 'Drop' : destination,
                          softWrap: true,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11.0,
                            height: 1.25,
                            color: destination.isEmpty
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18.0,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(height: 1.0, color: AppColors.dividerGrey),
                  ),
                  Row(
                    children: [
                      _activeTripMeta(
                        textTheme,
                        icon: Icons.local_shipping_outlined,
                        value: vehicle ?? '—',
                      ),
                      _activeTripDivider(),
                      _activeTripMeta(
                        textTheme,
                        icon: Icons.person_outline,
                        value: driver ?? '—',
                      ),
                      _activeTripDivider(),
                      _activeTripMeta(
                        textTheme,
                        icon: Icons.schedule_outlined,
                        value: _activeTripEta(trip),
                        caption: 'ETA',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _activeTripMeta(
    TextTheme textTheme, {
    required IconData icon,
    required String value,
    String? caption,
  }) {
    final valueStyle = textTheme.bodySmall?.copyWith(
      fontSize: 10.5,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Icon(icon, size: 14.0, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: caption == null
                ? Text(value, softWrap: true, style: valueStyle)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        caption,
                        softWrap: true,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 9.0,
                          height: 1.1,
                        ),
                      ),
                      Text(value, softWrap: true, style: valueStyle),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _activeTripDivider() {
    return Container(
      width: 1.0,
      height: 28.0,
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      color: AppColors.dividerGrey,
    );
  }

  String _activeTripTitle(TripModel trip) {
    final customer = trip.customerName?.trim() ?? '';
    if (customer.isNotEmpty) return customer;
    final container = trip.containerNumber?.trim() ?? '';
    if (container.isNotEmpty) return container;
    if (trip.tripId.isNotEmpty) return trip.tripId;
    return 'Trip';
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  String _activeTripEta(TripModel trip) {
    final seconds = trip.tracking?.etaSeconds;
    if (seconds == null || seconds <= 0) return '—';
    final arrival = DateTime.now().add(Duration(seconds: seconds));
    return Helpers.formatDate(arrival);
  }

  Future<void> _startCreateTripFlow(BuildContext context) async {
    await openCreateTripFlow(context);
    if (!context.mounted) return;
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final pinnedProvider =
        Provider.of<PinnedTripsProvider>(context, listen: false);
    await tripProvider.loadTrips(refresh: true);
    await tripProvider.loadAvailableTrips(refresh: true);
    await pinnedProvider.reconcileWithTripProvider(tripProvider);
  }

  Widget _buildKycBanner(BuildContext context, TextTheme textTheme) {
    final user = context.watch<AuthProvider>().user;
    final apiVerified = user?.isKycVerified == true;
    if (apiVerified || _localKycCompleted || _kycBannerDismissed) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InkWell(
              onTap: () async {
                final done = await Navigator.of(context).pushNamed('/kyc');
                if (!mounted || done != true) return;
                await context.read<AuthProvider>().refreshProfile();
                _localKycCompleted = await isLocalKycCompleted();
                if (mounted) setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 40, 14),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Complete KYC to keep your transporter account verified.',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () async {
                  await dismissKycBanner();
                  if (!mounted) return;
                  setState(() => _kycBannerDismissed = true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTripCard(BuildContext context, TextTheme textTheme) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final permissionService = PermissionService(authProvider);
        final canCreateTrip = permissionService.hasPermission('createTrips') ||
            permissionService.isTransporter;

        if (!canCreateTrip) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
          child: Material(
            color: AppColors.offWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: const BorderSide(color: AppColors.dividerGrey, width: 1.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _startCreateTripFlow(context),
              borderRadius: BorderRadius.circular(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 48.0,
                      height: 48.0,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.background,
                        size: 26.0,
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppCopy.newTrip,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            'Create a new trip in few steps',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    const Icon(
                      Icons.arrow_forward,
                      color: AppColors.primary,
                      size: 22.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFleetOverview(BuildContext context, TextTheme textTheme) {
    void openFleet() => Navigator.of(context).pushNamed('/vehicles');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Fleet',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: openFleet,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2.0),
                  const Icon(Icons.arrow_forward, size: 16.0),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Consumer2<VehicleProvider, DriverProvider>(
          builder: (context, vehicleProvider, driverProvider, _) {
            return Material(
              color: AppColors.offWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
                side: const BorderSide(color: AppColors.dividerGrey, width: 1.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: openFleet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _fleetStat(
                          textTheme,
                          icon: Icons.local_shipping_outlined,
                          value: vehicleProvider.vehicles.length.toString(),
                          label: 'Vehicles',
                        ),
                      ),
                      Container(
                        width: 1.0,
                        height: 28.0,
                        color: AppColors.dividerGrey,
                      ),
                      Expanded(
                        child: _fleetStat(
                          textTheme,
                          icon: Icons.people_outline,
                          value: driverProvider.drivers.length.toString(),
                          label: 'Drivers',
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20.0,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _fleetStat(
    TextTheme textTheme, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 22.0, color: AppColors.primary),
          const SizedBox(width: 16.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 11.0,
                  color: AppColors.textSecondary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/models/trip_model.dart';
import '../../providers/trip_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load trips and wallet when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final tripProvider = Provider.of<TripProvider>(context, listen: false);
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          tripProvider.loadTrips(refresh: true).catchError((e) {
            if (kDebugMode) {
              print('HomeTab: Error loading trips: $e');
            }
          });
          walletProvider.loadBalance().catchError((e) {
            if (kDebugMode) {
              print('HomeTab: Error loading wallet: $e');
            }
          });
        } catch (e) {
          if (kDebugMode) {
            print('HomeTab: Error accessing providers: $e');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Prottivo Transporter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/notifications');
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
        child: Consumer<TripProvider>(
          builder: (context, tripProvider, child) {
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
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Carousel Section
                  // _buildBannerCarousel(textTheme),

                  // const SizedBox(height: 24.0),

                  // Overview Cards Section (2x2 Grid)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildOverviewCards(textTheme, tripProvider),
                  ),

              const SizedBox(height: 24.0),

                  // Active Trip Card Section
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

                  // Action Buttons Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildActionButtons(context, textTheme),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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

  Widget _buildOverviewCards(TextTheme textTheme, TripProvider tripProvider) {
    final activeTripsCount = tripProvider.activeTrips.length;
    final completedTripsCount = tripProvider.completedTrips.length;
    final plannedTripsCount = tripProvider.plannedTrips.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16.0),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.local_shipping,
                value: activeTripsCount.toString(),
                label: 'Active Trips',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.schedule,
                value: plannedTripsCount.toString(),
                label: 'Planned Trips',
                textTheme: textTheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.check_circle_outline,
                value: completedTripsCount.toString(),
                label: 'Completed Trips',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.pending_actions,
                value: tripProvider.podPendingTrips.length.toString(),
                label: 'POD Pending',
                textTheme: textTheme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String value,
    required String label,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.dividerGrey, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32.0, color: AppColors.primary),
          const SizedBox(height: 12.0),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripCard(TextTheme textTheme, TripModel trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Trip',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16.0),
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: AppColors.primary, width: 2.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            style: textTheme.titleMedium?.copyWith(
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      Helpers.getStatusLabel(trip.status),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
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
      ],
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

  Widget _buildActionButtons(BuildContext context, TextTheme textTheme) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final permissionService = PermissionService(authProvider);
        // Only show "Create Trip" button if user has createTrips permission or is transporter
        // Note: hasPermission already returns true for transporters, so the OR is redundant but safe
        final canCreateTrip = permissionService.hasPermission('createTrips') || permissionService.isTransporter;
        
        if (kDebugMode) {
          print('HomeTab: canCreateTrip check - result: $canCreateTrip');
          print('HomeTab: User: ${authProvider.user?.id}, userType: ${authProvider.user?.userType}');
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canCreateTrip)
              SizedBox(
                height: 52.0,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/create-trip');
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, size: 20.0),
                const SizedBox(width: 8.0),
                Text(
                  'Create Trip',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
                ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
              child: SizedBox(
                height: 52.0,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/add-driver');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_add_outlined, size: 20.0),
                      const SizedBox(width: 8.0),
                      Text(
                        'Add Driver',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: SizedBox(
                height: 52.0,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/add-vehicle');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 20.0),
                      const SizedBox(width: 8.0),
                      Text(
                        'Add Vehicle',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              ],
            ),
          ],
        );
      },
    );
  }
}

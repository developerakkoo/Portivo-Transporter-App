import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../core/theme/app_colors.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _currentBannerIndex = 0;

  // Placeholder data - replace with real data later
  final int runningTrips = 5;
  final int activeTrips = 3;
  final int completedTrips = 12;
  final double walletBalance = 12500.00;

  // Placeholder active trip data
  final Map<String, dynamic>? activeTrip = {
    'id': 'TRP-2024-001',
    'driverName': 'John Doe',
    'vehicleInfo': 'ABC-1234 (Truck)',
    'origin': 'Warehouse A',
    'destination': 'Distribution Center B',
    'status': 'In Transit',
    'eta': '2h 30m',
  };

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
              // TODO: Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              // TODO: Navigate to profile
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner Carousel Section
              _buildBannerCarousel(textTheme),

              const SizedBox(height: 24.0),

              // Overview Cards Section (2x2 Grid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildOverviewCards(textTheme),
              ),

              const SizedBox(height: 24.0),

              // Active Trip Card Section
              if (activeTrip != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildActiveTripCard(textTheme),
                ),
                const SizedBox(height: 24.0),
              ],

              // Action Buttons Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildActionButtons(context, textTheme),
              ),
            ],
          ),
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
      ),
      _buildBannerPlaceholder(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.8), AppColors.textPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        title: 'Manage Operations',
        subtitle: 'Streamlined Workflow',
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.background,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.background.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(TextTheme textTheme) {
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
                icon: Icons.directions_run,
                value: runningTrips.toString(),
                label: 'Running Trips',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.local_shipping,
                value: activeTrips.toString(),
                label: 'Active Trips',
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
                value: completedTrips.toString(),
                label: 'Completed Trips',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.account_balance_wallet,
                value: '\$${walletBalance.toStringAsFixed(0)}',
                label: 'Wallet Balance',
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

  Widget _buildActiveTripCard(TextTheme textTheme) {
    if (activeTrip == null) return const SizedBox.shrink();

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
                  Text(
                    activeTrip!['id'] as String,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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
                      activeTrip!['status'] as String,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              _buildTripInfoRow(
                icon: Icons.person_outline,
                label: 'Driver',
                value: activeTrip!['driverName'] as String,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12.0),
              _buildTripInfoRow(
                icon: Icons.local_shipping_outlined,
                label: 'Vehicle',
                value: activeTrip!['vehicleInfo'] as String,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _buildTripInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Origin',
                      value: activeTrip!['origin'] as String,
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
                      value: activeTrip!['destination'] as String,
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
                      Icons.access_time,
                      color: AppColors.primary,
                      size: 20.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'ETA: ${activeTrip!['eta'] as String}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    // TODO: Navigate to add driver
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
                    // TODO: Navigate to add vehicle
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
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/route_colors.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/tracking_format.dart';
import '../data/models/trip_group.dart';
import '../data/models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../services/fleet_tracking_controller.dart';
import '../services/socket_service.dart';
import '../widgets/fleet_tracking_map.dart';

/// Trip Group detail: header, stats row, and two tabs — a realtime Fleet map
/// (all vehicles colored by route) and a per-vehicle list that opens each
/// vehicle's existing live tracking. Filter chips drive both views.
class TripGroupDetailScreen extends StatefulWidget {
  const TripGroupDetailScreen({super.key});

  @override
  State<TripGroupDetailScreen> createState() => _TripGroupDetailScreenState();
}

class _TripGroupDetailScreenState extends State<TripGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  TripProvider? _provider;
  FleetTrackingController? _fleet;
  VehicleMovementCategory? _filter;
  String? _groupId;
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    _groupId = args is String ? args : null;
    if (_groupId == null) return;

    // Ensure realtime is live for this screen even on cold entry / reconnect:
    // driver:location:updated is broadcast to the transporter room, which is the
    // fleet map's source of every vehicle's GPS fix (mirrors trip_detail).
    final socket = SocketService();
    socket.connect();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      socket.joinTransporterRoom(user.transporterId ?? user.id);
    }

    _provider = context.read<TripProvider>();
    _provider!.addListener(_onProviderChanged);
    await _provider!.loadTripGroup(_groupId!);
    if (!mounted) return;
    _syncController();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _syncController();
  }

  void _syncController() {
    final group = _provider?.selectedGroup;
    if (group == null) return;
    final signature =
        group.trips.map((t) => '${t.id}:${t.routeIndex}').join(',');

    if (_fleet == null) {
      _fleet = FleetTrackingController(trips: group.trips)..setFilter(_filter);
      _lastSignature = signature;
      setState(() {});
    } else if (signature != _lastSignature) {
      _fleet!.updateTrips(group.trips);
      _lastSignature = signature;
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _fleet?.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterSelected(VehicleMovementCategory? category) {
    setState(() => _filter = category);
    _fleet?.setFilter(category);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trip')),
      body: Consumer<TripProvider>(
        builder: (context, provider, _) {
          final group = provider.selectedGroup;

          if (group == null) {
            if (provider.isLoadingGroup) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.groupError != null) {
              return _errorState(provider.groupError!, textTheme);
            }
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _header(group, textTheme),
              _statsRow(group, textTheme),
              _filterChips(group, textTheme),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: 'Fleet View'),
                  Tab(text: 'Vehicle View'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _fleetView(),
                    _vehicleView(group, textTheme),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _errorState(String message, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_groupId != null) {
                  context.read<TripProvider>().loadTripGroup(_groupId!);
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(TripGroup group, TextTheme textTheme) {
    final customer = (group.customerName ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer.isNotEmpty ? customer : group.displayTripId,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            group.reference?.isNotEmpty == true
                ? '${group.displayTripId} · ${group.reference}'
                : group.displayTripId,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(TripGroup group, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _stat('${group.vehicleCount}', 'Vehicles', textTheme),
          _stat('${group.containerCount}', 'Containers', textTheme),
          _stat('${group.inTransitCount}', 'In Transit', textTheme,
              color: AppColors.info),
          _stat('${group.loadingCount}', 'Loading', textTheme,
              color: AppColors.warning),
          _stat('${group.deliveredCount}', 'Delivered', textTheme,
              color: AppColors.success),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, TextTheme textTheme,
      {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(TripGroup group, TextTheme textTheme) {
    Widget chip(String label, VehicleMovementCategory? category) {
      final selected = _filter == category;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => _onFilterSelected(category),
          showCheckmark: false,
          selectedColor: AppColors.primary,
          labelStyle: textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.background : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.offWhite,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.dividerGrey,
          ),
        ),
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('All', null),
          chip('In Transit', VehicleMovementCategory.inTransit),
          chip('Loading', VehicleMovementCategory.loading),
          chip('Delivered', VehicleMovementCategory.delivered),
        ],
      ),
    );
  }

  Widget _fleetView() {
    final fleet = _fleet;
    if (fleet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FleetTrackingMap(controller: fleet);
  }

  Widget _vehicleView(TripGroup group, TextTheme textTheme) {
    final query = _searchController.text.toLowerCase();
    var trips = group.trips.where((t) {
      if (_filter != null && movementCategoryForTrip(t) != _filter) {
        return false;
      }
      if (query.isEmpty) return true;
      final vehicle = (t.vehicleNumber ?? '').toLowerCase();
      final container = (t.containerNumber ?? '').toLowerCase();
      return vehicle.contains(query) || container.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search vehicle / container',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: trips.isEmpty
              ? Center(
                  child: Text(
                    'No vehicles',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _vehicleRow(trips[index], textTheme),
                ),
        ),
      ],
    );
  }

  Widget _vehicleRow(TripModel trip, TextTheme textTheme) {
    final category = movementCategoryForTrip(trip);
    final color = RouteColors.forIndex(trip.routeIndex);
    final eta = TrackingFormat.eta(trip.tracking?.etaSeconds);
    final distance =
        TrackingFormat.distance(trip.tracking?.distanceRemainingMeters);
    final metrics = <String>[
      if (distance != null) distance,
      if (eta != null) eta,
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () =>
          Navigator.of(context).pushNamed('/trip-detail', arguments: trip.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.dividerGrey),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.vehicleNumber?.isNotEmpty == true
                        ? trip.vehicleNumber!
                        : trip.tripId,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trip.containerNumber?.isNotEmpty == true
                        ? trip.containerNumber!
                        : 'No container',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (metrics.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metrics,
                      style: textTheme.labelSmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _categoryChip(category, textTheme),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(VehicleMovementCategory category, TextTheme textTheme) {
    Color color;
    switch (category) {
      case VehicleMovementCategory.inTransit:
        color = AppColors.info;
        break;
      case VehicleMovementCategory.loading:
        color = AppColors.warning;
        break;
      case VehicleMovementCategory.delivered:
        color = AppColors.success;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

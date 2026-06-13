import 'package:flutter/material.dart';
import '../models/trip_map_live_data.dart';
import '../widgets/trip_tracking_map.dart';

/// Full-screen live tracking with [Hero] (tag must match trip detail).
class TripTrackingFullscreenPage extends StatelessWidget {
  const TripTrackingFullscreenPage({
    super.key,
    required this.tripId,
    required this.live,
  });

  final String tripId;
  final ValueNotifier<TripMapLiveData> live;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Live tracking'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Hero(
          tag: 'trip_live_map_$tripId',
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: ValueListenableBuilder<TripMapLiveData>(
                valueListenable: live,
                builder: (context, data, _) {
                  return TripTrackingMap(
                    fullScreen: true,
                    pickupLocation: data.pickup,
                    dropLocation: data.drop,
                    driverLocation: data.driverTarget,
                    driverHeading: data.driverHeading,
                    driverTrailPoints: data.trail,
                    routePolylinePoints: data.routePolyline,
                    trailLoaded: data.trailLoaded,
                    showDriverMarker: true,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

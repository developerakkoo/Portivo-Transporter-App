import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_colors.dart';
import '../data/models/trip_model.dart';
import '../services/location_service.dart';

const LatLng _defaultPosition = LatLng(19.0760, 72.8777);
const double _defaultZoom = 14.0;

class LocationPickerScreen extends StatefulWidget {
  final bool isPickup;
  final String? initialQuery;

  /// When true (default), Places search is not biased to GPS or a fallback city—suited to
  /// port-to-port logistics across India. When false, ranking favors the device location and Mumbai fallback.
  final bool nationalSearch;

  const LocationPickerScreen({
    super.key,
    required this.isPickup,
    this.initialQuery,
    this.nationalSearch = true,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  final _locationService = LocationService();
  StreamSubscription<List<Prediction>>? _predictionsSubscription;
  StreamSubscription<bool>? _loadingSubscription;
  StreamSubscription<String?>? _searchErrorSubscription;
  Timer? _reverseGeocodeDebounce;

  GoogleMapController? _mapController;
  List<Prediction> _predictions = [];
  TripLocation? _selectedLocation;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isFetchingDetails = false;
  String? _errorMessage;
  String? _placesSearchError;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }
    _init();
  }

  Future<void> _init() async {
    try {
      _userPosition = await _getUserPosition();

      if (widget.nationalSearch) {
        await _locationService.initialize(
          biasSearchToOrigin: false,
        );
      } else {
        await _locationService.initialize(
          originLat: _userPosition?.latitude,
          originLng: _userPosition?.longitude,
          fallbackOriginLat: 19.076,
          fallbackOriginLng: 72.8777,
          biasSearchToOrigin: true,
        );
      }

      if (!mounted) return;

      if (!widget.nationalSearch) {
        _scheduleOriginRefresh();
      }

      _predictionsSubscription =
          _locationService.predictions.listen((predictions) {
        if (mounted) {
          setState(() => _predictions = predictions);
        }
      });

      _loadingSubscription = _locationService.loading.listen((isLoading) {
        if (mounted) {
          setState(() => _isSearching = isLoading);
        }
      });

      _searchErrorSubscription =
          _locationService.searchError.listen((message) {
        if (mounted) {
          setState(() => _placesSearchError = message);
        }
      });

      if (_searchController.text.isNotEmpty) {
        _locationService.searchPlaces(_searchController.text);
      }

      setState(() {
        _isInitialized = _locationService.isInitialized;
        _isLoading = false;
        if (!_isInitialized) {
          _errorMessage =
              'Location search is unavailable. Please check your API key configuration.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  /// Refresh origin after GPS may have become available (better ranking than fallback).
  void _scheduleOriginRefresh() {
    Future<void>.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final pos = await _getUserPosition();
      if (pos != null && mounted) {
        _locationService.setOrigin(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      }
    });
  }

  Future<Position?> _getUserPosition() async {
    final status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      final requested = await Permission.locationWhenInUse.request();
      if (!requested.isGranted) return null;
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _reverseGeocodeDebounce?.cancel();
    _predictionsSubscription?.cancel();
    _loadingSubscription?.cancel();
    _searchErrorSubscription?.cancel();
    _locationService.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      _locationService.clearPredictions();
      if (mounted) setState(() => _placesSearchError = null);
    } else {
      if (mounted) {
        setState(() => _placesSearchError = null);
      }
      _locationService.searchPlaces(value);
    }
  }

  Future<void> _onPredictionTap(Prediction prediction) async {
    if (prediction.placeId == null) return;

    setState(() => _isFetchingDetails = true);

    final location = await _locationService.getPlaceDetails(prediction.placeId!);

    if (mounted && location != null) {
      setState(() {
        _selectedLocation = location;
        _predictions = [];
        _searchController.text = location.address ?? prediction.title ?? '';
        _isFetchingDetails = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            location.coordinates.latitude,
            location.coordinates.longitude,
          ),
        ),
      );
    } else if (mounted) {
      setState(() => _isFetchingDetails = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get place details'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _onMarkerDragEnd(LatLng position) {
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocodeAndUpdate(position.latitude, position.longitude);
    });
  }

  Future<void> _reverseGeocodeAndUpdate(double lat, double lng) async {
    final address = await _locationService.reverseGeocode(lat, lng);
    if (mounted && _selectedLocation != null) {
      setState(() {
        _selectedLocation = TripLocation(
          address: address ?? _selectedLocation!.address,
          coordinates: LocationCoordinates(latitude: lat, longitude: lng),
        );
      });
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop(_selectedLocation);
    }
  }

  LatLng get _mapCenter {
    if (_selectedLocation != null) {
      return LatLng(
        _selectedLocation!.coordinates.latitude,
        _selectedLocation!.coordinates.longitude,
      );
    }
    if (_userPosition != null) {
      return LatLng(_userPosition!.latitude, _userPosition!.longitude);
    }
    return _defaultPosition;
  }

  Set<Marker> get _markers {
    if (_selectedLocation == null) return {};
    return {
      Marker(
        markerId: const MarkerId('selected'),
        position: LatLng(
          _selectedLocation!.coordinates.latitude,
          _selectedLocation!.coordinates.longitude,
        ),
        draggable: true,
        onDragEnd: _onMarkerDragEnd,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = widget.isPickup ? 'Pickup' : 'Drop';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Select $label Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(textTheme),
      bottomNavigationBar: _selectedLocation != null ? _buildConfirmBar() : null,
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(textTheme);
    }

    return Column(
      children: [
        _buildSearchBar(textTheme),
        Expanded(
          flex: _selectedLocation != null ? 2 : 1,
          child: _buildMap(),
        ),
        if (_selectedLocation == null)
          Expanded(
            flex: 1,
            child: _buildPredictionsList(textTheme),
          ),
      ],
    );
  }

  Widget _buildErrorState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16.0),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _init();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.nationalSearch
                ? 'Type to search, then choose a suggestion. Results are India-wide—try port name with city (e.g. JNPT Navi Mumbai).'
                : 'Type to search, then choose a suggestion. Results favor India and your area when location is on.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10.0),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for a location...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isFetchingDetails || _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          if (_placesSearchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _placesSearchError!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: _mapCenter,
        zoom: _defaultZoom,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      onTap: (_) {},
    );
  }

  Widget _buildPredictionsList(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: Text(
            'Search results',
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: _predictions.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Search for a location above'
                        : 'No results found',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _predictions.length,
                  itemBuilder: (context, index) {
                    final p = _predictions[index];
                    return _buildPredictionTile(p, textTheme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPredictionTile(Prediction prediction, TextTheme textTheme) {
    return InkWell(
      onTap: () => _onPredictionTap(prediction),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.dividerGrey),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.primary),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.title ?? '',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (prediction.description != null &&
                      prediction.description!.isNotEmpty) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      prediction.description!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedLocation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _selectedLocation!.address ?? 'Selected location',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(
              height: 52.0,
              child: ElevatedButton(
                onPressed: _confirmLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text('Confirm Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

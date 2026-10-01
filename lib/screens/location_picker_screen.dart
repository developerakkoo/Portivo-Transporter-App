import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/constants/operating_countries.dart';
import '../core/theme/app_colors.dart';
import '../data/models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../services/recent_location_search_service.dart';
import '../services/search_region_context.dart';
const double _defaultZoom = 14.0;
const Duration _gpsBootstrapTimeout = Duration(seconds: 8);

/// Hides POI labels/taps to avoid Places SDK activity conflicts on Android.
const String _poiHiddenMapStyle = '''
[
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';

class LocationPickerScreen extends StatefulWidget {
  final bool isPickup;
  final String? initialQuery;

  /// When true, never restrict suggestions to India (worldwide). Local GPS bias
  /// still applies when location permission is granted.
  final bool forceGlobalSearch;

  /// Previously: `true` meant worldwide without local bias. Prefer [forceGlobalSearch].
  @Deprecated('Use forceGlobalSearch')
  final bool? nationalSearch;

  /// When non-null, used as the AppBar title instead of "Select Pickup/Drop Location".
  final String? appBarTitle;

  /// When false, search Google Places and return a formatted location without
  /// opening the map (used for Create Trip Point A/B/C).
  final bool showMap;

  const LocationPickerScreen({
    super.key,
    required this.isPickup,
    this.initialQuery,
    this.forceGlobalSearch = false,
    this.nationalSearch,
    this.appBarTitle,
    this.showMap = true,
  });

  bool get _effectiveForceGlobal =>
      forceGlobalSearch || nationalSearch == true;

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
  bool _locationPermissionGranted = false;
  String _operatingCountryCode = OperatingCountries.defaultCode;
  List<TripLocation> _recentSearches = [];

  bool get _forceGlobal => widget._effectiveForceGlobal;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(_loadRecentSearches());
    unawaited(_bootstrap());
  }

  Future<void> _loadRecentSearches() async {
    final recents = await RecentLocationSearchService.load();
    if (!mounted) return;
    setState(() => _recentSearches = recents);
  }

  Future<void> _popLocation(TripLocation location) async {
    await RecentLocationSearchService.remember(location);
    if (!mounted) return;
    Navigator.of(context).pop(location);
  }

  /// GPS + region resolution, then a single Places configure before map render.
  Future<void> _bootstrap() async {
    try {
      final permissionGranted = await Permission.locationWhenInUse.isGranted;
      if (!mounted || _locationService.isDisposed) return;

      Position? pos;
      try {
        pos = await _getUserPositionIfGranted().timeout(_gpsBootstrapTimeout);
      } on TimeoutException {
        pos = null;
      }

      if (!mounted || _locationService.isDisposed) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _operatingCountryCode = authProvider.operatingCountry ??
          OperatingCountries.defaultCode;

      SearchRegionContext ctx;
      if (_forceGlobal) {
        ctx = SearchRegionContext(
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          confidence: pos != null
              ? SearchRegionConfidence.high
              : SearchRegionConfidence.none,
          countryCodes: null,
        );
      } else if (OperatingCountries.isSupported(_operatingCountryCode)) {
        ctx = SearchRegionContext.fromOperatingCountry(
          _operatingCountryCode,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
        );
      } else if (pos != null) {
        ctx = await SearchRegionContext.fromLatLng(pos.latitude, pos.longitude);
      } else {
        ctx = SearchRegionContext.fromOperatingCountry(
          OperatingCountries.defaultCode,
        );
      }

      await _locationService.configureForRegion(ctx);
      if (!mounted || _locationService.isDisposed) return;

      _attachStreamSubscriptions();

      if (_searchController.text.isNotEmpty) {
        _locationService.searchPlaces(_searchController.text);
      }

      setState(() {
        _isInitialized = _locationService.isInitialized;
        _isLoading = false;
        _locationPermissionGranted = permissionGranted;
        _userPosition = pos;
        if (!_isInitialized) {
          _errorMessage =
              'Location search is unavailable. Please check your API key configuration.';
        }
      });
    } catch (e) {
      if (mounted && !_locationService.isDisposed) {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  void _attachStreamSubscriptions() {
    _predictionsSubscription ??=
        _locationService.predictions.listen((predictions) {
      if (mounted) {
        setState(() => _predictions = predictions);
      }
    });

    _loadingSubscription ??= _locationService.loading.listen((isLoading) {
      if (mounted) {
        setState(() => _isSearching = isLoading);
      }
    });

    _searchErrorSubscription ??=
        _locationService.searchError.listen((message) {
      if (mounted) {
        setState(() => _placesSearchError = message);
      }
    });
  }

  Future<Position?> _getUserPositionIfGranted() async {
    if (!await Permission.locationWhenInUse.isGranted) return null;

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
    _mapController = null;
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (!_isInitialized) return;
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
    if (prediction.placeId == null || !_isInitialized) return;

    setState(() => _isFetchingDetails = true);

    final location = await _locationService.getPlaceDetails(prediction.placeId!);

    if (mounted && location != null) {
      if (!widget.showMap) {
        final formatted = location.countryCode == null
            ? TripLocation(
                address: location.address,
                coordinates: location.coordinates,
                countryCode: _forceGlobal ? null : _operatingCountryCode,
              )
            : location;
        Navigator.of(context).pop(formatted);
        unawaited(RecentLocationSearchService.remember(formatted));
        return;
      }
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
      final location = _selectedLocation!.countryCode == null
          ? TripLocation(
              address: _selectedLocation!.address,
              coordinates: _selectedLocation!.coordinates,
              countryCode: _forceGlobal ? null : _operatingCountryCode,
            )
          : _selectedLocation;
      unawaited(_popLocation(location!));
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
    return OperatingCountries.defaultCenterFor(_operatingCountryCode);
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
        title: Text(widget.appBarTitle ?? 'Select $label Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(textTheme),
      bottomNavigationBar:
          widget.showMap && _selectedLocation != null ? _buildConfirmBar() : null,
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
        if (!widget.showMap) ...[
          if (_isFetchingDetails) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildPredictionsList(textTheme)),
        ] else ...[
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
                unawaited(_bootstrap());
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
    final hint = _forceGlobal
        ? 'Worldwide search. Allow location for results ranked near you.'
        : 'Search places near you. In India, results favor precise local matches when location is on.';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hint,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10.0),
          TextField(
            controller: _searchController,
            enabled: _isInitialized,
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
        if (_userPosition != null) {
          unawaited(
            controller.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(
                  _userPosition!.latitude,
                  _userPosition!.longitude,
                ),
                _defaultZoom,
              ),
            ),
          );
        }
      },
      initialCameraPosition: CameraPosition(
        target: _mapCenter,
        zoom: _defaultZoom,
      ),
      markers: _markers,
      style: _poiHiddenMapStyle,
      myLocationEnabled: _locationPermissionGranted,
      myLocationButtonEnabled: _locationPermissionGranted,
      zoomControlsEnabled: false,
      onTap: (_) {},
    );
  }

  Widget _buildRecentSearches(TextTheme textTheme) {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._recentSearches.map(
          (loc) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: _isFetchingDetails
                  ? null
                  : () => unawaited(_popLocation(loc)),
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: AppColors.dividerGrey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: AppColors.textSecondary),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        loc.address ?? 'Location',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsList(TextTheme textTheme) {
    final showEmptySearch = _selectedLocation == null &&
        _searchController.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: Text(
            showEmptySearch && _predictions.isEmpty
                ? (_recentSearches.isEmpty ? 'Search results' : 'Recent')
                : 'Search results',
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              if (showEmptySearch && _predictions.isEmpty)
                _buildRecentSearches(textTheme),
              if (_predictions.isEmpty &&
                  !(showEmptySearch && _recentSearches.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Type an address or place name above'
                          : 'No results found',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (_predictions.isNotEmpty)
                ..._predictions.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildPredictionTile(p, textTheme),
                  ),
                ),
            ],
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

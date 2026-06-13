import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';

import '../core/config/maps_config.dart';
import '../data/models/trip_model.dart';
import 'search_region_context.dart';

/// Service for location search (Places Autocomplete) and reverse geocoding.
///
/// Uses [google_places_autocomplete] (native Places SDK). Session tokens are
/// handled by the package. Call [configureForRegion] once before showing the map.
class LocationService {
  GooglePlacesAutocomplete? _places;
  final _predictionsController = StreamController<List<Prediction>>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _searchErrorController = StreamController<String?>.broadcast();
  bool _isInitialized = false;
  bool _isDisposed = false;
  List<String>? _lastCountryCodes;
  Future<void>? _pendingConfigure;

  /// Stream of place predictions from search results.
  Stream<List<Prediction>> get predictions => _predictionsController.stream;

  /// Stream of loading state for search.
  Stream<bool> get loading => _loadingController.stream;

  /// User-visible search / Places errors (null to clear).
  Stream<String?> get searchError => _searchErrorController.stream;

  /// Whether the Places client has been successfully configured.
  bool get isInitialized => _isInitialized && !_isDisposed;

  bool get isDisposed => _isDisposed;

  void _emitPredictions(List<Prediction> predictions) {
    if (_isDisposed || _predictionsController.isClosed) return;
    _predictionsController.add(predictions);
  }

  void _emitLoading(bool isLoading) {
    if (_isDisposed || _loadingController.isClosed) return;
    _loadingController.add(isLoading);
  }

  void _emitSearchError(String? message) {
    if (_isDisposed || _searchErrorController.isClosed) return;
    _searchErrorController.add(message);
  }

  void _clearSearchError() {
    _emitSearchError(null);
  }

  void _handlePlacesError(PlacesException error) {
    if (_isDisposed) return;
    if (kDebugMode) {
      print('LocationService Places error: ${error.code} - ${error.message}');
    }
    _emitSearchError(_mapPlacesExceptionToMessage(error));
  }

  String _mapPlacesExceptionToMessage(PlacesException error) {
    final code = (error.code ?? '').toLowerCase();
    final msg = (error.message).toLowerCase();

    if (code.contains('over_query') ||
        msg.contains('over_query') ||
        msg.contains('quota')) {
      return 'Search is temporarily unavailable. Try again later.';
    }
    if (code.contains('invalid') ||
        msg.contains('invalid_request') ||
        msg.contains('invalid request')) {
      return 'Invalid search. Check the address and try again.';
    }
    if (code.contains('denied') ||
        msg.contains('request_denied') ||
        msg.contains('api key')) {
      return 'Search could not be completed. Check your connection and try again.';
    }
    if (code.contains('zero') || msg.contains('zero_results')) {
      return 'No matching places. Try a different search.';
    }
    return error.message.isNotEmpty
        ? error.message
        : 'Could not complete search. Try again.';
  }

  void _attachPredictionsClient(SearchRegionContext ctx) {
    if (_isDisposed) return;
    _places?.dispose();
    _places = GooglePlacesAutocomplete(
      debounceTime: 300,
      countries: ctx.countryCodes,
      originLat: ctx.latitude,
      originLng: ctx.longitude,
      predictionsListener: (predictions) {
        if (_isDisposed) return;
        if (predictions.isNotEmpty) {
          _clearSearchError();
        }
        _emitPredictions(predictions);
      },
      loadingListener: (isLoading) {
        if (_isDisposed) return;
        _emitLoading(isLoading);
      },
      onError: _handlePlacesError,
    );
  }

  /// Configure Places for [ctx]. Recreates the native client only when the
  /// country filter changes. Call once before rendering GoogleMap.
  Future<void> configureForRegion(SearchRegionContext ctx) async {
    if (_isDisposed) return;

    final configure = _configureForRegionImpl(ctx);
    _pendingConfigure = configure;
    try {
      await configure;
    } finally {
      if (identical(_pendingConfigure, configure)) {
        _pendingConfigure = null;
      }
    }
  }

  Future<void> _configureForRegionImpl(SearchRegionContext ctx) async {
    if (_isDisposed) return;

    final needRecreate =
        !_isInitialized || !_sameCountryCodes(_lastCountryCodes, ctx.countryCodes);

    _lastCountryCodes = ctx.countryCodes == null
        ? null
        : List<String>.from(ctx.countryCodes!);

    if (needRecreate) {
      _attachPredictionsClient(ctx);
      if (_isDisposed || _places == null) return;
      try {
        await _places!.initialize(
          apiKey: mapsApiKey.isNotEmpty ? mapsApiKey : null,
        );
        if (_isDisposed) return;
        _isInitialized = _places?.isInitialized ?? false;
      } catch (e) {
        if (kDebugMode) {
          print('LocationService configure failed: $e');
        }
        _isInitialized = false;
        rethrow;
      }
    } else {
      if (_isDisposed) return;
      if (ctx.hasApproxLocation) {
        _places?.setOrigin(
          latitude: ctx.latitude!,
          longitude: ctx.longitude!,
        );
      } else {
        _places?.clearOrigin();
      }
    }
  }

  /// Search for places matching [query]. Results arrive via [predictions] stream.
  void searchPlaces(String query) {
    if (_isDisposed || !_isInitialized || query.trim().isEmpty) {
      _emitPredictions([]);
      return;
    }
    _places?.getPredictions(query.trim());
  }

  /// Clear any pending predictions and search errors.
  void clearPredictions() {
    if (_isDisposed) return;
    _emitPredictions([]);
    _clearSearchError();
    _places?.clearQueue();
  }

  /// Get place details by [placeId]. Returns TripLocation with address and coordinates.
  Future<TripLocation?> getPlaceDetails(String placeId) async {
    if (_isDisposed || !_isInitialized) return null;

    try {
      final details = await _places!.getPlaceDetails(placeId);
      if (_isDisposed) return null;
      if (details == null) {
        _emitSearchError('Could not load place details. Try another result.');
        return null;
      }

      final lat = details.location?.lat;
      final lng = details.location?.lng;
      if (lat == null || lng == null) {
        _emitSearchError(
          'Could not load coordinates for this place. Try another result.',
        );
        return null;
      }

      _clearSearchError();
      return TripLocation(
        address: details.formattedAddress ?? details.name,
        coordinates: LocationCoordinates(latitude: lat, longitude: lng),
      );
    } on PlacesException catch (e) {
      _handlePlacesError(e);
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('LocationService getPlaceDetails failed: $e');
      }
      if (!_isDisposed) {
        _emitSearchError('Could not load place details. Try again.');
      }
      return null;
    }
  }

  /// Reverse geocode coordinates to address. Returns formatted address or null.
  /// Does not require Places SDK initialization.
  Future<String?> reverseGeocode(double lat, double lng) async {
    if (_isDisposed) return null;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (_isDisposed || placemarks.isEmpty) return null;

      final p = placemarks.first;
      final parts = <String>[];
      if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
      if (p.subLocality != null && p.subLocality!.isNotEmpty) {
        parts.add(p.subLocality!);
      }
      if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
      if (p.administrativeArea != null &&
          p.administrativeArea!.isNotEmpty) {
        parts.add(p.administrativeArea!);
      }
      if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);

      return parts.isNotEmpty ? parts.join(', ') : null;
    } catch (e) {
      if (kDebugMode) {
        print('LocationService reverseGeocode failed: $e');
      }
      return null;
    }
  }

  /// Update user origin for distance / ranking (same restriction as last configure).
  void setOrigin({required double latitude, required double longitude}) {
    if (_isDisposed) return;
    _places?.setOrigin(latitude: latitude, longitude: longitude);
  }

  /// Dispose resources. Safe to call while [configureForRegion] is in flight.
  static bool _sameCountryCodes(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isInitialized = false;
    _lastCountryCodes = null;
    _places?.dispose();
    _places = null;
    if (!_predictionsController.isClosed) {
      _predictionsController.close();
    }
    if (!_loadingController.isClosed) {
      _loadingController.close();
    }
    if (!_searchErrorController.isClosed) {
      _searchErrorController.close();
    }
  }
}

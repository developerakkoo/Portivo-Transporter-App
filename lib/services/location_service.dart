import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';

import '../core/config/maps_config.dart';
import '../data/models/trip_model.dart';

/// Service for location search (Places Autocomplete) and reverse geocoding.
class LocationService {
  GooglePlacesAutocomplete? _places;
  final _predictionsController = StreamController<List<Prediction>>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _searchErrorController = StreamController<String?>.broadcast();
  bool _isInitialized = false;

  /// Stream of place predictions from search results.
  Stream<List<Prediction>> get predictions => _predictionsController.stream;

  /// Stream of loading state for search.
  Stream<bool> get loading => _loadingController.stream;

  /// User-visible search / Places errors (null to clear).
  Stream<String?> get searchError => _searchErrorController.stream;

  /// Whether the Places client has been initialized.
  bool get isInitialized => _isInitialized;

  static const List<String> _countriesIn = ['in'];

  /// Initialize the Places client. Call once before use.
  ///
  /// When [biasSearchToOrigin] is **false** (default, port-to-port / India-wide): no origin is
  /// passed and ranking is not biased to device or a fallback city.
  ///
  /// When **true** ("near me"): [originLat]/[originLng] and optional [fallbackOriginLat]/[fallbackOriginLng]
  /// bias ranking toward that region.
  Future<void> initialize({
    double? originLat,
    double? originLng,
    double? fallbackOriginLat,
    double? fallbackOriginLng,
    bool biasSearchToOrigin = false,
  }) async {
    if (_isInitialized) return;

    double? lat;
    double? lng;
    if (biasSearchToOrigin) {
      lat = originLat ?? fallbackOriginLat;
      lng = originLng ?? fallbackOriginLng;
    }

    _places = GooglePlacesAutocomplete(
      debounceTime: 300,
      countries: _countriesIn,
      originLat: lat,
      originLng: lng,
      predictionsListener: (predictions) {
        if (!_predictionsController.isClosed) {
          if (predictions.isNotEmpty) {
            _clearSearchError();
          }
          _predictionsController.add(predictions);
        }
      },
      loadingListener: (isLoading) {
        if (!_loadingController.isClosed) {
          _loadingController.add(isLoading);
        }
      },
      onError: _handlePlacesError,
    );

    try {
      await _places!.initialize(
        apiKey: mapsApiKey.isNotEmpty ? mapsApiKey : null,
      );
      if (!biasSearchToOrigin) {
        _places?.clearOrigin();
      }
      _isInitialized = _places?.isInitialized ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('LocationService init failed: $e');
      }
      rethrow;
    }
  }

  void _clearSearchError() {
    if (!_searchErrorController.isClosed) {
      _searchErrorController.add(null);
    }
  }

  void _handlePlacesError(PlacesException error) {
    if (kDebugMode) {
      print('LocationService Places error: ${error.code} - ${error.message}');
    }
    if (_searchErrorController.isClosed) return;
    _searchErrorController.add(_mapPlacesExceptionToMessage(error));
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

  /// Search for places matching [query]. Results arrive via [predictions] stream.
  void searchPlaces(String query) {
    if (!_isInitialized || query.trim().isEmpty) {
      _predictionsController.add([]);
      return;
    }
    _places?.getPredictions(query.trim());
  }

  /// Clear any pending predictions and search errors.
  void clearPredictions() {
    _predictionsController.add([]);
    _clearSearchError();
    _places?.clearQueue();
  }

  /// Get place details by [placeId]. Returns TripLocation with address and coordinates.
  Future<TripLocation?> getPlaceDetails(String placeId) async {
    if (!_isInitialized) return null;

    try {
      final details = await _places!.getPlaceDetails(placeId);
      if (details == null) {
        if (!_searchErrorController.isClosed) {
          _searchErrorController.add(
            'Could not load place details. Try another result.',
          );
        }
        return null;
      }

      final lat = details.location?.lat;
      final lng = details.location?.lng;
      if (lat == null || lng == null) {
        if (!_searchErrorController.isClosed) {
          _searchErrorController.add(
            'Could not load coordinates for this place. Try another result.',
          );
        }
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
      if (!_searchErrorController.isClosed) {
        _searchErrorController.add('Could not load place details. Try again.');
      }
      return null;
    }
  }

  /// Reverse geocode coordinates to address. Returns formatted address or null.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

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

  /// Update user origin for distance / ranking in predictions (approximates local bias).
  void setOrigin({required double latitude, required double longitude}) {
    _places?.setOrigin(latitude: latitude, longitude: longitude);
  }

  /// Dispose resources.
  void dispose() {
    _predictionsController.close();
    _loadingController.close();
    _searchErrorController.close();
    _places?.dispose();
    _places = null;
    _isInitialized = false;
  }
}

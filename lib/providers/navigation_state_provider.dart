import 'package:flutter/foundation.dart';

class NavigationStateProvider with ChangeNotifier {
  String? _pendingHighlightTripId;
  int? _pendingTripsSubTabIndex;

  String? get pendingHighlightTripId => _pendingHighlightTripId;
  int? get pendingTripsSubTabIndex => _pendingTripsSubTabIndex;

  void requestTripHighlight(String tripId, {int? subTabIndex}) {
    _pendingHighlightTripId = tripId;
    _pendingTripsSubTabIndex = subTabIndex ?? 3;
    notifyListeners();
  }

  void clearTripHighlight() {
    _pendingHighlightTripId = null;
    _pendingTripsSubTabIndex = null;
    notifyListeners();
  }
}

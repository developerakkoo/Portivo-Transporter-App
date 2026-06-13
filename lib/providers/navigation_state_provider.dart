import 'package:flutter/foundation.dart';

class NavigationStateProvider with ChangeNotifier {
  String? _pendingHighlightTripId;
  int? _pendingTripsSubTabIndex;

  /// Opens Trips tab at this sub-tab (0–4) from Home overview cards, without highlight.
  int? _pendingOpenTripsSubTabOnly;
  int _openTripsSubTabNonce = 0;

  String? get pendingHighlightTripId => _pendingHighlightTripId;
  int? get pendingTripsSubTabIndex => _pendingTripsSubTabIndex;

  int? get pendingOpenTripsSubTabOnly => _pendingOpenTripsSubTabOnly;
  int get openTripsSubTabNonce => _openTripsSubTabNonce;

  void requestTripHighlight(String tripId, {int? subTabIndex}) {
    _pendingHighlightTripId = tripId;
    _pendingTripsSubTabIndex = subTabIndex ?? 4;
    notifyListeners();
  }

  void clearTripHighlight() {
    _pendingHighlightTripId = null;
    _pendingTripsSubTabIndex = null;
    notifyListeners();
  }

  /// Switch main shell to Trips and focus the given [TabController] index (Active=0, etc.).
  void requestOpenTripsSubTab(int index) {
    _pendingOpenTripsSubTabOnly = index;
    _openTripsSubTabNonce++;
    notifyListeners();
  }

  void clearPendingOpenTripsSubTab() {
    _pendingOpenTripsSubTabOnly = null;
    notifyListeners();
  }
}

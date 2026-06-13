import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/vehicle_type_model.dart';
import '../data/models/vehicle_type_request_model.dart';
import '../services/socket_service.dart';
import '../services/vehicle_type_service.dart';

class VehicleTypeProvider with ChangeNotifier {
  static const _dismissedRecentDecisionsKey = 'vehicle_type_dismissed_recent_decisions';

  final VehicleTypeService _service = VehicleTypeService();
  final SocketService _socketService = SocketService();

  List<VehicleTypeModel> _types = [];
  List<VehicleTypeRequestModel> _myRequests = [];
  final Set<String> _dismissedRecentDecisionIds = {};
  bool _dismissedIdsLoaded = false;
  bool _isLoading = false;
  bool _isLoadingRequests = false;
  String? _error;

  VehicleTypeProvider() {
    _socketService.addVehicleTypeRequestListener(_onVehicleTypeRequestUpdated);
  }

  void _onVehicleTypeRequestUpdated(Map<String, dynamic> _) {
    ensureLoaded(refresh: true);
  }

  List<VehicleTypeModel> get types => _types;
  List<VehicleTypeRequestModel> get myRequests => _myRequests;
  List<String> get typeNames => _types.map((t) => t.name).toList();
  List<String> get pendingTypeNames => _myRequests
      .where((r) => r.isPending)
      .map((r) => r.requestedName)
      .toList();
  bool get isLoading => _isLoading;
  bool get isLoadingRequests => _isLoadingRequests;
  String? get error => _error;
  bool get hasTypes => _types.isNotEmpty;

  List<VehicleTypeRequestModel> get recentDecisions {
    final decisions = _myRequests
        .where((r) => r.isApproved || r.isRejected)
        .toList();
    decisions.sort((a, b) {
      final aTime = a.reviewedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.reviewedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return decisions;
  }

  List<VehicleTypeRequestModel> get visibleRecentDecisions {
    return recentDecisions
        .where((request) => !_dismissedRecentDecisionIds.contains(request.id))
        .toList();
  }

  Future<void> _loadDismissedIds() async {
    if (_dismissedIdsLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_dismissedRecentDecisionsKey) ?? const [];
    _dismissedRecentDecisionIds
      ..clear()
      ..addAll(stored);
    _dismissedIdsLoaded = true;
    notifyListeners();
  }

  Future<void> clearVisibleRecentDecisions() async {
    await _loadDismissedIds();

    final idsToDismiss = visibleRecentDecisions.map((request) => request.id);
    if (idsToDismiss.isEmpty) return;

    _dismissedRecentDecisionIds.addAll(idsToDismiss);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dismissedRecentDecisionsKey,
      _dismissedRecentDecisionIds.toList(),
    );
    notifyListeners();
  }

  Future<void> dismissDecision(String requestId) async {
    await _loadDismissedIds();
    if (_dismissedRecentDecisionIds.contains(requestId)) return;

    _dismissedRecentDecisionIds.add(requestId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dismissedRecentDecisionsKey,
      _dismissedRecentDecisionIds.toList(),
    );
    notifyListeners();
  }

  Future<void> dismissApprovalBanner(String name) async {
    final request = requestForName(name);
    if (request == null || !request.isApproved) return;
    await dismissDecision(request.id);
  }

  VehicleTypeRequestModel? requestForName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final trimmed = name.trim();
    for (final request in _myRequests) {
      if (request.requestedName == trimmed) {
        return request;
      }
    }
    return null;
  }

  bool isRejectedType(String? name) => requestForName(name)?.isRejected ?? false;

  bool isRecentApproval(String? name) {
    final request = requestForName(name);
    if (request == null || !request.isApproved) return false;
    if (_dismissedRecentDecisionIds.contains(request.id)) return false;
    final reviewedAt = request.reviewedAt;
    if (reviewedAt == null) return true;
    return DateTime.now().difference(reviewedAt).inDays <= 7;
  }

  Future<void> loadTypes({bool refresh = false}) async {
    if (!refresh && _types.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _types = await _service.getActiveTypes();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('VehicleTypeProvider: Error loading types: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyRequests({bool refresh = false}) async {
    if (!refresh && _myRequests.isNotEmpty) return;

    _isLoadingRequests = true;
    notifyListeners();

    try {
      _myRequests = await _service.getMyRequests();
    } catch (e) {
      if (kDebugMode) {
        print('VehicleTypeProvider: Error loading requests: $e');
      }
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  Future<void> ensureLoaded({bool refresh = false}) async {
    await _loadDismissedIds();
    await Future.wait([
      loadTypes(refresh: refresh),
      loadMyRequests(refresh: refresh),
    ]);
  }

  List<String> filterTypeNames(String query) {
    return filterVehicleTypeNames(
      catalogNames: typeNames,
      pendingNames: pendingTypeNames,
      query: query,
    );
  }

  bool isPendingType(String? name) {
    if (name == null) return false;
    return pendingTypeNames.contains(name);
  }

  Future<String?> submitNewType(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final request = await _service.submitRequest(trimmed);
    _myRequests = [
      request,
      ..._myRequests.where((r) => r.id != request.id),
    ];
    notifyListeners();
    return request.requestedName;
  }
}

List<String> filterVehicleTypeNames({
  required List<String> catalogNames,
  required List<String> pendingNames,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  final allNames = <String>[
    ...pendingNames,
    ...catalogNames.where((name) => !pendingNames.contains(name)),
  ];

  if (q.isEmpty) return allNames;

  return allNames.where((name) => name.toLowerCase().contains(q)).toList();
}

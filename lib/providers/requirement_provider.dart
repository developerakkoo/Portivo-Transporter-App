import 'package:flutter/foundation.dart';
import '../data/models/requirement_model.dart';
import '../services/requirement_service.dart';
import '../services/socket_service.dart';
import '../utils/error_utils.dart';

/// Holds the requester's posted inquiries and the transporter's incoming
/// inquiry feed. Refreshes on the generic `notification:new` socket ping.
class RequirementProvider with ChangeNotifier {
  final RequirementService _service = RequirementService();
  final SocketService _socket = SocketService();

  List<RequirementModel> _mine = [];
  List<RequirementModel> _incoming = [];
  bool _loadingMine = false;
  bool _loadingIncoming = false;
  String? _error;

  List<RequirementModel> get mine => _mine;
  List<RequirementModel> get incoming => _incoming;
  bool get loadingMine => _loadingMine;
  bool get loadingIncoming => _loadingIncoming;
  String? get error => _error;

  RequirementProvider() {
    _socket.addNotificationListener(_onPing);
  }

  void _onPing(Map<String, dynamic> _) {
    // A relevant event happened; refresh both feeds if they're in use.
    loadMine(silent: true);
    loadIncoming(silent: true);
  }

  Future<void> loadMine({bool silent = false}) async {
    if (!silent) {
      _loadingMine = true;
      _error = null;
      notifyListeners();
    }
    try {
      _mine = await _service.fetchMine();
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) print('RequirementProvider.loadMine: $e');
    } finally {
      _loadingMine = false;
      notifyListeners();
    }
  }

  Future<void> loadIncoming({bool silent = false}) async {
    if (!silent) {
      _loadingIncoming = true;
      _error = null;
      notifyListeners();
    }
    try {
      _incoming = await _service.fetchIncoming();
    } catch (e) {
      _error = ErrorUtils.userMessage(e);
      if (kDebugMode) print('RequirementProvider.loadIncoming: $e');
    } finally {
      _loadingIncoming = false;
      notifyListeners();
    }
  }

  Future<RequirementModel> create({
    required String origin,
    required String destination,
    required String vehicleType,
    required String direction,
    int noOfVehicles = 1,
    DateTime? requiredBy,
    String? remarks,
  }) async {
    final created = await _service.create(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      direction: direction,
      noOfVehicles: noOfVehicles,
      requiredBy: requiredBy,
      remarks: remarks,
    );
    _mine = [created, ..._mine];
    notifyListeners();
    return created;
  }

  Future<void> cancel(String id) async {
    await _service.cancel(id);
    await loadMine(silent: true);
  }

  @override
  void dispose() {
    _socket.removeNotificationListener(_onPing);
    super.dispose();
  }
}

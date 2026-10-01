import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/models/trip_model.dart';
import '../data/models/vehicle_model.dart';
import '../data/models/driver_model.dart';
import '../providers/trip_provider.dart';
import '../providers/customer_provider.dart';
import '../widgets/trip_operational_location_fields.dart';
import '../core/utils/trip_operational_locations.dart';
import 'location_picker_screen.dart';
import '../providers/vehicle_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';
import '../core/utils/vehicle_driver_resolver.dart';
import '../core/utils/validators.dart';

final NumberFormat _inrFormat =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String _formatInr(num value) => _inrFormat.format(value);

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key, this.draftId});

  final String? draftId;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

/// One vehicle + driver (+ optional container + advance) inside a route.
class _AssignmentEntry {
  final TextEditingController containerController;
  final TextEditingController advanceController;
  FocusNode? _containerFocusNode;
  VehicleModel? vehicle;
  DriverModel? driver;

  _AssignmentEntry()
      : containerController = TextEditingController(),
        advanceController = TextEditingController();

  FocusNode get containerFocusNode => _containerFocusNode ??= FocusNode();

  double? get advance => double.tryParse(advanceController.text.trim());

  bool get isComplete => vehicle != null && driver != null;

  void dispose() {
    containerController.dispose();
    advanceController.dispose();
    _containerFocusNode?.dispose();
  }
}

/// One route in a multi-route trip: its own direction, A/B/C locations and a
/// list of vehicle/driver assignments. Each route maps 1:1 to a backend Trip.
class _RouteEntry {
  String tripType;
  final OperationalLocationDraft locations;
  final List<_AssignmentEntry> assignments;
  final GlobalKey cardKey;
  final TextEditingController distanceKm = TextEditingController();

  _RouteEntry({String? tripType})
      : tripType = tripType ?? AppConstants.tripTypeExport,
        locations = OperationalLocationDraft(
          tripType: tripType ?? AppConstants.tripTypeExport,
        ),
        assignments = [_AssignmentEntry()],
        cardKey = GlobalKey();

  int get vehicleCount => assignments.where((a) => a.vehicle != null).length;

  int get driverCount => assignments.where((a) => a.driver != null).length;

  double get advanceTotal {
    double sum = 0;
    for (final a in assignments) {
      final v = a.advance;
      if (v != null) sum += v;
    }
    return sum;
  }

  void dispose() {
    locations.dispose();
    distanceKm.dispose();
    for (final a in assignments) {
      a.dispose();
    }
  }
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();

  final List<_RouteEntry> _routes = [];
  final _tripReferenceController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _tripRefFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isSavingDraft = false;
  bool _draftSavedHint = false;
  String? _draftId;
  Timer? _autosaveDebounce;
  int _expandedRouteIndex = 0;
  int _wizardStep = 0;
  bool _payNow = true;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    _routes.add(_RouteEntry());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<VehicleProvider>().loadVehicles(
            status: 'active',
            availableForTrip: true,
            refresh: true,
          );
      context.read<DriverProvider>().loadDrivers(
            availableForTrip: true,
            refresh: true,
          );
      context.read<CustomerProvider>().loadCustomers(refresh: true);
      if (_draftId != null && mounted) {
        await _loadDraft(_draftId!);
      }
    });
    _customerFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _customerNameController.addListener(_scheduleAutosave);
    _tripReferenceController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _customerNameController.removeListener(_scheduleAutosave);
    _tripReferenceController.removeListener(_scheduleAutosave);
    for (final r in _routes) {
      r.dispose();
    }
    _tripReferenceController.dispose();
    _customerNameController.dispose();
    _customerFocusNode.dispose();
    _tripRefFocusNode.dispose();
    super.dispose();
  }

  // --- Aggregate summary getters -------------------------------------------

  int get _totalRoutes => _routes.length;
  int get _totalVehicles =>
      _routes.fold(0, (sum, r) => sum + r.vehicleCount);
  int get _totalDrivers =>
      _routes.fold(0, (sum, r) => sum + r.driverCount);
  double get _totalAdvance =>
      _routes.fold(0.0, (sum, r) => sum + r.advanceTotal);

  // --- Cross-route selection helpers (prevent double-booking) --------------

  Set<String> _allSelectedVehicleIds({_AssignmentEntry? except}) {
    final ids = <String>{};
    for (final r in _routes) {
      for (final a in r.assignments) {
        if (identical(a, except)) continue;
        final v = a.vehicle;
        if (v != null) ids.add(v.id);
      }
    }
    return ids;
  }

  Set<String> _allSelectedDriverIds({_AssignmentEntry? except}) {
    final ids = <String>{};
    for (final r in _routes) {
      for (final a in r.assignments) {
        if (identical(a, except)) continue;
        final d = a.driver;
        if (d != null) ids.add(d.id);
      }
    }
    return ids;
  }

  // --- Route management -----------------------------------------------------

  void _addRoute({bool openRouteStep = false}) {
    final inherited = _routes.isNotEmpty
        ? _routes.first.tripType
        : AppConstants.tripTypeExport;
    setState(() {
      _routes.add(_RouteEntry(tripType: inherited));
      _expandedRouteIndex = _routes.length - 1;
      if (openRouteStep) _wizardStep = 1;
    });
    _scheduleAutosave();
  }

  void _removeRoute(int index) {
    if (_routes.length <= 1) return;
    setState(() {
      _routes[index].dispose();
      _routes.removeAt(index);
      if (_expandedRouteIndex >= _routes.length) {
        _expandedRouteIndex = _routes.length - 1;
      } else if (_expandedRouteIndex > index) {
        _expandedRouteIndex--;
      }
    });
    _scheduleAutosave();
  }

  void _addAssignment(_RouteEntry route) {
    final entry = _AssignmentEntry();
    setState(() => route.assignments.add(entry));
    _scheduleAutosave();
    _editAssignment(route, entry);
  }

  void _removeAssignment(_RouteEntry route, int index) {
    if (route.assignments.length <= 1) return;
    setState(() {
      route.assignments[index].dispose();
      route.assignments.removeAt(index);
    });
    _scheduleAutosave();
  }

  Future<void> _openLocationPicker(
    _RouteEntry route,
    OperationalPoint startPoint,
  ) async {
    final current = route.locations.locationForPoint(startPoint);
    final result = await Navigator.push<TripLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          isPickup: startPoint == OperationalPoint.a,
          appBarTitle:
              TripOperationalLocations.pickerTitle(route.tripType, startPoint),
          initialQuery: current?.address,
          showMap: false,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => route.locations.setLocation(startPoint, result));
    _scheduleAutosave();
  }

  Future<VehicleModel?> _selectVehicle(
    BuildContext context,
    _AssignmentEntry entry,
  ) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final excludeIds = _allSelectedVehicleIds(except: entry);
    final vehicles = vehicleProvider.vehicles
        .where((v) => !excludeIds.contains(v.id))
        .toList();
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicles available')),
      );
      return null;
    }
    final drivers = context.read<DriverProvider>().drivers;
    return showDialog<VehicleModel>(
      context: context,
      builder: (context) => _VehiclePickerDialog(
        vehicles: vehicles,
        drivers: drivers,
      ),
    );
  }

  Future<DriverModel?> _selectDriver(
    BuildContext context,
    _AssignmentEntry entry,
  ) async {
    final driverProvider = context.read<DriverProvider>();
    final excludeIds = _allSelectedDriverIds(except: entry);
    final drivers = driverProvider.drivers
        .where((d) =>
            d.status == AppConstants.driverStatusActive &&
            !excludeIds.contains(d.id))
        .toList();
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No drivers available')),
      );
      return null;
    }
    return showDialog<DriverModel>(
      context: context,
      builder: (context) => _DriverPickerDialog(drivers: drivers),
    );
  }

  // --- Payload builders -----------------------------------------------------

  /// Batch payload for POST /trips/batch (only complete assignments included).
  Map<String, dynamic> _buildBatchPayload() {
    final routesPayload = <Map<String, dynamic>>[];
    for (final r in _routes) {
      final assignments = <Map<String, dynamic>>[];
      for (final a in r.assignments) {
        if (!a.isComplete) continue;
        final cn = Validators.normalizeContainerNumber(a.containerController.text);
        final adv = a.advance;
        assignments.add(<String, dynamic>{
          'vehicleId': a.vehicle!.id,
          'driverId': a.driver!.id,
          if (cn.isNotEmpty) 'containerNumber': cn,
          if (adv != null) 'advanceAmount': adv,
        });
      }
      routesPayload.add(<String, dynamic>{
        'tripType': r.tripType.toUpperCase(),
        ...r.locations.buildPayload(),
        'assignments': assignments,
      });
    }

    return <String, dynamic>{
      'customerName': _customerNameController.text.trim().toUpperCase(),
      'reference': _tripReferenceController.text.trim().isNotEmpty
          ? _tripReferenceController.text.trim().toUpperCase()
          : null,
      'routes': routesPayload,
    };
  }

  /// Full snapshot (including incomplete rows) so a draft can be resumed.
  Map<String, dynamic> _buildBatchDraft() {
    final routes = <Map<String, dynamic>>[];
    for (final r in _routes) {
      final assignments = <Map<String, dynamic>>[];
      for (final a in r.assignments) {
        assignments.add(<String, dynamic>{
          'vehicleId': a.vehicle?.id,
          'driverId': a.driver?.id,
          'containerNumber':
              Validators.normalizeContainerNumber(a.containerController.text),
          'advanceAmount': a.advance,
        });
      }
      routes.add(<String, dynamic>{
        'tripType': r.tripType,
        'pickupLocation': r.locations.pickup?.toJson(),
        'intermediateLocation': r.locations.intermediate?.toJson(),
        'dropLocation': r.locations.drop?.toJson(),
        'assignments': assignments,
      });
    }
    return <String, dynamic>{
      'customerName': _customerNameController.text.trim(),
      'reference': _tripReferenceController.text.trim(),
      'routes': routes,
    };
  }

  // --- Validation -----------------------------------------------------------

  /// Returns null when valid, otherwise `(message, routeIndexToExpand)`.
  (String, int?)? _validateBeforeStart() {
    if (_customerNameController.text.trim().isEmpty) {
      return ('Customer is required', null);
    }

    final allVehicleIds = <String>[];
    final allDriverIds = <String>[];

    for (var i = 0; i < _routes.length; i++) {
      final r = _routes[i];
      if (!r.locations.isComplete) {
        return ('Route ${i + 1}: set all locations', i);
      }
      final complete = r.assignments.where((a) => a.isComplete).toList();
      if (complete.isEmpty) {
        return ('Route ${i + 1}: add at least one vehicle and driver', i);
      }
      for (final a in complete) {
        allVehicleIds.add(a.vehicle!.id);
        allDriverIds.add(a.driver!.id);
      }
    }

    if (allVehicleIds.length != allVehicleIds.toSet().length) {
      return ('A vehicle is used in more than one route', null);
    }
    if (allDriverIds.length != allDriverIds.toSet().length) {
      return ('A driver is used in more than one route', null);
    }
    return null;
  }

  bool get _canStart =>
      _customerNameController.text.trim().isNotEmpty &&
      !_isLoading &&
      !_isSavingDraft;

  // --- Actions --------------------------------------------------------------

  Future<void> _handleStartTrip() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = _validateBeforeStart();
    if (error != null) {
      if (error.$2 != null) {
        setState(() => _expandedRouteIndex = error.$2!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.$1), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final tripProvider = context.read<TripProvider>();
      final trips = await tripProvider.createTripBatch(_buildBatchPayload());
      if (!mounted) return;
      if (trips != null && trips.isNotEmpty) {
        if (_draftId != null) {
          await tripProvider.deleteDraft(_draftId!);
        }
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Trip started with ${trips.length} route(s)'),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pushNamed('/trip-detail', arguments: trips.first.id);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(tripProvider.error ?? 'Failed to start trip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSaveDraft() async {
    setState(() => _isSavingDraft = true);
    try {
      final tripProvider = context.read<TripProvider>();
      final draft = await tripProvider.saveDraft(
        _draftPayload(),
        draftId: _draftId,
      );
      if (!mounted) return;
      if (draft != null) {
        setState(() {
          _draftId = draft.id;
          _draftSavedHint = true;
        });
        await tripProvider.loadDrafts(refresh: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tripProvider.error ?? 'Failed to save draft'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  Map<String, dynamic> _draftPayload() {
    return <String, dynamic>{
      'customerName': _customerNameController.text.trim().isNotEmpty
          ? _customerNameController.text.trim().toUpperCase()
          : null,
      'reference': _tripReferenceController.text.trim().isNotEmpty
          ? _tripReferenceController.text.trim().toUpperCase()
          : null,
      'tripType': _routes.isNotEmpty
          ? _routes.first.tripType.toUpperCase()
          : AppConstants.tripTypeExport,
      'batchDraft': _buildBatchDraft(),
    };
  }

  bool get _draftHasContent {
    if (_customerNameController.text.trim().isNotEmpty) return true;
    if (_tripReferenceController.text.trim().isNotEmpty) return true;
    for (final route in _routes) {
      if ((route.locations.pickup?.address ?? '').trim().isNotEmpty) {
        return true;
      }
      if ((route.locations.intermediate?.address ?? '').trim().isNotEmpty) {
        return true;
      }
      if ((route.locations.drop?.address ?? '').trim().isNotEmpty) {
        return true;
      }
      if (route.assignments.any((a) => a.vehicle != null || a.driver != null)) {
        return true;
      }
    }
    return false;
  }

  void _scheduleAutosave() {
    _autosaveDebounce?.cancel();
    if (!_draftHasContent) return;
    _autosaveDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_autosaveDraft());
    });
  }

  Future<void> _autosaveDraft() async {
    if (!mounted || _isLoading || _isSavingDraft || !_draftHasContent) return;
    try {
      final draft = await context.read<TripProvider>().saveDraft(
            _draftPayload(),
            draftId: _draftId,
            silent: true,
          );
      if (!mounted || draft == null) return;
      setState(() {
        _draftId = draft.id;
        _draftSavedHint = true;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CreateTrip autosave failed: $e');
      }
    }
  }

  Future<void> _loadDraft(String draftId) async {
    final tripProvider = context.read<TripProvider>();
    final vehicleProvider = context.read<VehicleProvider>();
    final driverProvider = context.read<DriverProvider>();
    final draft = await tripProvider.loadDraft(draftId);
    if (!mounted || draft == null) return;

    VehicleModel? findVehicle(String? id) {
      if (id == null || id.isEmpty) return null;
      try {
        return vehicleProvider.vehicles.firstWhere((v) => v.id == id);
      } catch (_) {
        return null;
      }
    }

    DriverModel? findDriver(String? id) {
      if (id == null || id.isEmpty) return null;
      try {
        return driverProvider.drivers.firstWhere((d) => d.id == id);
      } catch (_) {
        return null;
      }
    }

    final batchDraft = draft.batchDraft;
    final rawRoutes = batchDraft?['routes'];

    final newRoutes = <_RouteEntry>[];

    if (rawRoutes is List && rawRoutes.isNotEmpty) {
      for (final raw in rawRoutes) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final route = _RouteEntry(
          tripType: map['tripType']?.toString() ?? AppConstants.tripTypeExport,
        );
        route.locations.tripType = route.tripType;
        route.locations.pickup = _tripLocationFromJson(map['pickupLocation']);
        route.locations.intermediate =
            _tripLocationFromJson(map['intermediateLocation']);
        route.locations.drop = _tripLocationFromJson(map['dropLocation']);
        route.locations.syncControllersFromState();

        final rawAssignments = map['assignments'];
        if (rawAssignments is List && rawAssignments.isNotEmpty) {
          for (final a in route.assignments) {
            a.dispose();
          }
          route.assignments.clear();
          for (final ra in rawAssignments) {
            if (ra is! Map) continue;
            final am = Map<String, dynamic>.from(ra);
            final entry = _AssignmentEntry();
            entry.containerController.text =
                am['containerNumber']?.toString() ?? '';
            final adv = am['advanceAmount'];
            if (adv != null) {
              entry.advanceController.text =
                  adv is num ? adv.toStringAsFixed(0) : adv.toString();
            }
            entry.vehicle = findVehicle(am['vehicleId']?.toString());
            entry.driver = findDriver(am['driverId']?.toString());
            route.assignments.add(entry);
          }
          if (route.assignments.isEmpty) {
            route.assignments.add(_AssignmentEntry());
          }
        }
        newRoutes.add(route);
      }
    } else {
      // Legacy single-route draft: reconstruct one route from flat fields.
      final route = _RouteEntry(tripType: draft.tripType);
      route.locations.tripType = draft.tripType;
      route.locations.pickup = draft.pickupLocation;
      route.locations.intermediate = draft.intermediateLocation;
      route.locations.drop = draft.dropLocation;
      route.locations.syncControllersFromState();

      final assignmentEntries = draft.assignments;
      if (assignmentEntries != null && assignmentEntries.isNotEmpty) {
        for (final a in route.assignments) {
          a.dispose();
        }
        route.assignments.clear();
        for (final a in assignmentEntries) {
          final entry = _AssignmentEntry();
          entry.containerController.text = a.containerNumber;
          if (a.advanceAmount != null) {
            entry.advanceController.text = a.advanceAmount!.toStringAsFixed(0);
          }
          entry.vehicle = findVehicle(a.vehicleId);
          entry.driver = findDriver(a.driverId);
          route.assignments.add(entry);
        }
        if (route.assignments.isEmpty) {
          route.assignments.add(_AssignmentEntry());
        }
      }
      newRoutes.add(route);
    }

    if (newRoutes.isEmpty) newRoutes.add(_RouteEntry());

    setState(() {
      _draftId = draft.id;
      for (final r in _routes) {
        r.dispose();
      }
      _routes
        ..clear()
        ..addAll(newRoutes);
      _customerNameController.text =
          batchDraft?['customerName']?.toString() ?? draft.customerName ?? '';
      _tripReferenceController.text =
          batchDraft?['reference']?.toString() ?? draft.reference ?? '';
      _expandedRouteIndex = 0;
    });
  }

  TripLocation? _tripLocationFromJson(dynamic value) {
    if (value is Map) {
      try {
        return TripLocation.fromJson(Map<String, dynamic>.from(value));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _showAddCustomerDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddCustomerDialog(),
    );
    if (!mounted || name == null || name.isEmpty) return;

    final customerProvider = context.read<CustomerProvider>();
    final customer = await customerProvider.addCustomer(name);
    if (!mounted) return;
    if (customer != null) {
      setState(() => _customerNameController.text = customer.name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(customerProvider.error ?? 'Failed to add customer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, authChild) {
        final permissionService = PermissionService(authProvider);

        if (!permissionService.hasPermission('createTrips') &&
            !permissionService.isTransporter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to create trips'),
                backgroundColor: Colors.red,
              ),
            );
          });
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Create Trip')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final titles = ['Create Trip', 'Route & Vehicles', 'Review Trip'];
        return Scaffold(
          backgroundColor: AppColors.background,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[_wizardStep]),
                if (_draftSavedHint)
                  Text(
                    'Draft saved',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                  ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (_wizardStep > 0) {
                  setState(() => _wizardStep -= 1);
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
            actions: [
              if (_wizardStep == 0)
                TextButton.icon(
                  onPressed:
                      (_isLoading || _isSavingDraft) ? null : _handleSaveDraft,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text(AppCopy.saveDraft),
                )
              else if (_wizardStep == 1)
                TextButton(
                  onPressed: (_isLoading || _isSavingDraft)
                      ? null
                      : () => setState(() => _wizardStep = 2),
                  child: const Text('View Summary'),
                ),
            ],
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _wizardStep == 0
                    ? _buildCustomerStep(textTheme)
                    : _wizardStep == 1
                        ? _buildRouteStep(textTheme)
                        : _buildReviewStep(textTheme),
              ),
            ),
          ),
          bottomNavigationBar:
              _wizardStep == 2 ? null : _buildBottomBar(textTheme),
        );
      },
    );
  }

  Widget _buildCustomerStep(TextTheme textTheme) {
    final route = _routes.first;
    final isExport =
        route.tripType.toUpperCase() == AppConstants.tripTypeExport;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Customer Details',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildCustomerNameField(textTheme),
                  const SizedBox(height: 8),
                  _buildTripReferenceField(textTheme),
                  const SizedBox(height: 12),
                  Text(
                    'Trip Type',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildTripTypePills(route),
                  const SizedBox(height: 8),
                  if (isExport) _buildExportNote(textTheme),
                  const Spacer(),
                  _buildHeroIllustration(textTheme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteStep(TextTheme textTheme) {
    final index = _focusedRouteIndex;
    final route = _routes[index];
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return KeyedSubtree(
      key: route.cardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCustomerSubtitle(textTheme),
          if (_routes.length > 1) ...[
            _buildRouteSwitcher(),
            const SizedBox(height: 6),
          ],
          _buildRouteHeader(index, route, textTheme),
          _buildTimeline(route),
          const SizedBox(height: 6),
          _buildDistanceField(route),
          const SizedBox(height: 16),
          Visibility(
            visible: !keyboardOpen,
            maintainState: true,
            child: _buildVehiclesHeader(index, route, textTheme),
          ),
          Expanded(
            child: Visibility(
              visible: !keyboardOpen,
              maintainState: true,
              child: _buildVehicleList(route),
            ),
          ),
          Visibility(
            visible: !keyboardOpen,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildDashedButton(
                label: 'Add Another Route',
                onPressed: _addRoute,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(TextTheme textTheme) {
    final index = _focusedRouteIndex;
    final route = _routes[index];
    final contentWidth = MediaQuery.sizeOf(context).width - 32;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildReviewCustomerCard(textTheme),
                  const SizedBox(height: 8),
                  if (_routes.length > 1) ...[
                    _buildRouteSwitcher(),
                    const SizedBox(height: 6),
                  ],
                  _buildReviewRouteCard(index, route, textTheme),
                  const SizedBox(height: 8),
                  _buildReviewVehiclesCard(textTheme),
                  const SizedBox(height: 8),
                  _buildTotalAdvanceRow(textTheme),
                  const SizedBox(height: 6),
                  _buildPaymentChoice(textTheme),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildDashedButton(
          label: 'Add Another Route',
          onPressed: () => _addRoute(openRouteStep: true),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_isLoading || _isSavingDraft)
                    ? null
                    : () => setState(() => _wizardStep = 1),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Edit Trip'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _canStart ? _handleStartTrip : null,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.background),
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 20),
                label: const Text('Start Trip'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAllSetBanner(textTheme),
      ],
    );
  }

  int get _focusedRouteIndex =>
      _expandedRouteIndex.clamp(0, _routes.length - 1);

  Widget _buildCustomerSubtitle(TextTheme textTheme) {
    final name = _customerNameController.text.trim();
    final ref = _tripReferenceController.text.trim();
    final refPart = ref.isEmpty ? '' : '  |  Ref No.: $ref';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Customer: ${name.isEmpty ? '—' : name}$refPart',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildTripTypePills(_RouteEntry route, {VoidCallback? onChanged}) {
    const types = [
      AppConstants.tripTypeImport,
      AppConstants.tripTypeExport,
      AppConstants.tripTypeLocal,
    ];
    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildTypePill(route, types[i], onChanged)),
        ],
      ],
    );
  }

  Widget _buildTypePill(
    _RouteEntry route,
    String type,
    VoidCallback? onChanged,
  ) {
    final selected = route.tripType.toUpperCase() == type;
    final label = '${type[0]}${type.substring(1).toLowerCase()}';
    return Material(
      color: selected ? AppColors.primary : AppColors.background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          setState(() {
            route.tripType = type;
            route.locations.onTripTypeChanged(type);
          });
          onChanged?.call();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.dividerGrey,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.background : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportNote(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'For Export trips, return point (C) will be same as pickup point (A). You can change it later if required.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroIllustration(TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_shipping_outlined,
          size: 64,
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        Text(
          'Move Faster.',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          'Manage Smarter.',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'PORTTIVO',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteSwitcher() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _routes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _focusedRouteIndex;
          return ChoiceChip(
            label: Text('Route ${index + 1}'),
            selected: selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.background : AppColors.textPrimary,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.offWhite,
            onSelected: (_) => setState(() => _expandedRouteIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildRouteHeader(int index, _RouteEntry route, TextTheme textTheme) {
    return Row(
      children: [
        Text(
          'Route ${index + 1}',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        _buildDirectionChip(route.tripType),
        const Spacer(),
        _compactTextButton('Edit', () => _showRouteEditor(route)),
      ],
    );
  }

  Widget _buildTimeline(_RouteEntry route) {
    final points = TripOperationalLocations.visiblePoints(route.tripType);
    return Column(
      children: [
        for (var i = 0; i < points.length; i++) ...[
          _buildPointRow(route, points[i]),
          if (i < points.length - 1)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 10),
                width: 2,
                height: 8,
                color: AppColors.dividerGrey,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPointRow(_RouteEntry route, OperationalPoint point) {
    final address = _pointAddress(route, point);
    final empty =
        route.locations.locationForPoint(point)?.address?.trim().isEmpty ??
            true;
    return InkWell(
      onTap: () => _openLocationPicker(route, point),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            _pointBadge(point),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: empty ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                  if (_pointSameAsA(route, point))
                    const Text(
                      'Same as Point A (auto-filled)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.menu, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _pointBadge(OperationalPoint point) {
    final color = switch (point) {
      OperationalPoint.a => AppColors.success,
      OperationalPoint.b => AppColors.info,
      OperationalPoint.c => AppColors.primary,
    };
    final letter = switch (point) {
      OperationalPoint.a => 'A',
      OperationalPoint.b => 'B',
      OperationalPoint.c => 'C',
    };
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _pointAddress(_RouteEntry route, OperationalPoint point) {
    final addr = route.locations.locationForPoint(point)?.address?.trim();
    if (addr == null || addr.isEmpty) {
      return 'Select ${TripOperationalLocations.labelForPoint(route.tripType, point)}';
    }
    return addr;
  }

  bool _pointSameAsA(_RouteEntry route, OperationalPoint point) {
    if (point != OperationalPoint.c) return false;
    final a = route.locations.pickup?.address?.trim();
    final c = route.locations.drop?.address?.trim();
    return a != null && a.isNotEmpty && a == c;
  }

  Widget _buildDistanceField(_RouteEntry route) {
    return TextField(
      controller: route.distanceKm,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelText: 'Estimated Distance (Optional)',
        hintText: 'e.g. 125',
        suffixText: 'km',
        prefixIcon: Icon(Icons.alt_route, size: 18),
      ),
    );
  }

  Widget _buildVehiclesHeader(
    int index,
    _RouteEntry route,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Vehicles for Route ${index + 1}',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _compactTextButton(
          'Add Vehicle',
          () => _addAssignment(route),
          icon: Icons.add,
        ),
      ],
    );
  }

  Widget _buildVehicleList(_RouteEntry route) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: route.assignments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildVehicleRow(route, index),
    );
  }

  Widget _buildVehicleRow(_RouteEntry route, int index) {
    final entry = route.assignments[index];
    final number = entry.vehicle?.vehicleNumber ?? 'Select vehicle';
    final driverName = entry.driver?.name?.trim();
    final driverLabel = (driverName == null || driverName.isEmpty)
        ? (entry.driver?.mobile ?? 'Select driver')
        : driverName;
    return InkWell(
      onTap: () => _editAssignment(route, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.local_shipping, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: entry.vehicle == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    driverLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Advance',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
                Text(
                  _formatInr(entry.advance ?? 0),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            if (route.assignments.length > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Remove vehicle',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () => _removeAssignment(route, index),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCustomerCard(TextTheme textTheme) {
    final customer = _customerNameController.text.trim();
    final reference = _tripReferenceController.text.trim();
    final tripType = _routes.first.tripType;
    final typeLabel = '${tripType[0]}${tripType.substring(1).toLowerCase()}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Details',
            style: textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.apartment_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.isEmpty ? '—' : customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Reference No.  ${reference.isEmpty ? '—' : reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Trip Type',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              const Icon(Icons.swap_horiz, size: 16, color: AppColors.success),
              const SizedBox(width: 4),
              Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRouteCard(int index, _RouteEntry route, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Route ${index + 1}',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _buildDirectionChip(route.tripType),
              const Spacer(),
              _compactTextButton('Edit', () {
                setState(() {
                  _expandedRouteIndex = index;
                  _wizardStep = 1;
                });
              }),
            ],
          ),
          _buildTimeline(route),
        ],
      ),
    );
  }

  Widget _buildReviewVehiclesCard(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Vehicles ($_totalVehicles)',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _compactTextButton(
                'Edit',
                () => setState(() => _wizardStep = 1),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.local_shipping, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_totalVehicles Vehicles  |  $_totalDrivers Drivers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Container details can be added later',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAdvanceRow(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            'Total Advance',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            _formatInr(_totalAdvance),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChoice(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Make Driver Advance',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            const Tooltip(
              message:
                  'Choose when the advance is collected. Either option starts the trip.',
              child: Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPayOption(
                payNow: true,
                title: 'Pay Now',
                subtitle: 'Pay ${_formatInr(_totalAdvance)} and start the trip',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPayOption(
                payNow: false,
                title: 'Pay Later',
                subtitle: 'Pay before delivery',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayOption({
    required bool payNow,
    required String title,
    required String subtitle,
  }) {
    final selected = _payNow == payNow;
    return InkWell(
      onTap: () => setState(() => _payNow = payNow),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSetBanner(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Set!',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  'Once you start the trip, drivers will be notified and you can track it in real-time.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.offWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.dividerGrey),
    );
  }

  Widget _compactTextButton(
    String label,
    VoidCallback onPressed, {
    IconData? icon,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 2),
                Text(label),
              ],
            ),
    );
  }

  Widget _buildDashedButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: const _DashedBorderPainter(color: AppColors.primary),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionChip(String label) {
    final normalized = label.toUpperCase();
    final color = switch (normalized) {
      AppConstants.tripTypeImport => AppColors.info,
      AppConstants.tripTypeLocal => AppColors.warning,
      _ => AppColors.success,
    };
    final pretty = '${normalized[0]}${normalized.substring(1).toLowerCase()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        pretty,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showRouteEditor(_RouteEntry route) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final points = TripOperationalLocations.visiblePoints(route.tripType);
            final textTheme = Theme.of(context).textTheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit route',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text('Trip type', style: textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _buildTripTypePills(route, onChanged: () => setSheetState(() {})),
                    const SizedBox(height: 8),
                    for (final point in points)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _pointBadge(point),
                        title: Text(
                          _pointAddress(route, point),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openLocationPicker(route, point);
                        },
                      ),
                    if (_routes.length > 1)
                      TextButton(
                        onPressed: () {
                          final index = _routes.indexOf(route);
                          Navigator.of(sheetContext).pop();
                          if (index >= 0) _removeRoute(index);
                        },
                        child: const Text(
                          'Remove route',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editAssignment(_RouteEntry route, _AssignmentEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final textTheme = Theme.of(context).textTheme;
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vehicle & advance',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.local_shipping,
                          color: AppColors.primary,
                        ),
                        title: Text(entry.vehicle?.vehicleNumber ?? 'Select vehicle'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final vehicle = await _selectVehicle(sheetContext, entry);
                          if (vehicle == null || !mounted) return;
                          final drivers = this.context.read<DriverProvider>().drivers;
                          final linked = resolveDriverForVehicle(vehicle, drivers);
                          final usedDrivers = _allSelectedDriverIds(except: entry);
                          setState(() {
                            entry.vehicle = vehicle;
                            if (linked != null && !usedDrivers.contains(linked.id)) {
                              entry.driver = linked;
                            }
                          });
                          _scheduleAutosave();
                          setSheetState(() {});
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person, color: AppColors.primary),
                        title: Text(entry.driver?.name ?? 'Select driver'),
                        subtitle: entry.driver == null
                            ? null
                            : Text(entry.driver!.mobile),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final driver = await _selectDriver(sheetContext, entry);
                          if (driver == null || !mounted) return;
                          setState(() => entry.driver = driver);
                          _scheduleAutosave();
                          setSheetState(() {});
                        },
                      ),
                      TextField(
                        controller: entry.advanceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Advance',
                          prefixText: '₹ ',
                          isDense: true,
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _scheduleAutosave();
                        },
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  Widget _buildBottomBar(TextTheme textTheme) {
    final busy = _isLoading || _isSavingDraft;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.dividerGrey)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_wizardStep == 1) ...[
              Row(
                children: [
                  _buildBottomStat(Icons.alt_route, '$_totalRoutes', 'Routes'),
                  _buildBottomStat(
                    Icons.local_shipping,
                    '$_totalVehicles',
                    'Vehicles',
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total Advance',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatInr(_totalAdvance),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: busy
                    ? null
                    : () {
                        if (_wizardStep == 0 &&
                            _customerNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a customer'),
                            ),
                          );
                          return;
                        }
                        setState(() => _wizardStep += 1);
                      },
                child: const Text('Next  →'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomStat(IconData icon, String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerNameField(TextTheme textTheme) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, _) {
        final q = _customerNameController.text.trim().toLowerCase();
        final suggestions = q.isEmpty
            ? customerProvider.customers.take(8).toList()
            : customerProvider.customers
                .where((c) => c.name.toLowerCase().contains(q))
                .take(8)
                .toList();
        final suggestionHeight =
            (suggestions.length * 40.0).clamp(0, 120).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _customerNameController,
              focusNode: _customerFocusNode,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _tripRefFocusNode.requestFocus(),
              validator: (v) => Validators.validateRequired(v?.trim(), 'Customer'),
              decoration: const InputDecoration(
                labelText: 'Customer *',
                hintText: 'Search or enter customer name',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: Icon(Icons.apartment_outlined),
                suffixIcon: Icon(Icons.keyboard_arrow_down),
              ),
            ),
            if (_customerFocusNode.hasFocus && suggestions.isNotEmpty)
              Container(
                height: suggestionHeight,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.dividerGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = suggestions[index];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(customer.name),
                      onTap: () {
                        _customerNameController.text = customer.name;
                        _customerFocusNode.unfocus();
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _showAddCustomerDialog,
                child: const Text('+ Add Customer'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTripReferenceField(TextTheme textTheme) {
    return TextFormField(
      controller: _tripReferenceController,
      focusNode: _tripRefFocusNode,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: AppCopy.tripRefOptional,
        hintText: 'e.g. 12',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: Icon(Icons.tag_outlined),
      ),
    );
  }
}


class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 3.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog();

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Customer'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Customer Name',
          hintText: 'Enter customer name',
        ),
        onSubmitted: (value) {
          final name = value.trim();
          Navigator.of(context).pop(name.isEmpty ? null : name);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            Navigator.of(context).pop(name.isEmpty ? null : name);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Driver Picker Dialog with search
class _DriverPickerDialog extends StatefulWidget {
  final List<DriverModel> drivers;

  const _DriverPickerDialog({required this.drivers});

  @override
  State<_DriverPickerDialog> createState() => _DriverPickerDialogState();
}

class _DriverPickerDialogState extends State<_DriverPickerDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final q = _searchQuery.toLowerCase();
    final filtered = widget.drivers.where((d) {
      final name = (d.name ?? '').toLowerCase();
      final mobile = d.mobile.toLowerCase();
      return name.contains(q) || mobile.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Select Driver',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by driver name or mobile',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: widget.drivers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No available drivers. Complete or cancel in-progress trips first.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No drivers match your search'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final driver = filtered[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  (driver.name?.isNotEmpty ?? false)
                                      ? driver.name![0].toUpperCase()
                                      : 'D',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                driver.name ?? 'Driver',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                driver.mobile,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(driver),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Vehicle Picker Dialog with search
class _VehiclePickerDialog extends StatefulWidget {
  final List<VehicleModel> vehicles;
  final List<DriverModel> drivers;

  const _VehiclePickerDialog({
    required this.vehicles,
    required this.drivers,
  });

  @override
  State<_VehiclePickerDialog> createState() => _VehiclePickerDialogState();
}

class _VehiclePickerDialogState extends State<_VehiclePickerDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final q = _searchQuery.toLowerCase();
    final filtered = widget.vehicles.where((v) {
      final num = v.vehicleNumber.toLowerCase();
      return num.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Select Vehicle',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by vehicle number',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: widget.vehicles.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No available vehicles. Complete or cancel in-progress trips first.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No vehicles match your search'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final vehicle = filtered[index];
                            final linkedDriver = resolveDriverForVehicle(
                              vehicle,
                              widget.drivers,
                            );
                            final driverLabel = linkedDriver != null
                                ? 'Driver: ${linkedDriver.name ?? linkedDriver.mobile}'
                                : null;
                            final subtitleParts = [
                              '${vehicle.ownerType}${vehicle.trailerType != null ? ' • ${vehicle.trailerType}' : ''}',
                              if (driverLabel != null) driverLabel,
                            ];
                            return ListTile(
                              leading: const Icon(
                                Icons.local_shipping,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                vehicle.vehicleNumber,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                subtitleParts.join(' • '),
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(vehicle),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

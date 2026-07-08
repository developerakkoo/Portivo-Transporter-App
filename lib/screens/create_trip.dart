import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key, this.draftId});

  final String? draftId;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _AssignmentEntry {
  final TextEditingController containerController;
  FocusNode? _containerFocusNode;
  VehicleModel? vehicle;
  DriverModel? driver;

  _AssignmentEntry() : containerController = TextEditingController();

  /// Lazily created so hot reload after adding this field does not crash on
  /// assignment entries that already existed in memory.
  FocusNode get containerFocusNode =>
      _containerFocusNode ??= FocusNode();

  void dispose() {
    containerController.dispose();
    _containerFocusNode?.dispose();
  }
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedTripType;
  final List<_AssignmentEntry> _assignments = [];
  late final OperationalLocationDraft _locations;
  final _tripReferenceController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _tripRefFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isSavingDraft = false;
  String? _draftId;
  int _expandedAssignmentIndex = 0;
  final Map<int, GlobalKey> _assignmentCardKeys = {};

  @override
  void initState() {
    super.initState();
    _locations = OperationalLocationDraft();
    _draftId = widget.draftId;
    _assignments.add(_AssignmentEntry());
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
  }

  @override
  void dispose() {
    for (final e in _assignments) {
      e.dispose();
    }
    _locations.dispose();
    _tripReferenceController.dispose();
    _customerNameController.dispose();
    _customerFocusNode.dispose();
    _tripRefFocusNode.dispose();
    super.dispose();
  }

  Set<String> _selectedVehicleIds({int? exceptIndex}) {
    final ids = <String>{};
    for (var i = 0; i < _assignments.length; i++) {
      if (exceptIndex != null && i == exceptIndex) continue;
      final v = _assignments[i].vehicle;
      if (v != null) ids.add(v.id);
    }
    return ids;
  }

  Set<String> _selectedDriverIds({int? exceptIndex}) {
    final ids = <String>{};
    for (var i = 0; i < _assignments.length; i++) {
      if (exceptIndex != null && i == exceptIndex) continue;
      final d = _assignments[i].driver;
      if (d != null) ids.add(d.id);
    }
    return ids;
  }

  Future<void> _loadDraft(String draftId) async {
    final tripProvider = context.read<TripProvider>();
    final vehicleProvider = context.read<VehicleProvider>();
    final driverProvider = context.read<DriverProvider>();
    final draft = await tripProvider.loadDraft(draftId);
    if (!mounted || draft == null) return;

    setState(() {
      _draftId = draft.id;
      _selectedTripType = draft.tripType;
      _locations.tripType = draft.tripType;
      _locations.pickup = draft.pickupLocation;
      _locations.intermediate = draft.intermediateLocation;
      _locations.drop = draft.dropLocation;
      _locations.syncControllersFromState();
      _tripReferenceController.text = draft.reference ?? '';
      _customerNameController.text = draft.customerName ?? '';
    });

    final assignmentEntries = draft.assignments;
    if (assignmentEntries != null && assignmentEntries.isNotEmpty) {
      for (final e in _assignments) {
        e.dispose();
      }
      _assignments.clear();
      _assignmentCardKeys.clear();
      for (final a in assignmentEntries) {
        final entry = _AssignmentEntry();
        entry.containerController.text = a.containerNumber;
        try {
          entry.vehicle = vehicleProvider.vehicles.firstWhere((v) => v.id == a.vehicleId);
        } catch (_) {}
        try {
          entry.driver = driverProvider.drivers.firstWhere((d) => d.id == a.driverId);
        } catch (_) {}
        _assignments.add(entry);
      }
      if (mounted) {
        setState(() {
          _expandedAssignmentIndex = 0;
        });
      }
    }
  }

  void _addAssignment() {
    setState(() {
      _assignments.add(_AssignmentEntry());
      _expandedAssignmentIndex = _assignments.length - 1;
      _assignmentCardKeys.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _assignments.last.containerFocusNode.requestFocus();
      final key = _assignmentCardKeys[_expandedAssignmentIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          alignment: 0.2,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeAssignment(int index) {
    if (_assignments.length <= 1) return;
    setState(() {
      _assignments[index].dispose();
      _assignments.removeAt(index);
      _assignmentCardKeys.clear();
      if (_expandedAssignmentIndex >= _assignments.length) {
        _expandedAssignmentIndex = _assignments.length - 1;
      } else if (_expandedAssignmentIndex > index) {
        _expandedAssignmentIndex--;
      }
    });
  }

  String _assignmentSummary(_AssignmentEntry entry) {
    final container =
        Validators.normalizeContainerNumber(entry.containerController.text);
    final containerLabel = container.isNotEmpty ? container : 'No container';
    final vehicleLabel = entry.vehicle?.vehicleNumber ?? 'No vehicle';
    final driverLabel =
        entry.driver?.name ?? entry.driver?.mobile ?? 'No driver';
    return '$containerLabel · $vehicleLabel · $driverLabel';
  }

  bool _isAssignmentComplete(_AssignmentEntry entry) {
    return entry.vehicle != null && entry.driver != null;
  }

  Future<VehicleModel?> _selectVehicleForAssignment(
    BuildContext context, {
    int? assignmentIndex,
  }) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final excludeIds = _selectedVehicleIds(exceptIndex: assignmentIndex);
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

  Future<DriverModel?> _selectDriverForAssignment(
    BuildContext context, {
    int? assignmentIndex,
  }) async {
    final driverProvider = context.read<DriverProvider>();
    final excludeIds = _selectedDriverIds(exceptIndex: assignmentIndex);
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


  Future<void> _openLocationPicker(OperationalPoint startPoint) async {
    final points = TripOperationalLocations.visiblePoints(_selectedTripType);
    final startIndex = points.indexOf(startPoint);
    if (startIndex < 0) return;

    for (var i = startIndex; i < points.length; i++) {
      final point = points[i];
      final current = _locations.locationForPoint(point);
      final result = await Navigator.push<TripLocation>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            isPickup: point == OperationalPoint.a,
            appBarTitle: TripOperationalLocations.pickerTitle(_selectedTripType, point),
            initialQuery: current?.address,
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() => _locations.setLocation(point, result));
    }
    _customerFocusNode.requestFocus();
  }

  Map<String, dynamic>? _buildTripPayload() {
    if (_selectedTripType == null) return null;

    final assignmentsList = <Map<String, dynamic>>[];
    for (final e in _assignments) {
      if (e.vehicle == null || e.driver == null) continue;
      final cn = Validators.normalizeContainerNumber(e.containerController.text);
      final assignment = <String, dynamic>{
        'vehicleId': e.vehicle!.id,
        'driverId': e.driver!.id,
      };
      if (cn.isNotEmpty) {
        assignment['containerNumber'] = cn;
      }
      assignmentsList.add(assignment);
    }

    return <String, dynamic>{
      'reference': _tripReferenceController.text.trim().isNotEmpty
          ? _tripReferenceController.text.trim().toUpperCase()
          : null,
      'customerName': _customerNameController.text.trim().toUpperCase(),
      ..._locations.buildPayload(),
      'tripType': _selectedTripType!.toUpperCase(),
      if (assignmentsList.isNotEmpty) 'assignments': assignmentsList,
    };
  }

  String? _validateDuplicateAssignments(List<Map<String, dynamic>> assignmentsList) {
    final vehicleIds = <String>[];
    final driverIds = <String>[];
    for (final a in assignmentsList) {
      final v = a['vehicleId']?.toString();
      final d = a['driverId']?.toString();
      if (v != null) vehicleIds.add(v);
      if (d != null) driverIds.add(d);
    }
    if (vehicleIds.length != vehicleIds.toSet().length) {
      return 'Each vehicle can only be assigned once';
    }
    if (driverIds.length != driverIds.toSet().length) {
      return 'Each driver can only be assigned once';
    }
    return null;
  }

  String? _validateContainerFormats() {
    for (final entry in _assignments) {
      final raw = entry.containerController.text;
      final normalized = Validators.normalizeContainerNumber(raw);
      if (normalized.isEmpty) continue;
      if (!Validators.isValidContainerNumber(raw)) {
        return Validators.containerNumberLiveFeedback(raw).message;
      }
    }
    return null;
  }

  bool get _canCreateTrip {
    return _selectedTripType != null &&
        _locations.isComplete &&
        _customerNameController.text.trim().isNotEmpty &&
        !_isLoading &&
        !_isSavingDraft;
  }

  Future<void> _handleCreateTrip() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_canCreateTrip) return;

      final tripData = _buildTripPayload();
      if (tripData == null) return;

      final rawAssignments = tripData['assignments'];
      final assignmentsList = rawAssignments is List
          ? rawAssignments.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (assignmentsList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one assignment with vehicle and driver'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final dupError = _validateDuplicateAssignments(assignmentsList);
      if (dupError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dupError), backgroundColor: Colors.orange),
        );
        return;
      }

      final containerError = _validateContainerFormats();
      if (containerError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(containerError), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        final trip = await tripProvider.createTrip(tripData);

        if (mounted) {
          if (trip != null) {
            Navigator.of(context).pop();
            if (trip.isQueuedBlocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Trip created and queued. It will be ready to start when the current active trip completes.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Trip created successfully with ${assignmentsList.length} assignment(s)',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
            Navigator.of(context).pushNamed(
              '/trip-detail',
              arguments: trip.id,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tripProvider.error ?? 'Failed to create trip'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating trip: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleSaveDraft() async {
    final tripData = _buildTripPayload();
    if (tripData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a trip type to save draft'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final rawAssignments = tripData['assignments'];
    final assignmentsList = rawAssignments is List
        ? rawAssignments.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final dupError = _validateDuplicateAssignments(assignmentsList);
    if (dupError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dupError), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSavingDraft = true);

    try {
      final tripProvider = context.read<TripProvider>();
      final draft = await tripProvider.saveDraft(tripData, draftId: _draftId);
      if (!mounted) return;
      if (draft != null) {
        setState(() => _draftId = draft.id);
        await tripProvider.loadDrafts(refresh: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved'),
            backgroundColor: Colors.green,
          ),
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
      setState(() {
        _customerNameController.text = customer.name;
      });
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, authChild) {
        final permissionService = PermissionService(authProvider);
        
        // Check permission - redirect if unauthorized
        if (!permissionService.hasPermission('createTrips') && !permissionService.isTransporter) {
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
            appBar: AppBar(title: const Text(AppCopy.newTrip)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppCopy.newTrip),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Trip Type Dropdown
                _buildTripTypeDropdown(textTheme),
                const SizedBox(height: 20.0),

                // Assignments (Container + Vehicle + Driver per entry)
                _buildAssignmentsSection(textTheme),
                const SizedBox(height: 20.0),

                // Operational locations
                TripOperationalLocationFields(
                  tripType: _selectedTripType,
                  controllers: _locations.controllers,
                  onPick: _openLocationPicker,
                  validator: (point) {
                    if (_locations.locationForPoint(point) == null) {
                      return '${TripOperationalLocations.labelForPoint(_selectedTripType, point)} is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // Customer Name
                _buildCustomerNameField(textTheme),
                const SizedBox(height: 20.0),

                // Trip Reference (Optional)
                _buildTripReferenceField(textTheme),
                const SizedBox(height: 32.0),

                _buildSaveDraftButton(textTheme),
                const SizedBox(height: 12.0),

                // Create Trip Button
                _buildCreateTripButton(textTheme),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildTripTypeDropdown(TextTheme textTheme) {
    return DropdownButtonFormField<String>(
      value: _selectedTripType,
      decoration: const InputDecoration(
        labelText: 'Trip Type',
        hintText: 'Select trip type',
      ),
      items: const [
        DropdownMenuItem(value: AppConstants.tripTypeImport, child: Text('Import')),
        DropdownMenuItem(value: AppConstants.tripTypeExport, child: Text('Export')),
        DropdownMenuItem(value: AppConstants.tripTypeLocal, child: Text('Local')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedTripType = value;
          _locations.onTripTypeChanged(value);
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a trip type';
        }
        return null;
      },
    );
  }

  Widget _buildAssignmentsSection(TextTheme textTheme) {
    final accordionMode = _assignments.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Containers, Vehicles & Drivers',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          'Add at least one container with vehicle and driver. One container = one vehicle = one driver.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12.0),
        ...List.generate(_assignments.length, (index) {
          final entry = _assignments[index];
          final isExpanded = !accordionMode || _expandedAssignmentIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: KeyedSubtree(
              key: _assignmentCardKeys.putIfAbsent(index, () => GlobalKey()),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: BorderSide(
                    color: isExpanded && accordionMode
                        ? AppColors.primary
                        : AppColors.dividerGrey,
                    width: isExpanded && accordionMode ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAssignmentHeader(
                        index: index,
                        entry: entry,
                        textTheme: textTheme,
                        isExpanded: isExpanded,
                        accordionMode: accordionMode,
                        onExpand: accordionMode && !isExpanded
                            ? () => setState(
                                  () => _expandedAssignmentIndex = index,
                                )
                            : null,
                      ),
                      Visibility(
                        visible: isExpanded,
                        maintainState: true,
                        maintainAnimation: true,
                        child: _buildAssignmentFields(
                          entry: entry,
                          textTheme: textTheme,
                          assignmentIndex: index,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8.0),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addAssignment,
            icon: const Icon(Icons.add),
            label: const Text('Add Container / Vehicle / Driver'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentHeader({
    required int index,
    required _AssignmentEntry entry,
    required TextTheme textTheme,
    required bool isExpanded,
    required bool accordionMode,
    required VoidCallback? onExpand,
  }) {
    final complete = _isAssignmentComplete(entry);

    final title = Text(
      'Entry ${index + 1}',
      style: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );

    final removeButton = _assignments.length > 1
        ? IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: AppColors.error,
              size: 22.0,
            ),
            onPressed: () => _removeAssignment(index),
            tooltip: 'Remove',
          )
        : null;

    if (!accordionMode) {
      return Row(
        children: [
          title,
          const Spacer(),
          if (removeButton != null) removeButton,
        ],
      );
    }

    return InkWell(
      onTap: onExpand,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (complete)
                      const Padding(
                        padding: EdgeInsets.only(right: 4.0),
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 20.0,
                        ),
                      ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more,
                        color: AppColors.textSecondary,
                        size: 24.0,
                      ),
                    ),
                    if (removeButton != null)
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.error,
                          size: 22.0,
                        ),
                        onPressed: () => _removeAssignment(index),
                        tooltip: 'Remove',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40.0,
                          minHeight: 40.0,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
            if (!isExpanded) ...[
              const SizedBox(height: 4.0),
              Text(
                _assignmentSummary(entry),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentFields({
    required _AssignmentEntry entry,
    required TextTheme textTheme,
    required int assignmentIndex,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12.0),
        _buildContainerNumberField(
          entry,
          textTheme,
          focusNode: entry.containerFocusNode,
        ),
        const SizedBox(height: 12.0),
        InkWell(
          onTap: () async {
            final v = await _selectVehicleForAssignment(
              context,
              assignmentIndex: assignmentIndex,
            );
            if (v == null || !mounted) return;
            final drivers = context.read<DriverProvider>().drivers;
            final linked = resolveDriverForVehicle(v, drivers);
            setState(() {
              entry.vehicle = v;
              entry.driver = linked;
            });
            if (linked == null &&
                v.driverId != null &&
                v.driverId!.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Assigned driver is inactive or unavailable. Please select a driver manually.',
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.dividerGrey),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, color: AppColors.primary),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    entry.vehicle != null
                        ? '${entry.vehicle!.vehicleNumber} (${entry.vehicle!.ownerType})'
                        : 'Select vehicle',
                    style: textTheme.bodyMedium?.copyWith(
                      color: entry.vehicle != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                const Icon(Icons.search, color: AppColors.textSecondary, size: 20.0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        InkWell(
          onTap: () async {
            final d = await _selectDriverForAssignment(
              context,
              assignmentIndex: assignmentIndex,
            );
            if (d != null) setState(() => entry.driver = d);
          },
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.dividerGrey),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    entry.driver != null
                        ? '${entry.driver!.name ?? 'Driver'} (${entry.driver!.mobile})'
                        : 'Select driver',
                    style: textTheme.bodyMedium?.copyWith(
                      color: entry.driver != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                const Icon(Icons.search, color: AppColors.textSecondary, size: 20.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContainerNumberField(
    _AssignmentEntry entry,
    TextTheme textTheme, {
    FocusNode? focusNode,
  }) {
    final feedback = Validators.containerNumberLiveFeedback(
      entry.containerController.text,
    );
    final guideColor = switch (feedback.status) {
      ContainerNumberInputStatus.valid => AppColors.success,
      ContainerNumberInputStatus.invalid => AppColors.error,
      ContainerNumberInputStatus.typing => AppColors.info,
      ContainerNumberInputStatus.empty => AppColors.textSecondary,
    };
    final suffixIcon = switch (feedback.status) {
      ContainerNumberInputStatus.valid => const Icon(
          Icons.check_circle,
          color: AppColors.success,
        ),
      ContainerNumberInputStatus.invalid => const Icon(
          Icons.error_outline,
          color: AppColors.error,
        ),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: entry.containerController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(11),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: AppCopy.containerOptional,
            hintText: 'ABCD1234567',
            prefixIcon: const Icon(Icons.inventory_2_outlined),
            suffixIcon: suffixIcon,
            helperText: feedback.message,
            helperStyle: textTheme.bodySmall?.copyWith(
              color: guideColor,
              height: 1.35,
            ),
            helperMaxLines: 2,
          ),
        ),
      ],
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
              validator: (v) =>
                  Validators.validateRequired(v?.trim(), 'Customer'),
              decoration: const InputDecoration(
                labelText: 'Customer *',
                hintText: 'Search or enter customer name',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            if (_customerFocusNode.hasFocus && suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4.0),
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dividerGrey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = suggestions[index];
                    return ListTile(
                      dense: true,
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
        hintText: 'Enter trip reference',
      ),
      maxLines: 2,
    );
  }

  Widget _buildSaveDraftButton(TextTheme textTheme) {
    return SizedBox(
      height: 52.0,
      child: OutlinedButton(
        onPressed: (_isLoading || _isSavingDraft) ? null : _handleSaveDraft,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: _isSavingDraft
            ? const SizedBox(
                height: 20.0,
                width: 20.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              )
            : Text(
                AppCopy.saveDraft,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildCreateTripButton(TextTheme textTheme) {
    return SizedBox(
      height: 52.0,
      child: ElevatedButton(
        onPressed: _canCreateTrip ? _handleCreateTrip : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          disabledForegroundColor: AppColors.background.withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20.0,
                width: 20.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.background,
                  ),
                ),
              )
            : Text(
                AppCopy.newTrip,
                style: textTheme.labelLarge?.copyWith(
                  color: _canCreateTrip
                      ? AppColors.background
                      : AppColors.background.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
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
                                backgroundColor: AppColors.primary.withOpacity(0.1),
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
                                Icons.inventory_2,
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

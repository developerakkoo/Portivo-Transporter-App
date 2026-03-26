import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/models/trip_model.dart';
import '../data/models/vehicle_model.dart';
import '../data/models/driver_model.dart';
import '../providers/trip_provider.dart';
import 'location_picker_screen.dart';
import '../providers/vehicle_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _AssignmentEntry {
  final TextEditingController containerController;
  VehicleModel? vehicle;
  DriverModel? driver;
  _AssignmentEntry()
      : containerController = TextEditingController();
  void dispose() => containerController.dispose();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedTripType;
  final List<_AssignmentEntry> _assignments = [];
  final _pickupLocationController = TextEditingController();
  final _dropLocationController = TextEditingController();
  final _tripReferenceController = TextEditingController();
  final _customerNameController = TextEditingController();
  TripLocation? _pickupLocation;
  TripLocation? _dropLocation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _assignments.add(_AssignmentEntry());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().loadVehicles(status: 'active');
      context.read<DriverProvider>().loadDrivers();
    });
  }

  @override
  void dispose() {
    for (final e in _assignments) {
      e.dispose();
    }
    _pickupLocationController.dispose();
    _dropLocationController.dispose();
    _tripReferenceController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  void _addAssignment() {
    setState(() => _assignments.add(_AssignmentEntry()));
  }

  void _removeAssignment(int index) {
    if (_assignments.length <= 1) return;
    setState(() {
      _assignments[index].dispose();
      _assignments.removeAt(index);
    });
  }

  Future<VehicleModel?> _selectVehicleForAssignment(BuildContext context) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicles = vehicleProvider.vehicles;
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicles available')),
      );
      return null;
    }
    return showDialog<VehicleModel>(
      context: context,
      builder: (context) => _VehiclePickerDialog(vehicles: vehicles),
    );
  }

  Future<DriverModel?> _selectDriverForAssignment(BuildContext context) async {
    final driverProvider = context.read<DriverProvider>();
    final drivers = driverProvider.drivers
        .where((d) => d.status == AppConstants.driverStatusActive)
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


  Future<void> _openLocationPicker(bool isPickup) async {
    final result = await Navigator.push<TripLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          isPickup: isPickup,
          nationalSearch: true,
          initialQuery: isPickup
              ? _pickupLocation?.address
              : _dropLocation?.address,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isPickup) {
          _pickupLocation = result;
          _pickupLocationController.text = result.address ?? '';
        } else {
          _dropLocation = result;
          _dropLocationController.text = result.address ?? '';
        }
      });
    }
  }

  bool get _canCreateTrip {
    return _selectedTripType != null &&
        _pickupLocation != null &&
        _dropLocation != null &&
        !_isLoading;
  }

  Future<void> _handleCreateTrip() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_canCreateTrip) return;

      final assignmentsList = <Map<String, dynamic>>[];
      for (final e in _assignments) {
        final cn = e.containerController.text.trim().toUpperCase();
        if (cn.isEmpty || e.vehicle == null || e.driver == null) continue;
        assignmentsList.add({
          'containerNumber': cn,
          'vehicleId': e.vehicle!.id,
          'driverId': e.driver!.id,
        });
      }

      if (assignmentsList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one container with vehicle and driver assigned'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final tripProvider = Provider.of<TripProvider>(context, listen: false);

        final tripData = <String, dynamic>{
          'reference': _tripReferenceController.text.trim().isNotEmpty
              ? _tripReferenceController.text.trim().toUpperCase()
              : null,
          'customerName': _customerNameController.text.trim().isNotEmpty
              ? _customerNameController.text.trim().toUpperCase()
              : null,
          'pickupLocation': _pickupLocation!.toJson(),
          'dropLocation': _dropLocation!.toJson(),
          'tripType': _selectedTripType!.toUpperCase(),
        };

        tripData['assignments'] = assignmentsList;

        final trip = await tripProvider.createTrip(tripData);

        if (mounted) {
          if (trip != null) {
            final message = assignmentsList.isNotEmpty
                ? 'Trip created successfully with ${assignmentsList.length} container(s)'
                : 'Trip created successfully. Assign container, vehicle and driver for each entry.';
            
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
              ),
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
            appBar: AppBar(title: const Text('Create Trip')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Trip'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Trip Type Dropdown
                _buildTripTypeDropdown(textTheme),
                const SizedBox(height: 20.0),

                // Assignments (Container + Vehicle + Driver per entry)
                _buildAssignmentsSection(textTheme),
                const SizedBox(height: 20.0),

                // Customer Name
                _buildCustomerNameField(textTheme),
                const SizedBox(height: 20.0),

                // Pickup Location
                _buildPickupLocationField(textTheme),
                const SizedBox(height: 20.0),

                // Drop Location
                _buildDropLocationField(textTheme),
                const SizedBox(height: 20.0),

                // Trip Reference (Optional)
                _buildTripReferenceField(textTheme),
                const SizedBox(height: 32.0),

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
      ],
      onChanged: (value) {
        setState(() {
          _selectedTripType = value;
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
          final e = _assignments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: const BorderSide(color: AppColors.dividerGrey, width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Entry ${index + 1}',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        if (_assignments.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 22.0),
                            onPressed: () => _removeAssignment(index),
                            tooltip: 'Remove',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    TextFormField(
                      controller: e.containerController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Container Number',
                        hintText: 'Enter container number',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    InkWell(
                      onTap: () async {
                        final v = await _selectVehicleForAssignment(context);
                        if (v != null) setState(() => e.vehicle = v);
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
                                e.vehicle != null
                                    ? '${e.vehicle!.vehicleNumber} (${e.vehicle!.ownerType})'
                                    : 'Select vehicle',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: e.vehicle != null ? AppColors.textPrimary : AppColors.textMuted,
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
                        final d = await _selectDriverForAssignment(context);
                        if (d != null) setState(() => e.driver = d);
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
                                e.driver != null
                                    ? '${e.driver!.name ?? 'Driver'} (${e.driver!.mobile})'
                                    : 'Select driver',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: e.driver != null ? AppColors.textPrimary : AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Icon(Icons.search, color: AppColors.textSecondary, size: 20.0),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildCustomerNameField(TextTheme textTheme) {
    return TextFormField(
      controller: _customerNameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Customer Name (Optional)',
        hintText: 'Enter customer name',
        prefixIcon: Icon(Icons.business_outlined),
      ),
    );
  }

  Widget _buildPickupLocationField(TextTheme textTheme) {
    return InkWell(
      onTap: () => _openLocationPicker(true),
      borderRadius: BorderRadius.circular(12.0),
      child: AbsorbPointer(
        child: TextFormField(
          controller: _pickupLocationController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Pickup Location',
            hintText: 'Tap to search and select location',
            prefixIcon: Icon(Icons.location_on_outlined),
            suffixIcon: Icon(Icons.search),
          ),
          validator: (v) =>
              _pickupLocation == null ? 'Please select pickup location' : null,
        ),
      ),
    );
  }

  Widget _buildDropLocationField(TextTheme textTheme) {
    return InkWell(
      onTap: () => _openLocationPicker(false),
      borderRadius: BorderRadius.circular(12.0),
      child: AbsorbPointer(
        child: TextFormField(
          controller: _dropLocationController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Drop Location',
            hintText: 'Tap to search and select location',
            prefixIcon: Icon(Icons.location_on),
            suffixIcon: Icon(Icons.search),
          ),
          validator: (v) =>
              _dropLocation == null ? 'Please select drop location' : null,
        ),
      ),
    );
  }


  Widget _buildTripReferenceField(TextTheme textTheme) {
    return TextFormField(
      controller: _tripReferenceController,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Trip Reference (Optional)',
        hintText: 'Enter trip reference',
      ),
      maxLines: 2,
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
                'Create Trip',
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
                      child: Text('No drivers available'),
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

  const _VehiclePickerDialog({required this.vehicles});

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
                      child: Text('No vehicles available'),
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
                                '${vehicle.ownerType}${vehicle.trailerType != null ? ' • ${vehicle.trailerType}' : ''}',
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

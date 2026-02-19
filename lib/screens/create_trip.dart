import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/models/vehicle_model.dart';
import '../data/models/driver_model.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedTripType;
  VehicleModel? _selectedVehicle;
  DriverModel? _selectedDriver;
  final _pickupLocationController = TextEditingController();
  final _dropLocationController = TextEditingController();
  final _containerNumberController = TextEditingController();
  final _tripReferenceController = TextEditingController();
  bool _isLoading = false;
  
  // Dummy coordinates for Mumbai (pickup) and Pune (drop)
  static const double _dummyPickupLat = 19.0760;
  static const double _dummyPickupLng = 72.8777;
  static const double _dummyDropLat = 18.5204;
  static const double _dummyDropLng = 73.8567;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().loadVehicles(status: 'active');
      context.read<DriverProvider>().loadDrivers();
    });
  }

  @override
  void dispose() {
    _pickupLocationController.dispose();
    _dropLocationController.dispose();
    _tripReferenceController.dispose();
    _containerNumberController.dispose();
    super.dispose();
  }


  void _setDummyLocation(bool isPickup) {
    setState(() {
      if (isPickup) {
        _pickupLocationController.text = 'Port Mumbai (Dummy Location)';
      } else {
        _dropLocationController.text = 'Factory Pune (Dummy Location)';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPickup 
          ? 'Using dummy pickup location (Mumbai Port)' 
          : 'Using dummy drop location (Pune Factory)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDriver(BuildContext context) async {
    final driverProvider = context.read<DriverProvider>();
    final drivers = driverProvider.drivers;
    
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No drivers available')),
      );
      return;
    }

    final selectedDriver = await showDialog<DriverModel>(
      context: context,
      builder: (context) => _DriverPickerDialog(drivers: drivers),
    );

    if (selectedDriver != null) {
      setState(() {
        _selectedDriver = selectedDriver;
      });
    }
  }

  Future<void> _selectVehicle(BuildContext context) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicles = vehicleProvider.vehicles;
    
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicles available')),
      );
      return;
    }

    final selectedVehicle = await showDialog<VehicleModel>(
      context: context,
      builder: (context) => _VehiclePickerDialog(vehicles: vehicles),
    );

    if (selectedVehicle != null) {
      setState(() {
        _selectedVehicle = selectedVehicle;
      });
    }
  }


  bool get _canCreateTrip {
    return _selectedTripType != null &&
        !_isLoading;
  }

  Future<void> _handleCreateTrip() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_canCreateTrip) return;

      setState(() {
        _isLoading = true;
      });

      try {
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        
        // Use dummy coordinates - Mumbai for pickup, Pune for drop
        final tripData = {
          if (_selectedVehicle != null) 'vehicleId': _selectedVehicle!.id,
          if (_selectedDriver != null) 'driverId': _selectedDriver!.id,
          'containerNumber': _containerNumberController.text.trim().isNotEmpty
              ? _containerNumberController.text.trim().toUpperCase()
              : null,
          'reference': _tripReferenceController.text.trim().isNotEmpty
              ? _tripReferenceController.text.trim()
              : null,
          'pickupLocation': {
            'address': _pickupLocationController.text.trim().isNotEmpty
                ? _pickupLocationController.text.trim()
                : 'Port Mumbai',
            'coordinates': {
              'latitude': _dummyPickupLat,
              'longitude': _dummyPickupLng,
            },
          },
          'dropLocation': {
            'address': _dropLocationController.text.trim().isNotEmpty
                ? _dropLocationController.text.trim()
                : 'Factory Pune',
            'coordinates': {
              'latitude': _dummyDropLat,
              'longitude': _dummyDropLng,
            },
          },
          'tripType': _selectedTripType!.toUpperCase(),
        };

        final trip = await tripProvider.createTrip(tripData);

        if (mounted) {
          if (trip != null) {
            final hasVehicle = _selectedVehicle != null;
            final hasDriver = _selectedDriver != null;
            final message = hasVehicle && hasDriver
                ? 'Trip created successfully'
                : 'Trip created successfully. ${!hasVehicle ? "Vehicle" : ""}${!hasVehicle && !hasDriver ? " and " : ""}${!hasDriver ? "Driver" : ""} can be assigned later.';
            
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

                // Container Number
                _buildContainerNumberField(textTheme),
                const SizedBox(height: 20.0),

                // Select Vehicle
                _buildVehicleSelector(textTheme),
                const SizedBox(height: 20.0),

                // Select Driver
                _buildDriverSelector(textTheme),
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

  Widget _buildContainerNumberField(TextTheme textTheme) {
    return TextFormField(
      controller: _containerNumberController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Container Number (Optional)',
        hintText: 'Enter container number',
        prefixIcon: Icon(Icons.inventory_2_outlined),
      ),
    );
  }

  Widget _buildVehicleSelector(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Vehicle (Optional)',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        if (_selectedVehicle != null)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: AppColors.dividerGrey,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: AppColors.primary),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedVehicle!.vehicleNumber,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_selectedVehicle!.trailerType != null)
                        Text(
                          _selectedVehicle!.trailerType!,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20.0),
                  onPressed: () {
                    setState(() {
                      _selectedVehicle = null;
                    });
                  },
                ),
              ],
            ),
          )
        else
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, child) {
              if (vehicleProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final vehicles = vehicleProvider.vehicles;
              return DropdownButtonFormField<VehicleModel>(
                decoration: const InputDecoration(
                  labelText: 'Vehicle (Optional)',
                  hintText: 'Select vehicle or assign later',
                ),
                items: vehicles.map((vehicle) {
                  return DropdownMenuItem<VehicleModel>(
                    value: vehicle,
                    child: Text('${vehicle.vehicleNumber} (${vehicle.ownerType})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVehicle = value;
                  });
                },
              );
            },
          ),
        const SizedBox(height: 12.0),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _selectVehicle(context),
            icon: const Icon(Icons.search),
            label: const Text('Search Vehicle'),
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

  Widget _buildDriverSelector(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Driver (Optional)',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        InkWell(
          onTap: () => _selectDriver(context),
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: AppColors.dividerGrey,
                width: 1.0,
              ),
            ),
            child: Consumer<DriverProvider>(
              builder: (context, driverProvider, child) {
                if (driverProvider.isLoading) {
                  return const Row(
                    children: [
                      Icon(Icons.person, color: AppColors.primary),
                      SizedBox(width: 12.0),
                      Expanded(child: Text('Loading drivers...')),
                    ],
                  );
                }
                return Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.primary),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        _selectedDriver != null
                            ? '${_selectedDriver!.name ?? 'Driver'} (${_selectedDriver!.mobile})'
                            : 'Select driver (optional)',
                        style: textTheme.bodyMedium?.copyWith(
                          color: _selectedDriver != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: _selectedDriver != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_selectedDriver != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20.0),
                        onPressed: () {
                          setState(() {
                            _selectedDriver = null;
                          });
                        },
                      )
                    else
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupLocationField(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _pickupLocationController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Pickup Location',
            hintText: 'Enter pickup location',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () => _setDummyLocation(true),
              tooltip: 'Set dummy location (Mumbai)',
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Dummy Location: $_dummyPickupLat, $_dummyPickupLng (Mumbai Port)',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropLocationField(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _dropLocationController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Drop Location',
            hintText: 'Enter drop location',
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () => _setDummyLocation(false),
              tooltip: 'Set dummy location (Pune)',
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Dummy Location: $_dummyDropLat, $_dummyDropLng (Pune Factory)',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildTripReferenceField(TextTheme textTheme) {
    return TextFormField(
      controller: _tripReferenceController,
      textInputAction: TextInputAction.done,
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

// Driver Picker Dialog
class _DriverPickerDialog extends StatelessWidget {
  final List<DriverModel> drivers;

  const _DriverPickerDialog({required this.drivers});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            const Divider(height: 1),
            Flexible(
              child: drivers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No drivers available'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: drivers.length,
                      itemBuilder: (context, index) {
                        final driver = drivers[index];
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

// Vehicle Picker Dialog
class _VehiclePickerDialog extends StatelessWidget {
  final List<VehicleModel> vehicles;

  const _VehiclePickerDialog({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            const Divider(height: 1),
            Flexible(
              child: vehicles.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No vehicles available'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = vehicles[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.directions_car,
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

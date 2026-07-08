import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/user_feedback.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';

class AddEditVehicleScreen extends StatefulWidget {
  final String? vehicleId;
  const AddEditVehicleScreen({super.key, this.vehicleId});

  @override
  State<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends State<AddEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  
  String? _vehicleId;
  String _ownerType = 'OWN';
  String? _trailerType;
  String? _selectedVehicleType;
  String? _selectedDriverId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.vehicleId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vehicleId != null) {
        _loadVehicle();
      }
      if (mounted) {
        context.read<DriverProvider>().loadDrivers();
        context.read<VehicleTypeProvider>().ensureLoaded(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    if (_vehicleId == null) return;

    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = await vehicleProvider.getVehicleById(_vehicleId!);
    
    if (vehicle != null && mounted) {
      setState(() {
        _vehicleNumberController.text = vehicle.vehicleNumber;
        _ownerType = vehicle.ownerType;
        _trailerType = vehicle.trailerType;
        _selectedVehicleType = vehicle.vehicleType;
        _selectedDriverId = vehicle.driverId;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_selectedVehicleType == null || _selectedVehicleType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final vehicleProvider = context.read<VehicleProvider>();
        
        final vehicleData = {
          'vehicleNumber':
              Validators.normalizeIndianVehicleRegistration(
                  _vehicleNumberController.text),
          'ownerType': _ownerType,
          'vehicleType': _selectedVehicleType,
          if (_trailerType != null && _trailerType!.isNotEmpty) 'trailerType': _trailerType,
          if (_selectedDriverId != null) 'driverId': _selectedDriverId,
        };

        bool success;
        if (_vehicleId != null) {
          success = await vehicleProvider.updateVehicle(_vehicleId!, vehicleData);
        } else {
          final vehicle = await vehicleProvider.createVehicle(vehicleData);
          success = vehicle != null;
        }

        if (mounted) {
          if (success) {
            showUserSuccessSnackBar(
              context,
              _vehicleId != null
                  ? 'Vehicle updated successfully'
                  : 'Vehicle created successfully',
            );
            Navigator.of(context).pop();
          } else {
            showUserErrorSnackBar(
              context,
              vehicleProvider.error,
              fallback: 'Failed to ${_vehicleId != null ? 'update' : 'create'} vehicle',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          showUserErrorSnackBar(
            context,
            e,
            fallback: 'Failed to ${_vehicleId != null ? 'update' : 'create'} vehicle',
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
    final isEditMode = _vehicleId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Vehicle' : 'Add Vehicle'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vehicle Number
                TextFormField(
                  controller: _vehicleNumberController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                    hintText: 'e.g. MH12AB3434 (9-10 characters)',
                  ),
                  validator: Validators.validateVehicleNumber,
                ),
                const SizedBox(height: 20.0),

                // Owner Type
                DropdownButtonFormField<String>(
                  value: _ownerType,
                  decoration: const InputDecoration(
                    labelText: 'Owner Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'OWN', child: Text('Own')),
                    DropdownMenuItem(value: 'HIRED', child: Text('Hired')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _ownerType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20.0),

                SearchableVehicleTypePicker(
                  value: _selectedVehicleType,
                  onChanged: (value) {
                    setState(() => _selectedVehicleType = value);
                  },
                ),
                const SizedBox(height: 20.0),

                // Trailer notes (optional physical label)
                TextFormField(
                  initialValue: _trailerType,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Trailer Notes (Optional)',
                    hintText: 'Physical trailer label or sub-type',
                  ),
                  onChanged: (value) {
                    _trailerType = value.trim().isEmpty ? null : value.trim();
                  },
                ),
                const SizedBox(height: 20.0),

                // Driver Selection
                Consumer<DriverProvider>(
                  builder: (context, driverProvider, child) {
                    final drivers = driverProvider.drivers
                        .where((d) => d.status == AppConstants.driverStatusActive)
                        .toList();
                    
                    return DropdownButtonFormField<String>(
                      value: _selectedDriverId,
                      decoration: const InputDecoration(
                        labelText: 'Assign Driver (Optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No driver assigned'),
                        ),
                        ...drivers.map((driver) {
                          return DropdownMenuItem<String>(
                            value: driver.id,
                            child: Text('${driver.name ?? 'Driver'} (${driver.mobile})'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDriverId = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 32.0),

                // Save Button
                SizedBox(
                  height: 52.0,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20.0,
                            width: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
                            ),
                          )
                        : Text(
                            isEditMode ? 'Update Vehicle' : 'Create Vehicle',
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.background,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

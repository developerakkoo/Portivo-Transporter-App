import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/user_feedback.dart';
import '../../core/utils/validators.dart';
import '../../data/models/rc_verification.dart';
import '../../core/utils/vehicle_create_payload.dart';
import '../../data/models/driver_already_assigned_exception.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../widgets/driver_reassign_dialog.dart';
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
  final _cargoWeightController = TextEditingController();
  
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
    _cargoWeightController.dispose();
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
        _cargoWeightController.text = vehicle.cargoWeightMt == null
            ? ''
            : (vehicle.cargoWeightMt! % 1 == 0
                ? vehicle.cargoWeightMt!.toInt().toString()
                : vehicle.cargoWeightMt!.toString());
      });
    }
  }

  Future<({bool success, RcVerification? rc})> _submitVehicle(
    VehicleProvider vehicleProvider,
    Map<String, dynamic> vehicleData, {
    bool forceReassign = false,
  }) async {
    final payload = Map<String, dynamic>.from(vehicleData);
    if (forceReassign) payload['forceReassign'] = true;
    try {
      if (_vehicleId != null) {
        final updated = await vehicleProvider.updateVehicle(_vehicleId!, payload);
        return (success: updated, rc: null);
      }
      final created = await vehicleProvider.createVehicle(payload);
      return (success: created != null, rc: created?.verification);
    } on DriverAlreadyAssignedException catch (conflict) {
      if (!mounted) return (success: false, rc: null);
      setState(() => _isLoading = false);
      final move = await showDriverReassignDialog(
        context: context,
        conflict: conflict,
        newVehicleNumber: payload['vehicleNumber']?.toString() ?? '',
      );
      if (!move || !mounted) return (success: false, rc: null);
      setState(() => _isLoading = true);
      return _submitVehicle(vehicleProvider, vehicleData, forceReassign: true);
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
        
        final cargo = Validators.parseOptionalCargoWeightMt(
          _cargoWeightController.text,
        );
        Map<String, dynamic> vehicleData;
        if (_vehicleId != null) {
          vehicleData = {
            'vehicleNumber':
                Validators.normalizeIndianVehicleRegistration(
                    _vehicleNumberController.text),
            'ownerType': _ownerType,
            'vehicleType': _selectedVehicleType,
            if (_trailerType != null && _trailerType!.isNotEmpty)
              'trailerType': _trailerType,
            if (_selectedDriverId != null) 'driverId': _selectedDriverId,
            'cargoWeightMt': cargo,
          };
        } else if (_selectedDriverId != null && _selectedDriverId!.isNotEmpty) {
          vehicleData = buildVehicleCreatePayload(
            vehicleNumber: Validators.normalizeIndianVehicleRegistration(
                _vehicleNumberController.text),
            vehicleType: _selectedVehicleType!,
            driverId: _selectedDriverId!,
            ownerType: _ownerType,
            cargoWeightMt: cargo,
            trailerType: _trailerType,
          );
        } else {
          vehicleData = {
            'vehicleNumber':
                Validators.normalizeIndianVehicleRegistration(
                    _vehicleNumberController.text),
            'ownerType': _ownerType,
            'vehicleType': _selectedVehicleType,
            if (_trailerType != null && _trailerType!.isNotEmpty)
              'trailerType': _trailerType,
            if (cargo != null) 'cargoWeightMt': cargo,
          };
        }

        final outcome = await _submitVehicle(vehicleProvider, vehicleData);

        if (mounted) {
          if (outcome.success) {
            final created = _vehicleId == null;
            final warning = created && outcome.rc != null && !outcome.rc!.isVerified
                ? rcStatusLabel(outcome.rc!.status)
                : null;
            final base = created
                ? 'Vehicle created successfully'
                : 'Vehicle updated successfully';
            showUserSuccessSnackBar(
              context,
              warning == null ? base : '$base. ${warning.replaceFirst('Vehicle saved. ', '')}',
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

                TextFormField(
                  controller: _cargoWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Cargo Weight (MT)',
                    hintText: 'Optional',
                    suffixText: 'MT',
                  ),
                  validator: Validators.validateOptionalCargoWeightMt,
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

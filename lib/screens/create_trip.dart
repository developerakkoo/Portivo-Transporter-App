import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../core/theme/app_colors.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedTripType;
  Map<String, String>? _selectedVehicle;
  Contact? _selectedDriver;
  final _pickupLocationController = TextEditingController();
  final _dropLocationController = TextEditingController();
  Map<String, String>? _selectedCustomer;
  final _tripReferenceController = TextEditingController();
  bool _isLoading = false;

  // Placeholder recent vehicles
  final List<Map<String, String>> _recentVehicles = [
    {'number': 'ABC-1234', 'type': 'Truck', 'model': 'Mercedes Actros'},
    {'number': 'XYZ-5678', 'type': 'Van', 'model': 'Ford Transit'},
    {'number': 'DEF-9012', 'type': 'Truck', 'model': 'Volvo FH16'},
  ];

  @override
  void dispose() {
    _pickupLocationController.dispose();
    _dropLocationController.dispose();
    _tripReferenceController.dispose();
    super.dispose();
  }

  Future<void> _selectDriverFromContacts() async {
    try {
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission is required'),
            ),
          );
        }
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      if (!mounted) return;

      final selectedContact = await showDialog<Contact>(
        context: context,
        builder: (context) => _ContactsPickerDialog(contacts: contacts),
      );

      if (selectedContact != null) {
        setState(() {
          _selectedDriver = selectedContact;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing contacts: $e'),
          ),
        );
      }
    }
  }

  Future<void> _selectVehicle() async {
    final vehicle = await Navigator.of(context).pushNamed('/search-vehicle');
    if (vehicle != null && vehicle is Map<String, String>) {
      setState(() {
        _selectedVehicle = vehicle;
      });
    }
  }

  Future<void> _selectCustomer() async {
    final customer = await Navigator.of(context).pushNamed('/search-customer');
    if (customer != null && customer is Map<String, String>) {
      setState(() {
        _selectedCustomer = customer;
      });
    }
  }

  bool get _canCreateTrip {
    return _selectedTripType != null &&
        _selectedVehicle != null &&
        _selectedDriver != null &&
        _pickupLocationController.text.isNotEmpty &&
        _dropLocationController.text.isNotEmpty &&
        _selectedCustomer != null &&
        !_isLoading;
  }

  void _handleCreateTrip() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_canCreateTrip) return;

      setState(() {
        _isLoading = true;
      });

      // TODO: Implement actual trip creation logic
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip created successfully'),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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

                // Customer Name
                _buildCustomerSelector(textTheme),
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
  }

  Widget _buildTripTypeDropdown(TextTheme textTheme) {
    return DropdownButtonFormField<String>(
      value: _selectedTripType,
      decoration: const InputDecoration(
        labelText: 'Trip Type',
        hintText: 'Select trip type',
      ),
      items: const [
        DropdownMenuItem(value: 'Import', child: Text('Import')),
        DropdownMenuItem(value: 'Export', child: Text('Export')),
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

  Widget _buildVehicleSelector(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Vehicle',
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
                        _selectedVehicle!['number']!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_selectedVehicle!['type']} • ${_selectedVehicle!['model']}',
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
          DropdownButtonFormField<Map<String, String>>(
            decoration: const InputDecoration(
              labelText: 'Vehicle',
              hintText: 'Select vehicle',
            ),
            items: _recentVehicles.map((vehicle) {
              return DropdownMenuItem<Map<String, String>>(
                value: vehicle,
                child: Text('${vehicle['number']} - ${vehicle['type']}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedVehicle = value;
              });
            },
          ),
        const SizedBox(height: 12.0),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _selectVehicle,
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
          'Select Driver',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        InkWell(
          onTap: _selectDriverFromContacts,
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
            child: Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    _selectedDriver != null
                        ? _selectedDriver!.displayName
                        : 'Select driver from contacts',
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
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupLocationField(TextTheme textTheme) {
    return TextFormField(
      controller: _pickupLocationController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Pickup Location',
        hintText: 'Enter pickup location',
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter pickup location';
        }
        return null;
      },
    );
  }

  Widget _buildDropLocationField(TextTheme textTheme) {
    return TextFormField(
      controller: _dropLocationController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Drop Location',
        hintText: 'Enter drop location',
        prefixIcon: Icon(Icons.location_on),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter drop location';
        }
        return null;
      },
    );
  }

  Widget _buildCustomerSelector(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Name',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        InkWell(
          onTap: _selectCustomer,
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
            child: Row(
              children: [
                const Icon(Icons.business, color: AppColors.primary),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    _selectedCustomer != null
                        ? _selectedCustomer!['name']!
                        : 'Select customer',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _selectedCustomer != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: _selectedCustomer != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                      letterSpacing: _selectedCustomer != null ? 0.5 : 0.0,
                    ),
                  ),
                ),
                if (_selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20.0),
                    onPressed: () {
                      setState(() {
                        _selectedCustomer = null;
                      });
                    },
                  )
                else
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
              ],
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

// Contacts Picker Dialog
class _ContactsPickerDialog extends StatelessWidget {
  final List<Contact> contacts;

  const _ContactsPickerDialog({required this.contacts});

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
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        contact.displayName.isNotEmpty
                            ? contact.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      contact.displayName,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: contact.phones.isNotEmpty
                        ? Text(
                            contact.phones.first.number,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(contact),
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

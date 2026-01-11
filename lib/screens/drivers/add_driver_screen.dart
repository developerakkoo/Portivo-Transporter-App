import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/driver.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DriverStatus _selectedStatus = DriverStatus.pending;
  bool _isLoading = false;
  String? _selectedContactName;
  String? _selectedContactPhone;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectFromContacts() async {
    // TODO: Implement actual contact picker
    // For now, show a dialog to simulate contact selection
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ContactPickerDialog(),
    );

    if (result != null) {
      setState(() {
        _selectedContactName = result['name'];
        _selectedContactPhone = result['phone'];
        _nameController.text = _selectedContactName ?? '';
        _phoneController.text = _selectedContactPhone ?? '';
      });
    }
  }

  void _clearContactSelection() {
    setState(() {
      _selectedContactName = null;
      _selectedContactPhone = null;
      _nameController.clear();
      _phoneController.clear();
    });
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          final newDriver = Driver(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            status: _selectedStatus,
          );

          Navigator.of(context).pop(newDriver);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Driver'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Contact Selection Section
                _buildContactSelectionSection(textTheme),

                const SizedBox(height: 24.0),

                // Name Field
                _buildNameField(),

                const SizedBox(height: 20.0),

                // Phone Field
                _buildPhoneField(),

                const SizedBox(height: 20.0),

                // Status Dropdown
                _buildStatusDropdown(),

                const SizedBox(height: 32.0),

                // Save Button
                _buildSaveButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactSelectionSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Contact',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12.0),
        if (_selectedContactName != null)
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedContactName!,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        _selectedContactPhone!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                  onPressed: _clearContactSelection,
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 52.0,
            child: OutlinedButton.icon(
              onPressed: _selectFromContacts,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Select from Contacts'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Driver Name',
        hintText: 'Enter driver name',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter driver name';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: const InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter phone number',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter phone number';
        }
        if (value.length < 10) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<DriverStatus>(
      value: _selectedStatus,
      decoration: const InputDecoration(
        labelText: 'Status',
        hintText: 'Select status',
      ),
      items: DriverStatus.values.map((status) {
        String label;
        switch (status) {
          case DriverStatus.active:
            label = 'Active';
            break;
          case DriverStatus.notInstalled:
            label = 'Not Installed';
            break;
          case DriverStatus.pending:
            label = 'Pending';
            break;
        }

        return DropdownMenuItem<DriverStatus>(
          value: status,
          child: Text(label),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedStatus = value;
          });
        }
      },
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
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
                'Save Driver',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _ContactPickerDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Simulated contacts list
    final contacts = [
      {'name': 'John Doe', 'phone': '+1234567890'},
      {'name': 'Jane Smith', 'phone': '+0987654321'},
      {'name': 'Mike Johnson', 'phone': '+1122334455'},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Contact',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
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
                      backgroundColor: AppColors.offWhite,
                      child: Text(
                        contact['name']![0],
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      contact['name']!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      contact['phone']!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(contact);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


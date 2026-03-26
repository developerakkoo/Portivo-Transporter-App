import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/company_user_model.dart';
import '../../providers/company_user_provider.dart';
import '../../widgets/pin_digit_field.dart';

enum PinSetupStep {
  enter,
  confirm,
}

class AddEditUserScreen extends StatefulWidget {
  const AddEditUserScreen({super.key});

  @override
  State<AddEditUserScreen> createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends State<AddEditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _confirmPinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );
  final List<FocusNode> _confirmFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );

  CompanyUserModel? _existingUser;
  String _mode = 'add'; // 'add', 'edit', 'set-pin'
  bool _hasAccess = true;
  Set<String> _selectedPermissions = {};
  PinSetupStep _pinStep = PinSetupStep.enter;
  bool _isLoading = false;
  String? _pinErrorMessage;
  bool _showPinSection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _mode = args['mode'] ?? 'add';
      _existingUser = args['user'] as CompanyUserModel?;
      
      if (_existingUser != null) {
        _nameController.text = _existingUser!.name;
        _phoneController.text = _existingUser!.mobile;
        _emailController.text = _existingUser!.email ?? '';
        _hasAccess = _existingUser!.hasAccess;
        _selectedPermissions = Set.from(_existingUser!.permissions);
        _showPinSection = _mode == 'set-pin' || !_existingUser!.hasPinSet();
      } else {
        _showPinSection = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var controller in _confirmPinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    for (var node in _confirmFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getPin(List<TextEditingController> controllers) {
    return controllers.map((c) => c.text).join();
  }

  bool _isPinComplete(List<TextEditingController> controllers) {
    return controllers.every((c) => c.text.isNotEmpty);
  }

  void _handlePinInput(
    String value,
    int index,
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
  ) {
    if (value.isNotEmpty) {
      if (value.length > 1) {
        controllers[index].text = value[value.length - 1];
      }
      
      if (index < 3) {
        focusNodes[index + 1].requestFocus();
      } else {
        focusNodes[index].unfocus();
        _checkPinCompletion();
      }
    }
  }

  void _checkPinCompletion() {
    if (_pinStep == PinSetupStep.enter) {
      if (_isPinComplete(_pinControllers)) {
        setState(() {
          _pinStep = PinSetupStep.confirm;
          _pinErrorMessage = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _confirmFocusNodes[0].requestFocus();
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Validate PIN if access is enabled
      String? pinToSet;
      if (_hasAccess && _showPinSection) {
        if (!_isPinComplete(_pinControllers) || !_isPinComplete(_confirmPinControllers)) {
          setState(() {
            _pinErrorMessage = 'Please complete PIN setup';
          });
          return;
        }
        
        final enteredPin = _getPin(_pinControllers);
        final confirmedPin = _getPin(_confirmPinControllers);
        
        if (enteredPin != confirmedPin) {
          setState(() {
            _pinErrorMessage = 'PINs do not match. Please try again.';
          });
          for (var controller in _confirmPinControllers) {
            controller.clear();
          }
          _confirmFocusNodes[0].requestFocus();
          return;
        }
        pinToSet = enteredPin;
      }

      // Validate permissions
      if (_selectedPermissions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one permission'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _pinErrorMessage = null;
      });

      try {
        final provider = context.read<CompanyUserProvider>();
        
        if (_mode == 'set-pin' && _existingUser != null && pinToSet != null) {
          // Just set PIN
          final success = await provider.setPin(_existingUser!.id, pinToSet);
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN set successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.error ?? 'Failed to set PIN'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else if (_existingUser != null) {
          // Update existing user
          final userData = {
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            'permissions': _selectedPermissions.toList(),
            'hasAccess': _hasAccess,
          };
          
          final success = await provider.updateUser(_existingUser!.id, userData);
          
          if (success && pinToSet != null) {
            // Set PIN separately
            await provider.setPin(_existingUser!.id, pinToSet);
          }
          
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.error ?? 'Failed to update user'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // Create new user
          final userData = {
            'mobile': _phoneController.text.trim(),
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            'permissions': _selectedPermissions.toList(),
            'hasAccess': _hasAccess,
            if (pinToSet != null) 'pin': pinToSet,
          };
          
          final user = await provider.createUser(userData);
          
          if (mounted) {
            if (user != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User created successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.error ?? 'Failed to create user'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
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

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${_existingUser?.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && _existingUser != null && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final provider = context.read<CompanyUserProvider>();
        final success = await provider.deleteUser(_existingUser!.id);
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.error ?? 'Failed to delete user'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isEditMode = _mode == 'edit' || _mode == 'set-pin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit User' : 'Add User'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Basic Information
                _buildSectionHeader(textTheme, 'Basic Information'),
                const SizedBox(height: 16.0),
                _buildNameField(),
                const SizedBox(height: 20.0),
                _buildPhoneField(),
                const SizedBox(height: 20.0),
                _buildEmailField(),

                const SizedBox(height: 32.0),

                // PIN Setup
                if (_showPinSection) ...[
                  _buildSectionHeader(textTheme, 'Set Login PIN'),
                  const SizedBox(height: 16.0),
                  _buildPinSection(),
                  if (_pinErrorMessage != null) ...[
                    const SizedBox(height: 12.0),
                    _buildPinErrorMessage(_pinErrorMessage!),
                  ],
                  const SizedBox(height: 32.0),
                ],

                // Permissions
                _buildSectionHeader(textTheme, 'Permissions'),
                const SizedBox(height: 16.0),
                _buildPermissionsSection(),

                const SizedBox(height: 32.0),

                // Access Control
                _buildSectionHeader(textTheme, 'Access Control'),
                const SizedBox(height: 16.0),
                _buildAccessControl(),

                const SizedBox(height: 32.0),

                // Save Button
                _buildSaveButton(theme),

                // Delete Button (if editing)
                if (isEditMode && _mode != 'set-pin') ...[
                  const SizedBox(height: 16.0),
                  _buildDeleteButton(textTheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(TextTheme textTheme, String title) {
    return Text(
      title,
      style: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Full Name',
        hintText: 'Enter user name',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter user name';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
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

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email (Optional)',
        hintText: 'Enter email address',
      ),
    );
  }

  Widget _buildPinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pinStep == PinSetupStep.enter)
          _buildPinInput(
            controllers: _pinControllers,
            focusNodes: _pinFocusNodes,
            label: 'Enter PIN',
          )
        else
          _buildPinInput(
            controllers: _confirmPinControllers,
            focusNodes: _confirmFocusNodes,
            label: 'Confirm PIN',
          ),
      ],
    );
  }

  Widget _buildPinInput({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return _buildPinField(
              controller: controllers[index],
              focusNode: focusNodes[index],
              index: index,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int index,
  }) {
    final isFocused = focusNode.hasFocus;
    final hasValue = controller.text.isNotEmpty;
    final controllers = _pinStep == PinSetupStep.enter
        ? _pinControllers
        : _confirmPinControllers;
    final focusNodes = _pinStep == PinSetupStep.enter
        ? _pinFocusNodes
        : _confirmFocusNodes;

    return PinDigitField(
      index: index,
      controller: controller,
      focusNode: focusNode,
      controllers: controllers,
      focusNodes: focusNodes,
      onChanged: (value) {
        setState(() {});
        _handlePinInput(
          value,
          index,
          controllers,
          focusNodes,
        );
      },
      onStateChanged: () => setState(() {}),
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: hasValue || isFocused
            ? AppColors.background
            : AppColors.offWhite,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(
            color: isFocused ? AppColors.primary : AppColors.dividerGrey,
            width: isFocused ? 2.0 : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(
            color: isFocused ? AppColors.primary : AppColors.dividerGrey,
            width: isFocused ? 2.0 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildPinErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20.0,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection() {
    final allPermissions = [
      'viewTrips',
      'createTrips',
      'manageDrivers',
      'manageVehicles',
      'manageWallet',
      'manageFuelCards',
      'manageUsers',
      'viewReports',
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select permissions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedPermissions.length == allPermissions.length) {
                    _selectedPermissions.clear();
                  } else {
                    _selectedPermissions = Set.from(allPermissions);
                  }
                });
              },
              child: Text(
                _selectedPermissions.length == allPermissions.length
                    ? 'Deselect All'
                    : 'Select All',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        ...allPermissions.map((permission) {
          return _buildPermissionCheckbox(permission);
        }),
      ],
    );
  }

  Widget _buildPermissionCheckbox(String permission) {
    final label = _getPermissionLabel(permission);
    final isSelected = _selectedPermissions.contains(permission);

    return CheckboxListTile(
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            _selectedPermissions.add(permission);
          } else {
            _selectedPermissions.remove(permission);
          }
        });
      },
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
      ),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getPermissionLabel(String permission) {
    switch (permission) {
      case 'viewTrips':
        return 'View Trips';
      case 'createTrips':
        return 'Create Trips';
      case 'manageDrivers':
        return 'Manage Drivers';
      case 'manageVehicles':
        return 'Manage Vehicles';
      case 'manageWallet':
        return 'Manage Wallet';
      case 'manageFuelCards':
        return 'Manage Fuel Cards';
      case 'manageUsers':
        return 'Manage Users';
      case 'viewReports':
        return 'View Reports';
      default:
        return permission;
    }
  }

  Widget _buildAccessControl() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: SwitchListTile(
        value: _hasAccess,
        onChanged: (value) {
          setState(() {
            _hasAccess = value;
            if (value) {
              _showPinSection = true;
            }
          });
        },
        title: Text(
          'Enable Access',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
        subtitle: Text(
          'User can login with phone and PIN',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        activeColor: AppColors.primary,
      ),
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
                _mode == 'set-pin' ? 'Save PIN' : 'Save User',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDeleteButton(TextTheme textTheme) {
    return SizedBox(
      height: 52.0,
      child: OutlinedButton(
        onPressed: _handleDelete,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: Text(
          'Delete User',
          style: textTheme.labelLarge?.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


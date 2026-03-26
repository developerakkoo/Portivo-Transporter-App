import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_digit_field.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );

  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _mobileController = TextEditingController();
  bool _isCompanyUser = false; // Toggle between transporter and company user login

  @override
  void initState() {
    super.initState();
    // Auto-focus first PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    _mobileController.dispose();
    super.dispose();
  }

  String _getPin() {
    return _pinControllers.map((c) => c.text).join();
  }

  bool _isPinComplete() {
    return _pinControllers.every((c) => c.text.isNotEmpty);
  }

  void _handlePinInput(String value, int index) {
    if (value.isNotEmpty) {
      // Only allow single digit
      if (value.length > 1) {
        _pinControllers[index].text = value[value.length - 1];
      }
      
      // Move to next field if not last
      if (index < 3) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        // Last field filled, attempt login
        _pinFocusNodes[index].unfocus();
        _handleLogin();
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_isPinComplete()) {
      setState(() {
        _errorMessage = 'Please enter your 4-digit PIN';
      });
      return;
    }

    if (_mobileController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your mobile number';
      });
      return;
    }

    final enteredPin = _getPin();
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = _isCompanyUser
        ? await authProvider.loginAsCompanyUser(
            _mobileController.text.trim(),
            enteredPin,
          )
        : await authProvider.loginWithPIN(
            _mobileController.text.trim(),
            enteredPin,
          );

    if (mounted) {
      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = authProvider.error ?? 'Invalid PIN. Please try again.';
        });
        // Clear PIN fields
        for (var controller in _pinControllers) {
          controller.clear();
        }
        _pinFocusNodes[0].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final safeAreaTop = MediaQuery.of(context).padding.top;
              final safeAreaBottom = MediaQuery.of(context).padding.bottom;
              final availableHeight = screenHeight - safeAreaTop - safeAreaBottom;
              
              final minContentHeight = 500.0;
              final extraSpacing = (availableHeight - minContentHeight).clamp(0.0, 200.0);
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40.0),

                  // Header Section
                  _buildHeader(textTheme),

                  const SizedBox(height: 32.0),

                  // User Type Toggle
                  _buildUserTypeToggle(),

                  const SizedBox(height: 24.0),

                  // Mobile Number Field
                  _buildMobileField(textTheme),

                  const SizedBox(height: 32.0),

                  // PIN Input Section
                  _buildPinInput(),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16.0),
                    _buildErrorMessage(_errorMessage!),
                  ],

                  const SizedBox(height: 32.0),

                  // Primary Action
                  _buildLoginButton(theme),

                  // Footer - flexible spacing
                  SizedBox(height: extraSpacing),
                  const SizedBox(height: 24.0),
                  _buildFooter(textTheme),
                  const SizedBox(height: 24.0),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Your PIN',
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12.0),
        Text(
          _isCompanyUser
              ? 'Enter your mobile number and 4-digit PIN to login as company user'
              : 'Enter your 4-digit PIN to continue',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isCompanyUser = false;
                  _errorMessage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: !_isCompanyUser
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Transporter',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: !_isCompanyUser
                            ? AppColors.background
                            : AppColors.textSecondary,
                        fontWeight: !_isCompanyUser
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isCompanyUser = true;
                  _errorMessage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: _isCompanyUser
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Company User',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isCompanyUser
                            ? AppColors.background
                            : AppColors.textSecondary,
                        fontWeight: _isCompanyUser
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return _buildPinField(index);
          }),
        ),
      ],
    );
  }

  Widget _buildPinField(int index) {
    final controller = _pinControllers[index];
    final focusNode = _pinFocusNodes[index];
    final isFocused = focusNode.hasFocus;
    final hasValue = controller.text.isNotEmpty;

    return PinDigitField(
      index: index,
      controller: controller,
      focusNode: focusNode,
      controllers: _pinControllers,
      focusNodes: _pinFocusNodes,
      onChanged: (value) {
        setState(() {});
        _handlePinInput(value, index);
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
            color: isFocused
                ? AppColors.primary
                : AppColors.dividerGrey,
            width: isFocused ? 2.0 : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(
            color: isFocused
                ? AppColors.primary
                : AppColors.dividerGrey,
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
      onFieldSubmitted: (_) => _handleLogin(),
    );
  }

  Widget _buildErrorMessage(String message) {
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

  Widget _buildLoginButton(ThemeData theme) {
    return SizedBox(
      height: 52.0,
      child: ElevatedButton(
        onPressed: _isPinComplete() && !_isLoading ? _handleLogin : null,
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
                'Continue',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildMobileField(TextTheme textTheme) {
    return TextFormField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Mobile Number',
        hintText: 'Enter your mobile number',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildFooter(TextTheme textTheme) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).pop();
      },
      child: Text(
        'Use email and password instead',
        style: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}


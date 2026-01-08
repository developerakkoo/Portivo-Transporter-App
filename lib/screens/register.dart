import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum PasswordStrength {
  weak,
  fair,
  good,
  strong,
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;
    
    int strength = 0;
    
    // Length check
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    
    // Character variety checks
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    if (strength <= 2) return PasswordStrength.weak;
    if (strength <= 4) return PasswordStrength.fair;
    if (strength <= 5) return PasswordStrength.good;
    return PasswordStrength.strong;
  }

  double _getPasswordStrengthProgress(String password) {
    final strength = _calculatePasswordStrength(password);
    switch (strength) {
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.fair:
        return 0.5;
      case PasswordStrength.good:
        return 0.75;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  Color _getPasswordStrengthColor(String password) {
    final strength = _calculatePasswordStrength(password);
    switch (strength) {
      case PasswordStrength.weak:
        return AppColors.error;
      case PasswordStrength.fair:
        return AppColors.warning;
      case PasswordStrength.good:
        return AppColors.info;
      case PasswordStrength.strong:
        return AppColors.success;
    }
  }

  String _getPasswordStrengthText(String password) {
    final strength = _calculatePasswordStrength(password);
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  void _handleRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
    // TODO: Implement actual registration logic
    // Simulate loading for demonstration
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Navigate to PIN setup after successful registration
        Navigator.of(context).pushReplacementNamed('/pin-setup');
      }
    });
    }
  }

  bool get _canRegister {
    return _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _companyNameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        !_isLoading;
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
              
              final minContentHeight = 800.0;
              final extraSpacing = (availableHeight - minContentHeight).clamp(0.0, 100.0);
              
              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20.0),

                    // Header Section
                    _buildHeader(textTheme),

                    const SizedBox(height: 32.0),

                    // Form Section
                    _buildFirstNameField(),
                    const SizedBox(height: 20.0),
                    _buildLastNameField(),
                    const SizedBox(height: 20.0),
                    _buildCompanyNameField(),
                    const SizedBox(height: 20.0),
                    _buildEmailField(),
                    const SizedBox(height: 20.0),
                    _buildPasswordField(),
                    const SizedBox(height: 20.0),
                    _buildPhoneField(),

                    const SizedBox(height: 32.0),

                    // Primary Action
                    _buildRegisterButton(theme),

                    // Footer - flexible spacing
                    SizedBox(height: extraSpacing),
                    const SizedBox(height: 24.0),
                    _buildFooter(textTheme),
                    const SizedBox(height: 24.0),
                  ],
                ),
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
          'Create Account',
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12.0),
        Text(
          'Please fill in your details to create an account',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'First Name',
        hintText: 'Enter your first name',
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your first name';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
      controller: _lastNameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Last Name',
        hintText: 'Enter your last name',
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your last name';
        }
        return null;
      },
    );
  }

  Widget _buildCompanyNameField() {
    return TextFormField(
      controller: _companyNameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Company Name',
        hintText: 'Enter your company name',
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your company name';
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
        labelText: 'Email',
        hintText: 'Enter your email',
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    final password = _passwordController.text;
    final strength = _calculatePasswordStrength(password);
    final showStrengthIndicator = password.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            if (strength == PasswordStrength.weak) {
              return 'Password is too weak. Please use a stronger password';
            }
            return null;
          },
        ),
        if (showStrengthIndicator) ...[
          const SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: _getPasswordStrengthProgress(password),
                    backgroundColor: AppColors.offWhite,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getPasswordStrengthColor(password),
                    ),
                    minHeight: 6.0,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Text(
                _getPasswordStrengthText(password),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getPasswordStrengthColor(password),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter your phone number',
      ),
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: (_) => _handleRegister(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        // Basic phone validation
        if (value.length < 10) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton(ThemeData theme) {
    return SizedBox(
      height: 52.0,
      child: ElevatedButton(
        onPressed: _canRegister ? _handleRegister : null,
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
                'Register',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildFooter(TextTheme textTheme) {
    return Text(
      'By creating an account, you agree to our Terms of Service and Privacy Policy',
      style: textTheme.bodySmall?.copyWith(
        color: AppColors.textMuted,
      ),
      textAlign: TextAlign.center,
    );
  }
}


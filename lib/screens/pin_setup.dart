import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';
import '../widgets/pin_digit_field.dart';

enum PinSetupStep {
  enter,
  confirm,
}

class PinSetupScreen extends StatefulWidget {
  final String? mobileNumber;
  const PinSetupScreen({super.key, this.mobileNumber});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
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

  PinSetupStep _currentStep = PinSetupStep.enter;
  bool _isLoading = false;
  String? _errorMessage;

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
      // Only allow single digit
      if (value.length > 1) {
        controllers[index].text = value[value.length - 1];
      }
      
      // Move to next field if not last
      if (index < 3) {
        focusNodes[index + 1].requestFocus();
      } else {
        // Last field filled, move to confirmation or save
        focusNodes[index].unfocus();
        _checkPinCompletion();
      }
    }
  }


  void _checkPinCompletion() {
    if (_currentStep == PinSetupStep.enter) {
      if (_isPinComplete(_pinControllers)) {
        // Move to confirmation step
        setState(() {
          _currentStep = PinSetupStep.confirm;
          _errorMessage = null;
        });
        // Auto-focus first confirmation field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _confirmFocusNodes[0].requestFocus();
        });
      }
    }
  }

  Future<void> _handleSavePin() async {
    final enteredPin = _getPin(_pinControllers);
    final confirmedPin = _getPin(_confirmPinControllers);

    if (!_isPinComplete(_confirmPinControllers)) {
      setState(() {
        _errorMessage = 'Please complete the PIN confirmation';
      });
      return;
    }

    if (enteredPin != confirmedPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
      });
      // Clear confirmation and restart
      for (var controller in _confirmPinControllers) {
        controller.clear();
      }
      _confirmFocusNodes[0].requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final success = await authService.setPin(enteredPin);
      
      // Verify token exists after PIN setup
      if (success) {
        final token = await authService.getAccessToken();
        if (kDebugMode) {
          print('PinSetupScreen: Token verification after PIN setup: ${token != null}');
        }
        if (token == null) {
          setState(() {
            _errorMessage = 'Failed to save authentication token. Please try logging in again.';
            _isLoading = false;
          });
          return;
        }
      }

      if (mounted) {
        if (success) {
          // Connect Socket.IO after PIN setup
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.user != null) {
            try {
              final socketService = SocketService();
              await socketService.connect();
              final u = authProvider.user!;
              socketService.joinTransporterRoom(u.transporterId ?? u.id);
            } catch (e) {
              // Socket.IO connection failure is non-critical
              if (kDebugMode) {
                print('PinSetupScreen: Socket.IO connection failed (non-critical): $e');
              }
            }
          }

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN set successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to home screen after PIN setup
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to set PIN. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error setting PIN: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  bool get _canSave {
    if (_currentStep == PinSetupStep.enter) {
      return _isPinComplete(_pinControllers);
    } else {
      return _isPinComplete(_confirmPinControllers);
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
          onPressed: () {
            if (_currentStep == PinSetupStep.confirm) {
              // Go back to enter PIN step
              setState(() {
                _currentStep = PinSetupStep.enter;
                _errorMessage = null;
                for (var controller in _confirmPinControllers) {
                  controller.clear();
                }
              });
              _pinFocusNodes[0].requestFocus();
            } else {
              Navigator.of(context).pop();
            }
          },
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
              
              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20.0),

                    // Header Section
                    _buildHeader(textTheme),

                    const SizedBox(height: 48.0),

                    // PIN Input Section
                    if (_currentStep == PinSetupStep.enter)
                      _buildPinInput(
                        controllers: _pinControllers,
                        focusNodes: _pinFocusNodes,
                        label: 'Enter your PIN',
                      )
                    else
                      _buildPinInput(
                        controllers: _confirmPinControllers,
                        focusNodes: _confirmFocusNodes,
                        label: 'Confirm your PIN',
                      ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16.0),
                      _buildErrorMessage(_errorMessage!),
                    ],

                    const SizedBox(height: 32.0),

                    // Primary Action
                    _buildSaveButton(theme),

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
          'Set Up Your PIN',
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12.0),
        Text(
          'Create a 4-digit PIN for quick login',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16.0),
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
    final controllers = _currentStep == PinSetupStep.enter
        ? _pinControllers
        : _confirmPinControllers;
    final focusNodes = _currentStep == PinSetupStep.enter
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
      onEditingComplete: _checkPinCompletion,
      onFieldSubmitted: (_) => _checkPinCompletion(),
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

  Widget _buildSaveButton(ThemeData theme) {
    final buttonText = _currentStep == PinSetupStep.enter
        ? 'Continue'
        : 'Save PIN';

    return SizedBox(
      height: 52.0,
      child: ElevatedButton(
        onPressed: _canSave ? _handleSavePin : null,
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
                buttonText,
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
      'Your PIN is stored securely on your device',
      style: textTheme.bodySmall?.copyWith(
        color: AppColors.textMuted,
      ),
      textAlign: TextAlign.center,
    );
  }
}


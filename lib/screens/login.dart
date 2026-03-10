import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../utils/error_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.loginWithOTP(_mobileController.text.trim());

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!success) {
            _errorMessage = ErrorUtils.extractErrorMessage(
              authProvider.error ?? 'Login failed',
            );
          }
        });

        if (success) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  void _handleLoginWithPin() {
    Navigator.of(context).pushNamed('/pin-login');
  }

  void _handleSignUp() {
    Navigator.of(context).pushNamed('/register');
  }

  bool get _canSignIn {
    return _mobileController.text.isNotEmpty && !_isLoading;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                AppColors.offWhite.withOpacity(0.3),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final horizontalPadding = size.width > 600 ? 48.0 : 24.0;
              
              return Form(
                key: _formKey,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Flexible header section
                      Flexible(
                        flex: 2,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: availableHeight * 0.03),
                              _buildHeader(textTheme, size),
                            ],
                          ),
                        ),
                      ),
                      
                      // Form card section - flexible to fit remaining space
                      Flexible(
                        flex: 3,
                        fit: FlexFit.tight,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: availableHeight * 0.02),
                              _buildFormCard(textTheme, theme),
                            ],
                          ),
                        ),
                      ),
                      
                      // Footer section - minimal space
                      Flexible(
                        flex: 1,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: availableHeight * 0.02),
                              _buildFooter(textTheme),
                              SizedBox(height: availableHeight * 0.01),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(TextTheme textTheme, Size size) {
    final isSmallScreen = size.height < 700;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo with professional container
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 20.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/logo.png',
            height: isSmallScreen ? 50.0 : 70.0,
            width: isSmallScreen ? 120.0 : 160.0,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: isSmallScreen ? 50.0 : 70.0,
                width: isSmallScreen ? 120.0 : 160.0,
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  Icons.local_shipping,
                  size: isSmallScreen ? 30.0 : 40.0,
                  color: AppColors.primary,
                ),
              );
            },
          ),
        ),
        SizedBox(height: isSmallScreen ? 16.0 : 24.0),
        
        // Heading
        Text(
          'Welcome to Porttivo Transporter',
          style: (isSmallScreen ? textTheme.headlineSmall : textTheme.headlineMedium)?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isSmallScreen ? 8.0 : 12.0),
        
        // Subtitle
        Text(
          'Enter your mobile number to receive OTP and continue',
          style: (isSmallScreen ? textTheme.bodyMedium : textTheme.bodyLarge)?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFormCard(TextTheme textTheme, ThemeData theme) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 24.0,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mobile Number Field
          _buildMobileField(textTheme),
          
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          
          // Error Message
          if (_errorMessage != null) ...[
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
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
                    size: isSmallScreen ? 18.0 : 20.0,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        fontSize: isSmallScreen ? 11.0 : 12.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          ],
          
          // Primary Action Button
          _buildSignInButton(theme, isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          
          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: AppColors.dividerGrey,
                  thickness: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'OR',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 11.0 : 12.0,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: AppColors.dividerGrey,
                  thickness: 1.0,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          
          // Secondary Actions
          _buildLoginWithPinButton(textTheme, isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          
          _buildSignUpLink(textTheme, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildMobileField(TextTheme textTheme) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    
    return TextFormField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleSignIn(),
      style: TextStyle(
        fontSize: isSmallScreen ? 14.0 : 16.0,
      ),
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        hintText: 'Enter your 10-digit mobile number',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: isSmallScreen ? 14.0 : 16.0,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(
            Icons.phone_android,
            color: AppColors.primary,
            size: isSmallScreen ? 18.0 : 20.0,
          ),
        ),
        filled: true,
        fillColor: AppColors.offWhite,
      ),
      onChanged: (_) {
        setState(() {
          _errorMessage = null;
        });
      },
      validator: Validators.validateMobile,
    );
  }

  Widget _buildSignInButton(ThemeData theme, bool isSmallScreen) {
    return Container(
      height: isSmallScreen ? 50.0 : 56.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: _canSignIn
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12.0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: _canSignIn ? _handleSignIn : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 14.0 : 16.0,
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: isSmallScreen ? 20.0 : 24.0,
                width: isSmallScreen ? 20.0 : 24.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.background,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Continue with OTP',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        fontSize: isSmallScreen ? 13.0 : 14.0,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Icon(
                    Icons.arrow_forward,
                    size: isSmallScreen ? 18.0 : 20.0,
                    color: AppColors.background,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginWithPinButton(TextTheme textTheme, bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 50.0 : 56.0,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleLoginWithPin,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 14.0 : 16.0,
          ),
          side: BorderSide(
            color: AppColors.dividerGrey,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          backgroundColor: AppColors.background,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: isSmallScreen ? 18.0 : 20.0,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 8.0),
            Flexible(
              child: Text(
                'Login with PIN',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 13.0 : 14.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLink(TextTheme textTheme, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4.0 : 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              "New transporter? ",
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: isSmallScreen ? 12.0 : 14.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _handleSignUp,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Register here',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
                fontSize: isSmallScreen ? 12.0 : 14.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(TextTheme textTheme) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'By continuing, you agree to our ',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: isSmallScreen ? 10.0 : 11.0,
              ),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () {
                // Navigate to terms
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Terms of Service',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  fontSize: isSmallScreen ? 10.0 : 11.0,
                ),
              ),
            ),
            Text(
              ' and ',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: isSmallScreen ? 10.0 : 11.0,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to privacy
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Privacy Policy',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  fontSize: isSmallScreen ? 10.0 : 11.0,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 8.0 : 12.0),
        Text(
          '© 2025 Porttivo. All rights reserved.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: isSmallScreen ? 9.0 : 10.0,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

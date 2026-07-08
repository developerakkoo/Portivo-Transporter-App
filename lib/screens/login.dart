import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/permission_modal.dart';
import '../services/device_permission_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  /// Prevents overlapping async permission checks (post-frame + lifecycle resume).
  bool _permissionModalCheckInFlight = false;

  final DevicePermissionService _devicePermissionService = DevicePermissionService();

  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPermissionModal());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeShowPermissionModalAfterResume();
    }
  }

  /// After returning from Settings (or multitasking), skip work entirely if the login gate is satisfied.
  Future<void> _maybeShowPermissionModalAfterResume() async {
    if (_permissionModalCheckInFlight) return;
    if (await _devicePermissionService.areLoginGatePermissionsGranted()) {
      return;
    }
    await _maybeShowPermissionModal();
  }

  /// Shows the login permission sheet when location/camera are not granted.
  /// [_permissionModalCheckInFlight] stays true until the sheet is closed (prevents duplicate sheets).
  /// [DevicePermissionService.areLoginGatePermissionsGranted] already retries OS reads to avoid false negatives.
  Future<void> _maybeShowPermissionModal() async {
    if (_permissionModalCheckInFlight || !mounted) return;
    _permissionModalCheckInFlight = true;
    try {
      // Let Geolocator / permission_handler native bridges finish (avoids false "denied" on cold start).
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      if (await _devicePermissionService.areLoginGatePermissionsGranted()) {
        return;
      }

      if (!mounted) return;
      await PermissionModal.show(context);
    } finally {
      _permissionModalCheckInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            _errorMessage = ErrorUtils.userMessage(
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

    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeroBand(textTheme),
            Expanded(
              child: _buildFormSheet(textTheme, theme),
            ),
          ],
        ),
      ),
    );
  }

  // ── HERO BAND ──────────────────────────────────────────────────

  Widget _buildHeroBand(TextTheme textTheme) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.background,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Porttivo',
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'TRANSPORTER',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.background.withOpacity(0.55),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Waypoint dots — logistics motif
          _buildWaypointRow(),

          const SizedBox(height: 16),

          // Headline
          Text(
            'Welcome back',
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.background,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your mobile number to get a one-time password',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.background.withOpacity(0.65),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointRow() {
    return Row(
      children: [
        _buildWaypointDot(),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.background.withOpacity(0.3),
          ),
        ),
        _buildWaypointDot(),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.background.withOpacity(0.3),
          ),
        ),
        _buildWaypointDot(),
      ],
    );
  }

  Widget _buildWaypointDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
    );
  }

  // ── FORM SHEET ─────────────────────────────────────────────────

  Widget _buildFormSheet(TextTheme textTheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 28,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMobileField(textTheme),
              const SizedBox(height: 8),
              _buildErrorMessage(textTheme),
              const SizedBox(height: 20),
              _buildSignInButton(theme),
              const SizedBox(height: 20),
              _buildOrDivider(textTheme),
              const SizedBox(height: 20),
              _buildLoginWithPinButton(textTheme),
              const SizedBox(height: 20),
              _buildPermissionNudgeCard(textTheme),
              const SizedBox(height: 24),
              _buildRegisterRow(textTheme),
              const SizedBox(height: 20),
              _buildFooter(textTheme),
            ],
          ),
        ),
      ),
    );
  }

  // ── MOBILE FIELD ───────────────────────────────────────────────

  Widget _buildMobileField(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MOBILE NUMBER',
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleSignIn(),
          onChanged: (_) => setState(() => _errorMessage = null),
          validator: Validators.validateMobile,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: '10-digit mobile number',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            prefixIcon: Container(
              width: 64,
              margin: const EdgeInsets.fromLTRB(4, 4, 0, 4),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_android,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+91',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            filled: true,
            fillColor: AppColors.offWhite,
          ),
        ),
      ],
    );
  }

  // ── ERROR MESSAGE ──────────────────────────────────────────────

  Widget _buildErrorMessage(TextTheme textTheme) {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.error.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── SIGN IN BUTTON ─────────────────────────────────────────────

  Widget _buildSignInButton(ThemeData theme) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _canSignIn ? _handleSignIn : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue with OTP',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.background,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }

  // ── OR DIVIDER ─────────────────────────────────────────────────

  Widget _buildOrDivider(TextTheme textTheme) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.dividerGrey, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.dividerGrey, thickness: 1)),
      ],
    );
  }

  // ── PIN BUTTON ─────────────────────────────────────────────────

  Widget _buildLoginWithPinButton(TextTheme textTheme) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleLoginWithPin,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.dividerGrey, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.background,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.textPrimary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Login with PIN',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PERMISSION NUDGE CARD ──────────────────────────────────────

  Widget _buildPermissionNudgeCard(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Keep Bluetooth, Wi-Fi and Location enabled for seamless delivery tracking.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── REGISTER ROW ───────────────────────────────────────────────

  Widget _buildRegisterRow(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New transporter? ',
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
            ),
          ),
        ),
      ],
    );
  }

  // ── FOOTER ─────────────────────────────────────────────────────

  Widget _buildFooter(TextTheme textTheme) {
    return Column(
      children: [
        Divider(color: AppColors.dividerGrey, thickness: 1),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'By continuing, you agree to our ',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            TextButton(
              onPressed: () {},
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
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              ' and ',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            TextButton(
              onPressed: () {},
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
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '© 2025 Porttivo. All rights reserved.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

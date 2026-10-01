import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/pin_digit_field.dart';

class OtpVerifyArgs {
  const OtpVerifyArgs({
    required this.mobile,
    this.requestId,
  });

  final String mobile;
  final String? requestId;
}

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key, required this.args});

  final OtpVerifyArgs args;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  static const int _otpLength = 4;
  static const int _resendSeconds = 30;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  int _secondsLeft = _resendSeconds;
  Timer? _timer;
  String? _errorMessage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  String get _maskedMobile {
    final m = widget.args.mobile;
    if (m.length < 4) return m;
    return '+91 ••••••${m.substring(m.length - 4)}';
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  void _onDigitChanged(String value, int index) {
    setState(() => _errorMessage = null);
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == _otpLength) {
      unawaited(_verify());
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_otp.length != _otpLength) {
      setState(() => _errorMessage = 'Enter the 4-digit OTP');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyLoginOtp(mobile: widget.args.mobile, otp: _otp);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      return;
    }
    setState(() {
      _busy = false;
      _errorMessage = ErrorUtils.userMessage(
        auth.error ?? 'Invalid or expired OTP',
      );
    });
    _clearOtp();
  }

  Future<void> _resend({String retryType = 'text'}) async {
    if (_busy || _secondsLeft > 0) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendLoginOtp(widget.args.mobile, retryType: retryType);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _clearOtp();
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            retryType == 'voice'
                ? 'We will call you with the code'
                : 'A new OTP was sent',
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = ErrorUtils.userMessage(
          auth.error ?? 'Could not resend OTP',
        );
      });
    }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.background),
                  ),
                  Expanded(
                    child: Text(
                      'Verify OTP',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter the 4-digit code sent to $_maskedMobile',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.background.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_otpLength, (index) {
                          return _buildDigit(index);
                        }),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _verify,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : const Text('Verify'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_secondsLeft > 0)
                        Text(
                          'Resend SMS in ${_secondsLeft}s',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _busy ? null : () => _resend(),
                          child: const Text('Resend SMS'),
                        ),
                      TextButton(
                        onPressed: _busy || _secondsLeft > 0
                            ? null
                            : () => _resend(retryType: 'voice'),
                        child: const Text('Call me instead'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigit(int index) {
    final controller = _controllers[index];
    final focusNode = _focusNodes[index];
    final isFocused = focusNode.hasFocus;
    final hasValue = controller.text.isNotEmpty;

    return PinDigitField(
      index: index,
      controller: controller,
      focusNode: focusNode,
      controllers: _controllers,
      focusNodes: _focusNodes,
      width: 46,
      height: 56,
      onChanged: (value) => _onDigitChanged(value, index),
      onStateChanged: () => setState(() {}),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: hasValue || isFocused ? AppColors.background : AppColors.offWhite,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isFocused ? AppColors.primary : AppColors.dividerGrey,
            width: isFocused ? 2 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isFocused ? AppColors.primary : AppColors.dividerGrey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onFieldSubmitted: (_) => _verify(),
    );
  }
}

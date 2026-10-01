import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/kyc_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/beneficiary_provider.dart';
import '../../services/kyc_service.dart';

const kycCompletedPrefKey = 'transporter_kyc_completed';
const kycBannerDismissedPrefKey = 'transporter_kyc_banner_dismissed';
const kycMaxFileBytes = 10 * 1024 * 1024;
final panNumberPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _panNumber = TextEditingController();
  final _aadhaarNumber = TextEditingController();
  final _kycService = KycService();

  TransporterKyc? _existing;
  String? _panFilePath;
  String? _aadhaarFilePath;
  String? _aadhaarBackFilePath;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BeneficiaryProvider>().loadBeneficiary(refresh: true);
      _loadExistingKyc();
    });
  }

  @override
  void dispose() {
    _panNumber.dispose();
    _aadhaarNumber.dispose();
    super.dispose();
  }

  Future<void> _loadExistingKyc() async {
    setState(() => _loading = true);
    try {
      final kyc = await _kycService.getKyc();
      if (!mounted) return;
      _existing = kyc;
      if (_panNumber.text.isEmpty && (kyc.panNumber ?? '').isNotEmpty) {
        _panNumber.text = kyc.panNumber!;
      }
      if (_aadhaarNumber.text.isEmpty && (kyc.aadhaarNumber ?? '').isNotEmpty) {
        _aadhaarNumber.text = kyc.aadhaarNumber!;
      }
    } catch (e) {
      if (mounted) {
        showUserErrorSnackBar(context, e, fallback: 'Could not load KYC');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument({required String kind}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    final file = File(path);
    final size = await file.length();
    if (size > kycMaxFileBytes) {
      if (!mounted) return;
      showUserErrorSnackBar(
        context,
        null,
        fallback: 'File must be 10 MB or smaller',
      );
      return;
    }

    setState(() {
      if (kind == 'pan') {
        _panFilePath = path;
      } else if (kind == 'aadhaarBack') {
        _aadhaarBackFilePath = path;
      } else {
        _aadhaarFilePath = path;
      }
    });
  }

  Future<void> _openBankDetails() async {
    await Navigator.of(context).pushNamed('/bank-account');
    if (!mounted) return;
    await context.read<BeneficiaryProvider>().loadBeneficiary(refresh: true);
    await _loadExistingKyc();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final existing = _existing;
    final block = kycSubmitBlockReason(
      pan: _panNumber.text,
      aadhaar: _aadhaarNumber.text,
      hasPanImage: _panFilePath != null || (existing?.hasExistingPanImage ?? false),
      hasAadhaarImage:
          _aadhaarFilePath != null || (existing?.hasExistingAadhaarImage ?? false),
    );
    if (block != null) {
      showUserErrorSnackBar(context, null, fallback: block);
      return;
    }

    setState(() => _saving = true);
    try {
      final beneficiary = context.read<BeneficiaryProvider>().beneficiary;
      final kyc = await _kycService.submitKyc(
        panNumber: _panNumber.text.trim().toUpperCase(),
        aadhaarNumber: _aadhaarNumber.text.replaceAll(RegExp(r'\s'), ''),
        panImagePath: _panFilePath,
        aadhaarImagePath: _aadhaarFilePath,
        aadhaarBackImagePath: _aadhaarBackFilePath,
        existingPanImageUrl: existing?.panImage ?? existing?.panImagePath,
        existingAadhaarImageUrl:
            existing?.aadhaarImage ?? existing?.aadhaarImagePath,
        existingAadhaarBackImageUrl:
            existing?.aadhaarBackImage ?? existing?.aadhaarBackImagePath,
        accountHolderName: beneficiary?.name,
        ifscCode: beneficiary?.ifsc,
        isUpdate: existing?.hasBeenSubmitted == true,
      );

      final prefs = await SharedPreferences.getInstance();
      if (kyc.isCompleted || kyc.networkAccessGranted) {
        await prefs.setBool(kycCompletedPrefKey, true);
      }
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;

      if (kyc.isCompleted || kyc.networkAccessGranted) {
        showUserSuccessSnackBar(
          context,
          'KYC completed. Network and marketplace access granted.',
        );
        Navigator.of(context).pop(true);
        return;
      }

      _existing = kyc;
      final missing = kycMissingRequirement(kyc);
      showUserErrorSnackBar(
        context,
        null,
        fallback: missing ?? 'KYC saved. Complete remaining documents to finish.',
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        showUserErrorSnackBar(context, e, fallback: 'Could not save KYC');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBank = context.watch<BeneficiaryProvider>().hasBankAccount ||
        (_existing?.bankDetails.isAdded == true);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Complete KYC')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'PAN, Aadhaar, and bank account details are required to complete verification.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _panNumber,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(10),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            return newValue.copyWith(
                              text: newValue.text.toUpperCase(),
                            );
                          }),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'PAN Number *',
                          hintText: 'ABCDE1234F',
                        ),
                        validator: (value) {
                          final pan = value?.trim().toUpperCase() ?? '';
                          if (pan.isEmpty) return 'PAN number is required';
                          if (!panNumberPattern.hasMatch(pan)) {
                            return 'Enter a valid 10-character PAN number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _pickDocument(kind: 'pan'),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(
                          _panFilePath == null &&
                                  !(_existing?.hasExistingPanImage ?? false)
                              ? 'Upload PAN image *'
                              : 'Change PAN document',
                        ),
                      ),
                      if (_panFilePath != null) ...[
                        const SizedBox(height: 8),
                        _KycDocPreview(
                          filePath: _panFilePath,
                          label: 'PAN selected',
                        ),
                      ] else if (_existing?.hasExistingPanImage == true) ...[
                        const SizedBox(height: 8),
                        _KycDocPreview(
                          networkUrl: resolveUploadUrl(
                            ApiConfig.baseUrl,
                            _existing?.panImage ?? _existing?.panImagePath,
                          ),
                          label: 'PAN uploaded',
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _aadhaarNumber,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Aadhaar Number *',
                          hintText: '12-digit number',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length != 12) {
                            return 'Enter a 12-digit Aadhaar number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _pickDocument(kind: 'aadhaar'),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(
                          _aadhaarFilePath == null &&
                                  !(_existing?.hasExistingAadhaarImage ?? false)
                              ? 'Upload Aadhaar front *'
                              : 'Change Aadhaar front',
                        ),
                      ),
                      if (_aadhaarFilePath != null) ...[
                        const SizedBox(height: 8),
                        _KycDocPreview(
                          filePath: _aadhaarFilePath,
                          label: 'Aadhaar front selected',
                        ),
                      ] else if (_existing?.hasExistingAadhaarImage == true) ...[
                        const SizedBox(height: 8),
                        _KycDocPreview(
                          networkUrl: resolveUploadUrl(
                            ApiConfig.baseUrl,
                            _existing?.aadhaarImage ??
                                _existing?.aadhaarImagePath,
                          ),
                          label: 'Aadhaar uploaded',
                        ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _pickDocument(kind: 'aadhaarBack'),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(
                          _aadhaarBackFilePath == null &&
                                  !(_existing?.hasExistingAadhaarBackImage ??
                                      false)
                              ? 'Upload Aadhaar back (optional)'
                              : 'Change Aadhaar back',
                        ),
                      ),
                      if (_aadhaarBackFilePath != null) ...[
                        const SizedBox(height: 8),
                        _KycDocPreview(
                          filePath: _aadhaarBackFilePath,
                          label: 'Aadhaar back selected',
                        ),
                      ] else if (_existing?.hasExistingAadhaarBackImage ==
                          true) ...[
                        const SizedBox(height: 8),
                        _KycDocPreview(
                          networkUrl: resolveUploadUrl(
                            ApiConfig.baseUrl,
                            _existing?.aadhaarBackImage ??
                                _existing?.aadhaarBackImagePath,
                          ),
                          label: 'Aadhaar back uploaded',
                        ),
                      ],
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _openBankDetails,
                        icon: Icon(
                          hasBank
                              ? Icons.check_circle_outline
                              : Icons.account_balance_outlined,
                          color: hasBank ? AppColors.success : null,
                        ),
                        label: Text(
                          hasBank
                              ? 'Bank details added'
                              : 'Add bank account details *',
                        ),
                      ),
                      if (!hasBank)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Register a Razorpay beneficiary bank account to complete KYC.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Text('Submit KYC'),
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

class _KycDocPreview extends StatelessWidget {
  const _KycDocPreview({
    this.filePath,
    this.networkUrl,
    required this.label,
  });

  final String? filePath;
  final String? networkUrl;
  final String label;

  bool get _isPdf {
    final value = (filePath ?? networkUrl ?? '').toLowerCase();
    return value.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    Widget thumb;
    if (_isPdf) {
      thumb = Container(
        width: 56,
        height: 56,
        color: AppColors.offWhite,
        child: const Icon(Icons.picture_as_pdf_outlined),
      );
    } else if (filePath != null) {
      thumb = Image.file(
        File(filePath!),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: AppColors.offWhite,
          child: const Icon(Icons.image),
        ),
      );
    } else if (networkUrl != null && networkUrl!.isNotEmpty) {
      thumb = Image.network(
        networkUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: AppColors.offWhite,
          child: const Icon(Icons.image),
        ),
      );
    } else {
      thumb = Container(
        width: 56,
        height: 56,
        color: AppColors.offWhite,
        child: const Icon(Icons.image),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: thumb,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> isLocalKycCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kycCompletedPrefKey) == true;
}

Future<bool> isKycBannerDismissed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kycBannerDismissedPrefKey) == true;
}

Future<void> dismissKycBanner() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kycBannerDismissedPrefKey, true);
}

/// Returns a user-facing reason when KYC cannot be submitted, or null if valid.
/// Bank details are not part of the current backend completion condition.
String? kycSubmitBlockReason({
  required String pan,
  required String aadhaar,
  required bool hasPanImage,
  required bool hasAadhaarImage,
  bool hasBank = true,
}) {
  final normalizedPan = pan.trim().toUpperCase();
  final normalizedAadhaar = aadhaar.replaceAll(RegExp(r'\s'), '');
  if (normalizedPan.isEmpty) return 'PAN number is required';
  if (!panNumberPattern.hasMatch(normalizedPan)) {
    return 'Enter a valid 10-character PAN number';
  }
  if (normalizedAadhaar.length != 12) return 'Enter a 12-digit Aadhaar number';
  if (!hasPanImage) return 'PAN image is required';
  if (!hasAadhaarImage) return 'Aadhaar image is required';
  return null;
}

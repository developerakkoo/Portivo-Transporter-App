import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/beneficiary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/beneficiary_provider.dart';

/// Bank account details for sending and receiving payments.
///
/// The account is registered as a Razorpay payout beneficiary (contact + fund
/// account). Our backend keeps the Razorpay ids; this screen reads the current
/// state from GET /payouts/beneficiary.
class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _accountController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();

  bool _prefilled = false;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BeneficiaryProvider>().loadBeneficiary(refresh: true);
      _prefillFromProfile();
    });
  }

  void _prefillFromProfile() {
    if (_prefilled) return;
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      if (_nameController.text.isEmpty && (user.name ?? '').isNotEmpty) {
        _nameController.text = user.name!;
      }
      if (_phoneController.text.isEmpty && user.mobile.isNotEmpty) {
        _phoneController.text = user.mobile;
      }
      _prefilled = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<BeneficiaryProvider>();
    final success = await provider.addBeneficiary(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      bankAccount: _accountController.text.trim(),
      ifsc: _ifscController.text.trim().toUpperCase(),
      email: _emailController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      setState(() => _showAddForm = false);
      showUserSuccessSnackBar(context, 'Bank account added successfully');
    } else {
      showUserErrorSnackBar(
        context,
        provider.error,
        fallback: 'Failed to add bank account',
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this bank account?'),
        content: const Text(
          'This account will no longer receive payouts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<BeneficiaryProvider>();
    final success = await provider.deleteBeneficiary();

    if (!mounted) return;
    if (success) {
      showUserSuccessSnackBar(context, 'Bank account removed');
    } else {
      showUserErrorSnackBar(
        context,
        provider.error,
        fallback: 'Failed to remove bank account',
      );
    }
  }

  void _handleAddAccount(BeneficiaryProvider provider) {
    if (provider.hasBankAccount) {
      // The payout partner supports one active beneficiary per account, so a
      // second account cannot be added until the current one is removed.
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add bank account'),
          content: const Text(
            'Only one bank account can be active at a time. Your current '
            'account is set as primary — remove it to add a new one.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _showAddForm = true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeneficiaryProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bank Account Details'),
        actions: [
          if (provider.hasLoaded)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add bank account',
              onPressed: () => _handleAddAccount(provider),
            ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (provider.isLoading && !provider.hasLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!provider.hasLoaded && provider.error != null) {
              return _buildLoadError(provider);
            }

            if (provider.hasBankAccount) {
              return _buildDetailsView(provider);
            }

            if (_showAddForm) {
              return _buildAddForm(provider);
            }

            return _buildEmptyState();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 56.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16.0),
            const Text(
              'No bank account added',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Add a bank account to send and receive payouts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAddForm = true),
              icon: const Icon(Icons.add),
              label: const Text('Add Bank Account'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 14.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(BeneficiaryProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48.0, color: AppColors.error),
            const SizedBox(height: 16.0),
            Text(
              provider.error ?? 'Failed to load bank account details',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16.0),
            OutlinedButton(
              onPressed: () => provider.loadBeneficiary(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Details view (beneficiary already registered)
  // ---------------------------------------------------------------------

  Widget _buildDetailsView(BeneficiaryProvider provider) {
    final beneficiary = provider.beneficiary!;

    return RefreshIndicator(
      onRefresh: () => provider.loadBeneficiary(refresh: true),
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          if (provider.isSubmitting)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: AppColors.dividerGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: AppColors.background,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  beneficiary.name ?? 'Bank account',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              _buildPrimaryChip(),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            beneficiary.maskedAccountNumber ?? '',
                            style: const TextStyle(
                              fontSize: 14.0,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(beneficiary),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'More options',
                      onSelected: (value) {
                        if (value == 'remove') {
                          _handleDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20.0,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 8.0),
                              Text(
                                'Remove Account',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20.0),
                _buildDetailRow('Account number',
                    beneficiary.maskedAccountNumber ?? '—'),
                _buildDetailRow('IFSC', beneficiary.ifsc ?? '—'),
                _buildDetailRow('Phone', beneficiary.phone ?? '—'),
                if (beneficiary.razorpayFundAccountId != null &&
                    beneficiary.razorpayFundAccountId!.isNotEmpty)
                  _buildDetailRow(
                    'Razorpay fund account',
                    beneficiary.razorpayFundAccountId!,
                  ),
                if (beneficiary.createdAt != null)
                  _buildDetailRow(
                    'Added on',
                    _formatDateTime(beneficiary.createdAt!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'Your bank details are stored securely with our payment partner '
            '(Razorpay) and are used only for sending and receiving payments.',
            style: TextStyle(fontSize: 12.0, color: AppColors.textMuted),
          ),
          const SizedBox(height: 32.0),
          const Text(
            'Manage bank accounts for payouts',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.0, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: const Text(
        'Primary',
        style: TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: AppColors.info,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BeneficiaryModel beneficiary) {
    final status = (beneficiary.verificationStatus ?? '').toUpperCase();
    final isVerified = status == 'VERIFIED' || status == 'ACTIVE';
    final color = isVerified ? AppColors.success : AppColors.warning;
    final label = isVerified ? 'Active' : (status.isEmpty ? 'Pending' : status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130.0,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.0,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}, '
        '${hour12.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} $period';
  }

  // ---------------------------------------------------------------------
  // Add form (no beneficiary yet)
  // ---------------------------------------------------------------------

  Widget _buildAddForm(BeneficiaryProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add your bank account to send and receive payments. Your bank '
              'details are stored securely with our payment partner (Razorpay) '
              'and never saved in full on our servers.',
              style: TextStyle(fontSize: 13.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24.0),
            _sectionLabel('Account holder'),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Account Holder Name',
                hintText: 'Name as per bank records',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the account holder name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter 10-digit phone number',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.trim().length != 10) {
                  return 'Phone number must be 10 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                hintText: 'Enter email address',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 24.0),
            _sectionLabel('Bank account'),
            TextFormField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: const InputDecoration(
                labelText: 'Account Number',
                hintText: 'Enter bank account number',
              ),
              validator: (value) {
                final account = value?.trim() ?? '';
                if (account.isEmpty) {
                  return 'Please enter account number';
                }
                if (account.length < 9 || account.length > 18) {
                  return 'Account number must be 9-18 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _confirmAccountController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: const InputDecoration(
                labelText: 'Confirm Account Number',
                hintText: 'Re-enter bank account number',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please confirm account number';
                }
                if (value.trim() != _accountController.text.trim()) {
                  return 'Account numbers do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _ifscController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(11),
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(
                    text: newValue.text.toUpperCase(),
                  ),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'IFSC Code',
                hintText: 'e.g. MAHB0001462',
              ),
              validator: (value) {
                final ifsc = value?.trim().toUpperCase() ?? '';
                if (ifsc.isEmpty) {
                  return 'Please enter IFSC code';
                }
                if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
                  return 'Please enter a valid IFSC code';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
            const SizedBox(height: 32.0),
            SizedBox(
              height: 52.0,
              child: ElevatedButton(
                onPressed: provider.isSubmitting ? null : _handleSubmit,
                child: provider.isSubmitting
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
                    : const Text(
                        'Add Bank Account',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

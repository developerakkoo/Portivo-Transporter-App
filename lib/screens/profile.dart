import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/helpers.dart';
import '../data/models/transporter_model.dart';
import '../services/transporter_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TransporterService _transporterService = TransporterService();
  TransporterModel? _transporter;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transporter = await _transporterService.getProfile();
      setState(() {
        _transporter = transporter;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProfile,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorView(textTheme)
                : _transporter != null
                    ? _buildProfileContent(textTheme)
                    : _buildEmptyView(textTheme),
      ),
    );
  }

  Widget _buildErrorView(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.0,
              color: AppColors.error,
            ),
            const SizedBox(height: 16.0),
            Text(
              'Error loading profile',
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              _error ?? 'Unknown error',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(TextTheme textTheme) {
    return Center(
      child: Text(
        'No profile data available',
        style: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProfileContent(TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            _buildProfileHeader(textTheme),
            const SizedBox(height: 32.0),

            // Profile Information
            _buildSectionTitle('Personal Information', textTheme),
            const SizedBox(height: 16.0),
            _buildInfoCard(
              icon: Icons.person_outline,
              label: 'Name',
              value: _transporter!.name ?? 'Not set',
              textTheme: textTheme,
            ),
            const SizedBox(height: 12.0),
            _buildInfoCard(
              icon: Icons.phone_outlined,
              label: 'Mobile Number',
              value: _transporter!.mobile,
              textTheme: textTheme,
            ),
            const SizedBox(height: 12.0),
            _buildInfoCard(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _transporter!.email ?? 'Not set',
              textTheme: textTheme,
            ),
            const SizedBox(height: 32.0),

            // Company Information
            _buildSectionTitle('Company Information', textTheme),
            const SizedBox(height: 16.0),
            _buildInfoCard(
              icon: Icons.business_outlined,
              label: 'Company',
              value: _transporter!.company ?? 'Not set',
              textTheme: textTheme,
            ),
            const SizedBox(height: 32.0),

            // Account Information
            _buildSectionTitle('Account Information', textTheme),
            const SizedBox(height: 16.0),
            _buildInfoCard(
              icon: Icons.info_outline,
              label: 'Status',
              value: _transporter!.status.toUpperCase(),
              textTheme: textTheme,
              valueColor: _getStatusColor(_transporter!.status),
            ),
            const SizedBox(height: 12.0),
            _buildInfoCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet Balance',
              value: '\$${_transporter!.walletBalance.toStringAsFixed(2)}',
              textTheme: textTheme,
              valueColor: AppColors.primary,
            ),
            const SizedBox(height: 12.0),
            _buildInfoCard(
              icon: Icons.calendar_today_outlined,
              label: 'Account Created',
              value: Helpers.formatDateTime(_transporter!.createdAt),
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40.0,
            backgroundColor: AppColors.background,
            child: Text(
              _transporter!.name?.isNotEmpty == true
                  ? _transporter!.name![0].toUpperCase()
                  : 'T',
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _transporter!.name ?? 'Transporter',
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  _transporter!.company ?? 'No company',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.background.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required TextTheme textTheme,
    Color? valueColor,
  }) {
    return Container(
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
          Icon(
            icon,
            color: AppColors.primary,
            size: 24.0,
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'blocked':
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/company_user_model.dart';
import '../../providers/company_user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';

class CompanyUsersScreen extends StatefulWidget {
  const CompanyUsersScreen({super.key});

  @override
  State<CompanyUsersScreen> createState() => _CompanyUsersScreenState();
}

class _CompanyUsersScreenState extends State<CompanyUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyUserProvider>().loadUsers();
    });
  }

  Future<void> _handleDelete(CompanyUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${user.name}? This action cannot be undone.',
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

    if (confirmed == true && mounted) {
      final provider = context.read<CompanyUserProvider>();
      final success = await provider.deleteUser(user.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to delete user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleToggleAccess(CompanyUserModel user) async {
    final provider = context.read<CompanyUserProvider>();
    final newAccess = !user.hasAccess;
    
    if (!newAccess) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable Access'),
          content: Text(
            'Are you sure you want to disable access for ${user.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final success = await provider.toggleAccess(user.id, newAccess);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access ${newAccess ? 'enabled' : 'disabled'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to toggle access'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, authChild) {
        final permissionService = PermissionService(authProvider);
        
        // Check permission - redirect if unauthorized
        if (!permissionService.hasPermission('manageUsers') && !permissionService.isTransporter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to access company users'),
                backgroundColor: Colors.red,
              ),
            );
          });
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Company & Users')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Consumer<CompanyUserProvider>(
          builder: (context, provider, child) {
        final users = provider.users;
        final isLoading = provider.isLoading;
        final error = provider.error;

        if (isLoading && users.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Company & Users'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (error != null && users.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Company & Users'),
            ),
            body: Center(
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
                    'Error loading users',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    error,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () => provider.loadUsers(refresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Company & Users'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading
                    ? null
                    : () => provider.loadUsers(refresh: true),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.loadUsers(refresh: true),
            child: users.isEmpty
                ? _buildEmptyState(textTheme)
                : _buildUsersList(users, textTheme),
          ),
          floatingActionButton: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final permissionService = PermissionService(authProvider);
              // Only show "Add User" button if user has manageUsers permission or is transporter
              if (permissionService.hasPermission('manageUsers') || permissionService.isTransporter) {
                return FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/add-user', arguments: {'mode': 'add'})
                        .then((_) => provider.loadUsers(refresh: true));
                  },
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: AppColors.background),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
      },
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outlined,
              size: 64.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 24.0),
            Text(
              'No users yet',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              'Add users to grant them access to the app',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(List<CompanyUserModel> users, TextTheme textTheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(user, textTheme);
      },
    );
  }

  Widget _buildUserCard(CompanyUserModel user, TextTheme textTheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: AppColors.dividerGrey,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context)
              .pushNamed('/add-user', arguments: {'user': user, 'mode': 'edit'})
              .then((_) => context.read<CompanyUserProvider>().loadUsers(refresh: true));
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.offWhite,
                    radius: 24.0,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          user.mobile,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          Navigator.of(context)
                              .pushNamed('/add-user',
                                  arguments: {'user': user, 'mode': 'edit'})
                              .then((_) => context.read<CompanyUserProvider>().loadUsers(refresh: true));
                          break;
                        case 'toggle':
                          _handleToggleAccess(user);
                          break;
                        case 'delete':
                          _handleDelete(user);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(user.hasAccess ? 'Disable Access' : 'Enable Access'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildStatusChip(
                    user.hasAccess ? 'Active' : 'Inactive',
                    user.hasAccess ? AppColors.success : AppColors.textMuted,
                  ),
                  _buildStatusChip(
                    user.hasPinSet() ? 'PIN Set' : 'No PIN',
                    user.hasPinSet() ? AppColors.success : AppColors.warning,
                  ),
                  _buildStatusChip(
                    '${user.permissions.length} permissions',
                    AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed('/add-user',
                                arguments: {'user': user, 'mode': 'set-pin'})
                            .then((_) => context.read<CompanyUserProvider>().loadUsers(refresh: true));
                      },
                      icon: Icon(
                        user.hasPinSet() ? Icons.lock : Icons.lock_outline,
                        size: 18.0,
                      ),
                      label: Text(user.hasPinSet() ? 'Change PIN' : 'Set PIN'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Switch(
                    value: user.hasAccess,
                    onChanged: (value) {
                      _handleToggleAccess(user);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

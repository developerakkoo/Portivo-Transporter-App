import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_user.dart';

class CompanyUsersScreen extends StatefulWidget {
  const CompanyUsersScreen({super.key});

  @override
  State<CompanyUsersScreen> createState() => _CompanyUsersScreenState();
}

class _CompanyUsersScreenState extends State<CompanyUsersScreen> {
  List<AppUser> _users = [];

  void _addUser(AppUser user) {
    setState(() {
      _users.add(user);
    });
  }

  void _updateUser(AppUser updatedUser) {
    setState(() {
      final index = _users.indexWhere((u) => u.id == updatedUser.id);
      if (index != -1) {
        _users[index] = updatedUser;
      }
    });
  }

  void _deleteUser(String userId) {
    setState(() {
      _users.removeWhere((u) => u.id == userId);
    });
  }

  void _toggleUserAccess(AppUser user) {
    setState(() {
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = user.copyWith(
          hasAccess: !user.hasAccess,
          updatedAt: DateTime.now(),
        );
      }
    });
  }

  void _showSetPinDialog(AppUser user) {
    Navigator.of(context).pushNamed(
      '/add-user',
      arguments: {'user': user, 'mode': 'set-pin'},
    ).then((result) {
      if (result != null && result is AppUser) {
        _updateUser(result);
      }
    });
  }

  void _showDeleteConfirmation(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${user.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteUser(user.id);
            },
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
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Company & Users'),
      ),
      body: _users.isEmpty
          ? _buildEmptyState(textTheme)
          : _buildUsersList(textTheme),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .pushNamed('/add-user', arguments: {'mode': 'add'})
              .then((result) {
            if (result != null && result is AppUser) {
              _addUser(result);
            }
          });
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
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

  Widget _buildUsersList(TextTheme textTheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserCard(user, textTheme);
      },
    );
  }

  Widget _buildUserCard(AppUser user, TextTheme textTheme) {
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
              .then((result) {
            if (result != null && result is AppUser) {
              _updateUser(result);
            }
          });
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
                          user.phone,
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
                              .then((result) {
                            if (result != null && result is AppUser) {
                              _updateUser(result);
                            }
                          });
                          break;
                        case 'toggle':
                          _toggleUserAccess(user);
                          break;
                        case 'delete':
                          _showDeleteConfirmation(user);
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
                  if (!user.hasPinSet())
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showSetPinDialog(user),
                        icon: const Icon(Icons.lock_outline, size: 18.0),
                        label: const Text('Set PIN'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showSetPinDialog(user),
                        icon: const Icon(Icons.lock, size: 18.0),
                        label: const Text('Change PIN'),
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
                      if (!value) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Disable Access'),
                            content: Text(
                              'Are you sure you want to disable access for ${user.name}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Cancel',
                                  style: textTheme.bodyLarge?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _toggleUserAccess(user);
                                },
                                child: Text(
                                  'Disable',
                                  style: textTheme.bodyLarge?.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        _toggleUserAccess(user);
                      }
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


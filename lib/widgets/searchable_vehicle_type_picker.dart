import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/notifications/app_banner_controller.dart';
import '../core/theme/app_colors.dart';
import '../data/models/vehicle_type_request_model.dart';
import '../core/utils/user_feedback.dart';
import '../providers/vehicle_type_provider.dart';

class SearchableVehicleTypePicker extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final String labelText;
  final bool mandatory;
  final bool allowClear;

  const SearchableVehicleTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.labelText = 'Vehicle Type *',
    this.mandatory = true,
    this.allowClear = false,
  });

  @override
  State<SearchableVehicleTypePicker> createState() =>
      _SearchableVehicleTypePickerState();
}

class _SearchableVehicleTypePickerState extends State<SearchableVehicleTypePicker> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.value ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VehicleTypeProvider>().ensureLoaded();
        _clearRejectedSelection(context.read<VehicleTypeProvider>());
      }
    });
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _showSuggestions = _focusNode.hasFocus);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchableVehicleTypePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        widget.value != _searchController.text) {
      // Defer so we don't mutate the controller (which notifies the enclosing
      // Form's TextFormField and calls setState) during the build phase, which
      // throws "setState() or markNeedsBuild() called during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = widget.value ?? '';
        if (_searchController.text != target) {
          _searchController.text = target;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearRejectedSelection(VehicleTypeProvider provider) {
    final current = widget.value ?? _searchController.text.trim();
    if (current.isEmpty || !provider.isRejectedType(current)) return;

    _searchController.clear();
    widget.onChanged(null);
  }

  String? _activeName(VehicleTypeProvider provider) {
    final selected = widget.value?.trim();
    if (selected != null && selected.isNotEmpty) return selected;

    final typed = _searchController.text.trim();
    if (typed.isEmpty) return null;

    final request = provider.requestForName(typed);
    if (request != null) return typed;

    if (provider.typeNames.contains(typed) || provider.isPendingType(typed)) {
      return typed;
    }

    return null;
  }

  Future<void> _openAddNewDialog(VehicleTypeProvider provider) async {
    final nameController = TextEditingController(text: _searchController.text.trim());
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add New Vehicle Type'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Vehicle type name',
              hintText: 'Enter the vehicle type',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(nameController.text.trim());
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (!mounted || submitted == null || submitted.isEmpty) return;

    try {
      final requestedName = await provider.submitNewType(submitted);
      if (!mounted || requestedName == null) return;

      _searchController.text = requestedName;
      widget.onChanged(requestedName);
      _focusNode.unfocus();
      setState(() => _showSuggestions = false);

      context.read<AppBannerController>().show(
            id: 'vehicle-type-submitted-$requestedName',
            title: 'Vehicle type submitted',
            body: 'Waiting for admin approval',
            type: AppBannerType.info,
          );
    } catch (e) {
      if (!mounted) return;
      showUserErrorSnackBar(context, e);
    }
  }

  void _selectValue(String? value, VehicleTypeProvider provider) {
    if (value != null && provider.isRejectedType(value)) {
      return;
    }

    if (value == null) {
      _searchController.clear();
      widget.onChanged(null);
      _focusNode.unfocus();
      setState(() => _showSuggestions = false);
      return;
    }

    _searchController.text = value;
    widget.onChanged(value);
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
  }

  Widget _buildRequestStatusBanner(VehicleTypeProvider provider) {
    final activeName = _activeName(provider);
    if (activeName == null) return const SizedBox.shrink();

    final request = provider.requestForName(activeName);
    if (request == null) return const SizedBox.shrink();

    if (request.isPending) {
      return _statusCard(
        color: AppColors.warning.withOpacity(0.12),
        borderColor: AppColors.warning,
        icon: Icons.hourglass_top_outlined,
        iconColor: AppColors.warning,
        title: '"$activeName" is pending admin approval.',
        message: 'You can still save this vehicle with this type.',
      );
    }

    if (request.isRejected) {
      final reason = request.rejectionReason?.trim();
      return _statusCard(
        color: Colors.red.withOpacity(0.08),
        borderColor: Colors.red.shade300,
        icon: Icons.cancel_outlined,
        iconColor: Colors.red.shade700,
        title: '"$activeName" was rejected.',
        message: reason != null && reason.isNotEmpty
            ? 'Reason: $reason. Choose another type or submit a new request.'
            : 'Choose another type or submit a new request.',
        actionLabel: 'Clear selection',
        onAction: () => _selectValue(null, provider),
      );
    }

    if (request.isApproved && provider.isRecentApproval(activeName)) {
      return _statusCard(
        color: Colors.green.withOpacity(0.1),
        borderColor: Colors.green.shade300,
        icon: Icons.check_circle_outline,
        iconColor: Colors.green.shade700,
        title: '"$activeName" was approved.',
        message: 'This type is now available to all transporters.',
        dismissLabel: 'Clear',
        onDismiss: () => provider.dismissApprovalBanner(activeName),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _statusCard({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    String? dismissLabel,
    VoidCallback? onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20.0),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    if (dismissLabel != null && onDismiss != null)
                      TextButton(
                        onPressed: onDismiss,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(dismissLabel),
                      ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8.0),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDecisionsList(VehicleTypeProvider provider) {
    if (!_showSuggestions || _searchController.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    final recent = provider.visibleRecentDecisions.take(3).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent vehicle type updates',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => provider.clearVisibleRecentDecisions(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          ...recent.map((request) => _recentDecisionTile(request)),
        ],
      ),
    );
  }

  Widget _recentDecisionTile(VehicleTypeRequestModel request) {
    final isApproved = request.isApproved;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isApproved ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18.0,
            color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              isApproved
                  ? '"${request.requestedName}" was approved.'
                  : request.rejectionReason != null &&
                          request.rejectionReason!.trim().isNotEmpty
                      ? '"${request.requestedName}" was rejected: ${request.rejectionReason}'
                      : '"${request.requestedName}" was rejected.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleTypeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && !provider.hasTypes && provider.pendingTypeNames.isEmpty) {
          return const LinearProgressIndicator();
        }

        if (provider.error != null && !provider.hasTypes && provider.pendingTypeNames.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Could not load vehicle types.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
              TextButton(
                onPressed: () => provider.ensureLoaded(refresh: true),
                child: const Text('Retry'),
              ),
            ],
          );
        }

        final filtered = provider.filterTypeNames(_searchController.text);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: 'Search vehicle type',
                suffixIcon: widget.allowClear && widget.value != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          widget.onChanged(null);
                          setState(() {});
                        },
                      )
                    : const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
              validator: widget.validator ??
                  (widget.mandatory
                      ? (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vehicle type is required';
                          }
                          final trimmed = value.trim();
                          if (provider.isRejectedType(trimmed)) {
                            return 'This vehicle type was rejected. Choose another type.';
                          }
                          final names = [
                            ...provider.typeNames,
                            ...provider.pendingTypeNames,
                          ];
                          if (!names.contains(trimmed)) {
                            return 'Select a vehicle type from the list';
                          }
                          return null;
                        }
                      : null),
            ),
            _buildRequestStatusBanner(provider),
            _buildRecentDecisionsList(provider),
            if (_showSuggestions)
              Container(
                margin: const EdgeInsets.only(top: 4.0),
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.dividerGrey),
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.allowClear)
                      ListTile(
                        dense: true,
                        title: const Text('Any'),
                        onTap: () => _selectValue(null, provider),
                      ),
                    ...filtered.map((name) {
                      final pending = provider.isPendingType(name);
                      final rejected = provider.isRejectedType(name);
                      return ListTile(
                        dense: true,
                        enabled: !rejected,
                        title: Text(
                          name,
                          style: rejected
                              ? TextStyle(color: AppColors.textMuted)
                              : null,
                        ),
                        subtitle: pending
                            ? Text(
                                'Pending approval',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.warning,
                                    ),
                              )
                            : rejected
                                ? Text(
                                    'Rejected',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.red.shade700,
                                        ),
                                  )
                                : null,
                        onTap: rejected ? null : () => _selectValue(name, provider),
                      );
                    }),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Other — Add New Vehicle Type'),
                      onTap: () => _openAddNewDialog(provider),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

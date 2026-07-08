import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/user_feedback.dart';
import '../../utils/error_utils.dart';
import '../../data/models/driver_model.dart';
import '../../data/models/fleet_import_result.dart';
import '../../providers/driver_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';

/// RC verification state for a single vehicle-number field.
enum VerifyState { idle, verifying, verified, notVerified, error }

/// One editable vehicle row in the Add Fleet screen.
class _FleetRow {
  final TextEditingController vehicleNumber = TextEditingController();
  String? vehicleType;

  // Assigned driver. If [driverId] is set the driver already exists in the app;
  // otherwise [driverName]/[driverMobile] describe a driver to be created on save.
  String? driverId;
  String? driverName;
  String? driverMobile;

  // RC verification state (informational; does not block saving).
  VerifyState verify = VerifyState.idle;
  String? verifyMessage;
  String? verifiedNumber; // normalized number that was last verified
  Timer? debounce;
  int verifyToken = 0; // guards against stale/superseded responses

  bool get hasDriver =>
      (driverId != null && driverId!.isNotEmpty) ||
      (driverMobile != null && driverMobile!.trim().isNotEmpty);

  String? get driverLabel {
    if (driverName != null && driverName!.trim().isNotEmpty) return driverName!.trim();
    if (driverMobile != null && driverMobile!.trim().isNotEmpty) return driverMobile!.trim();
    return null;
  }

  void dispose() {
    debounce?.cancel();
    vehicleNumber.dispose();
  }
}

/// Result of the per-row driver selection sheet.
class _DriverSelection {
  final String? driverId;
  final String? name;
  final String? mobile;

  _DriverSelection({this.driverId, this.name, this.mobile});
}

class AddFleetScreen extends StatefulWidget {
  const AddFleetScreen({super.key});

  @override
  State<AddFleetScreen> createState() => _AddFleetScreenState();
}

class _AddFleetScreenState extends State<AddFleetScreen> {
  final List<_FleetRow> _rows = [_FleetRow()];
  final VehicleService _vehicleService = VehicleService();

  bool _isSaving = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DriverProvider>().loadDrivers(refresh: true);
      context.read<VehicleTypeProvider>().ensureLoaded();
      // Needed to know which drivers are already assigned to a vehicle so the
      // driver picker can hide them. No-op if vehicles are already loaded.
      context.read<VehicleProvider>().loadVehicles();
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _normalizeMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  void _addRow() {
    setState(() => _rows.add(_FleetRow()));
  }

  void _removeRow(int index) {
    if (_rows.length == 1) {
      // Keep at least one row; just clear it.
      setState(() {
        final row = _rows[index];
        row.debounce?.cancel();
        row.vehicleNumber.clear();
        row.vehicleType = null;
        row.driverId = null;
        row.driverName = null;
        row.driverMobile = null;
        row.verify = VerifyState.idle;
        row.verifyMessage = null;
        row.verifiedNumber = null;
        row.verifyToken++;
      });
      return;
    }
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _selectDriver(int index) async {
    final selection = await showModalBottomSheet<_DriverSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (_) => _DriverSelectSheet(vehicleNumber: index + 1),
    );

    if (selection == null || !mounted) return;
    setState(() {
      _rows[index].driverId = selection.driverId;
      _rows[index].driverName = selection.name;
      _rows[index].driverMobile = selection.mobile;
    });
  }

  /// Debounced RC verification trigger, fired as the vehicle number changes.
  void _onVehicleNumberChanged(int index, String value) {
    final row = _rows[index];
    row.debounce?.cancel();

    final normalized = Validators.normalizeIndianVehicleRegistration(value);

    // Not a complete, well-formed number yet: reset any prior verification.
    if (Validators.validateVehicleNumber(value) != null) {
      row.verifyToken++;
      if (row.verify != VerifyState.idle ||
          row.verifyMessage != null ||
          row.verifiedNumber != null) {
        setState(() {
          row.verify = VerifyState.idle;
          row.verifyMessage = null;
          row.verifiedNumber = null;
        });
      }
      return;
    }

    // Already verified this exact number: keep the badge, no re-check.
    if (normalized == row.verifiedNumber) return;

    setState(() {
      row.verify = VerifyState.idle;
      row.verifyMessage = null;
    });
    row.debounce = Timer(
      const Duration(milliseconds: 700),
      () => _verifyRow(index, normalized),
    );
  }

  Future<void> _verifyRow(int index, String number) async {
    final row = _rows[index];
    final token = ++row.verifyToken;
    if (mounted) {
      setState(() {
        row.verify = VerifyState.verifying;
        row.verifyMessage = null;
      });
    }

    final result = await _vehicleService.verifyVehicleNumber(number);

    // Ignore stale/superseded responses (field edited or row removed).
    if (!mounted || token != row.verifyToken) return;

    setState(() {
      row.verifyMessage = result.message;
      if (result.isVerified) {
        row.verify = VerifyState.verified;
        row.verifiedNumber = number;
      } else if (result.success) {
        row.verify = VerifyState.notVerified;
        row.verifiedNumber = null;
      } else {
        row.verify = VerifyState.error;
        row.verifiedNumber = null;
      }
    });
  }

  String? _validateRows() {
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final numberError = Validators.validateVehicleNumber(row.vehicleNumber.text);
      if (numberError != null) {
        return 'Vehicle ${i + 1}: $numberError';
      }
      if (row.vehicleType == null || row.vehicleType!.trim().isEmpty) {
        return 'Vehicle ${i + 1}: please select a vehicle type';
      }
      if (!row.hasDriver) {
        return 'Vehicle ${i + 1}: please assign a driver';
      }
      if (row.driverId == null) {
        final mobile = _normalizeMobile(row.driverMobile ?? '');
        if (mobile.length != 10) {
          return 'Vehicle ${i + 1}: driver mobile must be 10 digits';
        }
      }
    }
    return null;
  }

  Future<void> _saveFleet() async {
    final validationError = _validateRows();
    if (validationError != null) {
      showUserErrorSnackBar(context, null, fallback: validationError);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final driverProvider = context.read<DriverProvider>();
    final vehicleProvider = context.read<VehicleProvider>();
    final results = <FleetImportRowResult>[];

    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final rowNum = i + 1;
      final normalizedNumber =
          Validators.normalizeIndianVehicleRegistration(row.vehicleNumber.text);
      try {
        String? driverId = row.driverId;

        // Resolve/create driver for manual or contact entries.
        if (driverId == null &&
            row.driverMobile != null &&
            row.driverMobile!.trim().isNotEmpty) {
          final mobile = _normalizeMobile(row.driverMobile!);
          final existing =
              driverProvider.drivers.where((d) => d.mobile == mobile).toList();
          if (existing.isNotEmpty) {
            driverId = existing.first.id;
          } else {
            final created = await driverProvider.createDriver(
              mobile: mobile,
              name: (row.driverName ?? '').trim(),
              status: 'active',
            );
            if (created != null) {
              driverId = created.id;
            } else {
              // Possibly already exists (409): reload and match by mobile.
              await driverProvider.loadDrivers(refresh: true);
              final again =
                  driverProvider.drivers.where((d) => d.mobile == mobile).toList();
              if (again.isNotEmpty) {
                driverId = again.first.id;
              } else {
                throw Exception(driverProvider.error ?? 'Failed to create driver');
              }
            }
          }
        }

        final vehicleData = <String, dynamic>{
          'vehicleNumber': normalizedNumber,
          'ownerType': 'OWN',
          'vehicleType': row.vehicleType,
          if (driverId != null) 'driverId': driverId,
        };

        final vehicle = await _vehicleService.createVehicle(vehicleData);
        results.add(FleetImportRowResult(
          row: rowNum,
          success: vehicle != null,
          vehicleNumber: normalizedNumber,
          vehicleId: vehicle?.id,
          driverId: driverId,
        ));
      } catch (e) {
        results.add(FleetImportRowResult(
          row: rowNum,
          success: false,
          vehicleNumber: normalizedNumber,
          error: _humanizeError(e),
        ));
      }
    }

    // Refresh caches so lists/counts reflect the new fleet.
    await vehicleProvider.loadVehicles(refresh: true);
    await driverProvider.loadDrivers(refresh: true);

    if (!mounted) return;
    setState(() => _isSaving = false);

    final succeeded = results.where((r) => r.success).length;
    final summary = FleetImportResult(
      total: results.length,
      succeeded: succeeded,
      failed: results.length - succeeded,
      results: results,
    );
    await _showResultsDialog(summary, title: 'Save Fleet');

    // Remove successfully-saved rows so the user can fix any failures.
    if (mounted && succeeded > 0) {
      final failedRowNumbers =
          results.where((r) => !r.success).map((r) => r.row).toSet();
      setState(() {
        final remaining = <_FleetRow>[];
        for (int i = 0; i < _rows.length; i++) {
          if (failedRowNumbers.contains(i + 1)) {
            remaining.add(_rows[i]);
          } else {
            _rows[i].dispose();
          }
        }
        _rows
          ..clear()
          ..addAll(remaining.isEmpty ? [_FleetRow()] : remaining);
      });
    }
  }

  Future<void> _importExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null) return;

      if (!mounted) return;
      final vehicleProvider = context.read<VehicleProvider>();
      final driverProvider = context.read<DriverProvider>();
      setState(() => _isImporting = true);

      final summary = await _vehicleService.bulkImportFleet(path);

      await vehicleProvider.loadVehicles(refresh: true);
      await driverProvider.loadDrivers(refresh: true);

      if (!mounted) return;
      setState(() => _isImporting = false);
      await _showResultsDialog(summary, title: 'Import Excel');
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        showUserErrorSnackBar(context, e, fallback: 'Failed to import file');
      }
    }
  }

  String _humanizeError(Object e) {
    // Extracts the backend/API message (e.g. from a DioException 400 body)
    // and filters out technical noise like the raw DioException dump.
    return ErrorUtils.userMessage(e, fallback: 'Could not save this vehicle');
  }

  Future<void> _showResultsDialog(FleetImportResult summary, {required String title}) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final failures = summary.results.where((r) => !r.success).toList();
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.succeeded} of ${summary.total} added successfully.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (summary.failed > 0) ...[
                  const SizedBox(height: 12.0),
                  Text(
                    '${summary.failed} failed:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: failures.length,
                      itemBuilder: (context, i) {
                        final f = failures[i];
                        final label = f.vehicleNumber?.isNotEmpty == true
                            ? f.vehicleNumber!
                            : 'Row ${f.row}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '- $label: ${f.error ?? 'Failed'}',
                            style: const TextStyle(
                              fontSize: 13.0,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Fleet'),
            Text(
              'Add your vehicles and regular drivers',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton.icon(
              onPressed: _isImporting || _isSaving ? null : _importExcel,
              icon: _isImporting
                  ? const SizedBox(
                      height: 16.0,
                      width: 16.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : const Icon(Icons.upload_file, size: 18.0),
              label: const Text('Import Excel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
          children: [
            _buildInfoBanner(
              icon: Icons.info_outline,
              text:
                  'Add your own vehicles and regular drivers. You can add hired vehicles while creating a trip.',
            ),
            const SizedBox(height: 24.0),
            Text(
              'Fleet Details',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Add one or more vehicles with their assigned driver.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Excel columns: vehicleNumber, vehicleType, driverName, driverMobile',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16.0),
            ...List.generate(_rows.length, (i) => _buildVehicleCard(i, textTheme)),
            const SizedBox(height: 4.0),
            _buildAddAnotherButton(textTheme),
            const SizedBox(height: 20.0),
            _buildInfoBanner(
              icon: Icons.verified_user_outlined,
              text:
                  'Drivers will be able to login to the Porttivo Driver App using their mobile number. If the number already exists, the driver will be linked to this vehicle.',
              tone: _BannerTone.success,
            ),
            const SizedBox(height: 24.0),
            SizedBox(
              height: 52.0,
              child: ElevatedButton.icon(
                onPressed: _isSaving || _isImporting ? null : _saveFleet,
                icon: _isSaving
                    ? const SizedBox(
                        height: 20.0,
                        width: 20.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.background),
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Fleet',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 14.0, color: AppColors.textMuted),
                const SizedBox(width: 6.0),
                Text(
                  'Your data is secure and encrypted',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(int index, TextTheme textTheme) {
    final row = _rows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
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
                width: 26.0,
                height: 26.0,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.background,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Text(
                'Vehicle ${index + 1}',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeRow(index),
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Remove vehicle',
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: row.vehicleNumber,
            textCapitalization: TextCapitalization.characters,
            maxLength: 10,
            onChanged: (value) => _onVehicleNumberChanged(index, value),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(10),
              TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(
                    text: newValue.text.toUpperCase(),
                    selection: newValue.selection,
                  )),
            ],
            decoration: InputDecoration(
              labelText: 'Vehicle Number *',
              hintText: 'e.g. MH12AB3434',
              counterText: '',
              suffixIcon: _buildVerifySuffixIcon(row),
            ),
          ),
          _buildVerifyStatus(row, textTheme),
          const SizedBox(height: 12.0),
          SearchableVehicleTypePicker(
            value: row.vehicleType,
            onChanged: (value) => setState(() => row.vehicleType = value),
          ),
          const SizedBox(height: 12.0),
          _buildDriverSelector(index, textTheme),
        ],
      ),
    );
  }

  Widget? _buildVerifySuffixIcon(_FleetRow row) {
    switch (row.verify) {
      case VerifyState.verifying:
        return const Padding(
          padding: EdgeInsets.all(12.0),
          child: SizedBox(
            height: 16.0,
            width: 16.0,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        );
      case VerifyState.verified:
        return const Icon(Icons.verified, color: AppColors.success);
      case VerifyState.notVerified:
        return const Icon(Icons.error_outline, color: AppColors.warning);
      case VerifyState.error:
        return const Icon(Icons.cloud_off_outlined, color: AppColors.textMuted);
      case VerifyState.idle:
        return null;
    }
  }

  Widget _buildVerifyStatus(_FleetRow row, TextTheme textTheme) {
    final String text;
    final Color color;
    switch (row.verify) {
      case VerifyState.verifying:
        text = 'Verifying vehicle...';
        color = AppColors.textSecondary;
        break;
      case VerifyState.verified:
        text = 'Verified';
        color = AppColors.success;
        break;
      case VerifyState.notVerified:
        text = row.verifyMessage ?? 'Vehicle could not be verified';
        color = AppColors.warning;
        break;
      case VerifyState.error:
        text = row.verifyMessage ?? 'Could not verify right now';
        color = AppColors.textMuted;
        break;
      case VerifyState.idle:
        return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, left: 4.0),
      child: Text(
        text,
        style: textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDriverSelector(int index, TextTheme textTheme) {
    final row = _rows[index];
    final label = row.driverLabel;
    return InkWell(
      onTap: () => _selectDriver(index),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.dividerGrey),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16.0,
              backgroundColor: AppColors.offWhite,
              child: Icon(
                label == null ? Icons.person_add_alt : Icons.person,
                size: 18.0,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label ?? 'Select Driver *',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: label == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (row.driverMobile != null && row.driverMobile!.trim().isNotEmpty)
                    Text(
                      row.driverMobile!.trim(),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAnotherButton(TextTheme textTheme) {
    return InkWell(
      onTap: _addRow,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20.0),
            const SizedBox(width: 8.0),
            Text(
              'Add Another Vehicle',
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String text,
    _BannerTone tone = _BannerTone.info,
  }) {
    final Color bg =
        tone == _BannerTone.success ? const Color(0xFFEAF7EE) : const Color(0xFFEFF3FB);
    final Color fg = tone == _BannerTone.success ? AppColors.success : AppColors.info;
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20.0),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.0,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BannerTone { info, success }

/// Bottom sheet to select a driver: import from contacts, enter manually, or
/// pick one of the transporter's existing drivers.
class _DriverSelectSheet extends StatefulWidget {
  const _DriverSelectSheet({required this.vehicleNumber});

  final int vehicleNumber;

  @override
  State<_DriverSelectSheet> createState() => _DriverSelectSheetState();
}

class _DriverSelectSheetState extends State<_DriverSelectSheet> {
  bool _showAll = false;

  Future<void> _importFromContacts() async {
    try {
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission is required to pick from contacts'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;
      String? mobile;
      if (contact.phones.isNotEmpty) {
        final digits = contact.phones.first.number.replaceAll(RegExp(r'[^0-9]'), '');
        mobile = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      }
      Navigator.of(context).pop(
        _DriverSelection(name: contact.displayName, mobile: mobile),
      );
    } catch (e) {
      if (mounted) {
        showUserErrorSnackBar(context, e, fallback: 'Could not pick contact');
      }
    }
  }

  Future<void> _enterManually() async {
    final selection = await showDialog<_DriverSelection>(
      context: context,
      builder: (_) => const _ManualDriverDialog(),
    );
    if (selection != null && mounted) {
      Navigator.of(context).pop(selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Only surface drivers not already assigned to a vehicle. A driver is
    // considered assigned if any vehicle references their id via driverId.
    final assignedDriverIds = context
        .watch<VehicleProvider>()
        .vehicles
        .map((v) => v.driverId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final drivers = context
        .watch<DriverProvider>()
        .drivers
        .where((d) => !assignedDriverIds.contains(d.id))
        .toList();
    final visibleDrivers = _showAll ? drivers : drivers.take(3).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Select Driver for Vehicle ${widget.vehicleNumber}',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildOptionCard(
                    icon: Icons.import_contacts,
                    title: 'Import from Contacts',
                    subtitle: 'Pick driver from your phone contacts',
                    onTap: _importFromContacts,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: _buildOptionCard(
                    icon: Icons.edit_outlined,
                    title: 'Enter Manually',
                    subtitle: 'Add driver name and mobile number',
                    onTap: _enterManually,
                    textTheme: textTheme,
                  ),
                ),
              ],
            ),
          ),
          // Only show "Recent Contacts" when there are unassigned drivers.
          if (drivers.isNotEmpty) ...[
            const SizedBox(height: 20.0),
            Row(
              children: [
                Text(
                  'Recent Contacts',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (drivers.length > 3)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll ? 'Show less' : 'View All'),
                  ),
              ],
            ),
            const SizedBox(height: 4.0),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: visibleDrivers.length,
                separatorBuilder: (_, __) => const Divider(height: 1.0),
                itemBuilder: (context, i) => _buildDriverTile(visibleDrivers[i], textTheme),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverTile(DriverModel driver, TextTheme textTheme) {
    final name = (driver.name?.trim().isNotEmpty == true) ? driver.name!.trim() : 'Driver';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18.0,
        backgroundColor: AppColors.offWhite,
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13.0,
          ),
        ),
      ),
      title: Text(name, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(driver.mobile),
      trailing: TextButton(
        onPressed: () => Navigator.of(context).pop(
          _DriverSelection(driverId: driver.id, name: driver.name, mobile: driver.mobile),
        ),
        child: const Text('Select'),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required TextTheme textTheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.dividerGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22.0),
            const SizedBox(height: 8.0),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small dialog to enter a driver name + mobile manually.
class _ManualDriverDialog extends StatefulWidget {
  const _ManualDriverDialog();

  @override
  State<_ManualDriverDialog> createState() => _ManualDriverDialogState();
}

class _ManualDriverDialogState extends State<_ManualDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(
        _DriverSelection(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Driver'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Driver Name',
                hintText: 'Enter driver name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter driver name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Enter 10-digit mobile number',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter mobile number';
                }
                if (value.trim().length != 10) {
                  return 'Mobile number must be 10 digits';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

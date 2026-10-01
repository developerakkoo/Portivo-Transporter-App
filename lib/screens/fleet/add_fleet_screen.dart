import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/user_feedback.dart';
import '../../core/utils/vehicle_create_payload.dart';
import '../../data/models/driver_already_assigned_exception.dart';
import '../../data/models/driver_model.dart';
import '../../data/models/fleet_import_result.dart';
import '../../data/models/rc_verification.dart';
import '../../data/models/vehicle_model.dart';
import '../../providers/driver_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../services/vehicle_service.dart';
import '../../utils/error_utils.dart';
import '../../widgets/driver_reassign_dialog.dart';
import 'select_vehicle_type_screen.dart';

/// RC verification state for a single vehicle-number field.
enum VerifyState { idle, verifying, verified, notVerified, error }

/// One editable vehicle row in the Add Fleet screen.
class _FleetRow {
  final TextEditingController vehicleNumber = TextEditingController();
  final TextEditingController cargoWeight = TextEditingController();
  final TextEditingController driverNameController = TextEditingController();
  final TextEditingController driverMobileController = TextEditingController();
  final TextEditingController alternateMobile = TextEditingController();
  final TextEditingController licenseNumber = TextEditingController();
  DateTime? licenseValidTill;
  String? vehicleType;
  bool expanded = false;

  // Assigned driver. If [driverId] is set the driver already exists in the app;
  // otherwise name/mobile describe a driver to be created on save.
  String? driverId;
  String? originalAlternateMobile;
  String? originalLicenseNumber;
  DateTime? originalLicenseValidTill;
  bool forceReassign = false;

  // RC verification state (informational; does not block saving).
  VerifyState verify = VerifyState.idle;
  String? verifyMessage;
  String? verifiedNumber; // normalized number that was last verified
  Timer? debounce;
  int verifyToken = 0; // guards against stale/superseded responses

  String? get driverName => driverNameController.text.trim().isEmpty
      ? null
      : driverNameController.text.trim();
  String? get driverMobile => driverMobileController.text.trim().isEmpty
      ? null
      : driverMobileController.text.trim();

  bool get hasDriver =>
      (driverId != null && driverId!.isNotEmpty) ||
      (driverMobile != null && driverMobile!.isNotEmpty);

  String? get driverLabel {
    final name = driverName;
    final mobile = driverMobile;
    if (name != null && mobile != null && mobile.isNotEmpty) {
      return '$name ($mobile)';
    }
    return name ?? mobile;
  }

  void applyDriverSelection(_DriverSelection selection) {
    driverId = selection.driverId;
    driverNameController.text = selection.name ?? '';
    driverMobileController.text = selection.mobile ?? '';
    alternateMobile.text = selection.alternateMobile ?? '';
    licenseNumber.text = selection.licenseNumber ?? '';
    licenseValidTill = selection.licenseValidTill;
    originalAlternateMobile = selection.alternateMobile;
    originalLicenseNumber = selection.licenseNumber;
    originalLicenseValidTill = selection.licenseValidTill;
    forceReassign = selection.forceReassign;
  }

  void clearDriver() {
    driverId = null;
    driverNameController.clear();
    driverMobileController.clear();
    alternateMobile.clear();
    licenseNumber.clear();
    licenseValidTill = null;
    originalAlternateMobile = null;
    originalLicenseNumber = null;
    originalLicenseValidTill = null;
    forceReassign = false;
  }

  void dispose() {
    debounce?.cancel();
    vehicleNumber.dispose();
    cargoWeight.dispose();
    driverNameController.dispose();
    driverMobileController.dispose();
    alternateMobile.dispose();
    licenseNumber.dispose();
  }
}

/// Result of the per-row driver selection sheet.
class _DriverSelection {
  final String? driverId;
  final String? name;
  final String? mobile;
  final String? alternateMobile;
  final String? licenseNumber;
  final DateTime? licenseValidTill;
  final bool forceReassign;

  _DriverSelection({
    this.driverId,
    this.name,
    this.mobile,
    this.alternateMobile,
    this.licenseNumber,
    this.licenseValidTill,
    this.forceReassign = false,
  });
}

class AddFleetScreen extends StatefulWidget {
  const AddFleetScreen({super.key});

  @override
  State<AddFleetScreen> createState() => _AddFleetScreenState();
}

class _AddFleetScreenState extends State<AddFleetScreen> {
  final List<_FleetRow> _rows = [(_FleetRow()..expanded = true)];
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

  void _toggleRow(int index) {
    setState(() {
      final open = !_rows[index].expanded;
      for (var i = 0; i < _rows.length; i++) {
        _rows[i].expanded = open && i == index;
      }
    });
  }

  void _removeRow(int index) {
    if (_rows.length == 1) {
      // Keep at least one row; just clear it.
      setState(() {
        final row = _rows[index];
        row.debounce?.cancel();
        row.vehicleNumber.clear();
        row.cargoWeight.clear();
        row.vehicleType = null;
        row.clearDriver();
        row.verify = VerifyState.idle;
        row.verifyMessage = null;
        row.verifiedNumber = null;
        row.verifyToken++;
        row.expanded = true;
      });
      return;
    }
    final wasExpanded = _rows[index].expanded;
    setState(() {
      _rows.removeAt(index).dispose();
      if (wasExpanded && _rows.isNotEmpty) {
        for (final row in _rows) {
          row.expanded = false;
        }
        _rows[index.clamp(0, _rows.length - 1)].expanded = true;
      }
    });
  }

  Future<void> _selectDriver(int index) async {
    final row = _rows[index];
    final typedNumber = row.vehicleNumber.text.trim();
    final vehicleLabel = typedNumber.isEmpty
        ? 'this vehicle'
        : Validators.normalizeIndianVehicleRegistration(typedNumber);
    final maxHeight = MediaQuery.of(context).size.height * 0.5;
    final selection = await showModalBottomSheet<_DriverSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      constraints: BoxConstraints(maxHeight: maxHeight),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (_) => SizedBox(
        height: maxHeight,
        child: _DriverSelectSheet(
          vehicleNumber: index + 1,
          newVehicleNumber: vehicleLabel,
        ),
      ),
    );

    if (selection == null || !mounted) return;
    setState(() {
      _rows[index].applyDriverSelection(selection);
    });
  }

  Future<void> _addNewDriver(int index) async {
    final selection = await showDialog<_DriverSelection>(
      context: context,
      builder: (_) => const _ManualDriverDialog(),
    );
    if (selection == null || !mounted) return;
    setState(() => _rows[index].applyDriverSelection(selection));
  }

  Future<void> _pickVehicleType(int index) async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SelectVehicleTypeScreen(
          selectedName: _rows[index].vehicleType,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _rows[index].vehicleType = selected);
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
      if (result.isVerified) {
        row.verify = VerifyState.verified;
        row.verifiedNumber = number;
        row.verifyMessage = null;
      } else {
        row.verify = VerifyState.notVerified;
        row.verifiedNumber = null;
        row.verifyMessage = null;
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
        if ((row.driverName ?? '').isEmpty) {
          return 'Vehicle ${i + 1}: please enter driver name';
        }
      }
      final cargoError = Validators.validateOptionalCargoWeightMt(row.cargoWeight.text);
      if (cargoError != null) {
        return 'Vehicle ${i + 1}: $cargoError';
      }
      final altError = Validators.validateOptionalMobile(row.alternateMobile.text);
      if (altError != null) {
        return 'Vehicle ${i + 1}: alternate mobile — $altError';
      }
    }
    return null;
  }

  Future<String?> _resolveDriverId(_FleetRow row, DriverProvider driverProvider) async {
    String? driverId = row.driverId;
    if (driverId != null && driverId.isNotEmpty) {
      await _syncExistingDriverFields(row, driverProvider);
      return driverId;
    }
    if (row.driverMobile == null || row.driverMobile!.trim().isEmpty) {
      return null;
    }

    final mobile = _normalizeMobile(row.driverMobile!);
    final existing =
        driverProvider.drivers.where((d) => d.mobile == mobile).toList();
    if (existing.isNotEmpty) {
      row.driverId = existing.first.id;
      await _syncExistingDriverFields(row, driverProvider);
      return existing.first.id;
    }

    final created = await driverProvider.createDriver(
      mobile: mobile,
      name: (row.driverName ?? '').trim(),
      status: 'active',
      alternateMobile: row.alternateMobile.text.trim().isEmpty
          ? null
          : _normalizeMobile(row.alternateMobile.text),
      licenseNumber: row.licenseNumber.text.trim().isEmpty
          ? null
          : row.licenseNumber.text.trim(),
      licenseValidTill: formatLicenseValidTill(row.licenseValidTill),
    );
    if (created != null) {
      row.driverId = created.id;
      return created.id;
    }

    await driverProvider.loadDrivers(refresh: true);
    final again =
        driverProvider.drivers.where((d) => d.mobile == mobile).toList();
    if (again.isNotEmpty) {
      row.driverId = again.first.id;
      return again.first.id;
    }
    throw Exception(driverProvider.error ?? 'Failed to create driver');
  }

  Future<void> _syncExistingDriverFields(
    _FleetRow row,
    DriverProvider driverProvider,
  ) async {
    final id = row.driverId;
    if (id == null || id.isEmpty) return;
    final alt = row.alternateMobile.text.trim();
    final license = row.licenseNumber.text.trim();
    final till = formatLicenseValidTill(row.licenseValidTill);
    final originalTill = formatLicenseValidTill(row.originalLicenseValidTill);
    final changed = alt != (row.originalAlternateMobile ?? '') ||
        license != (row.originalLicenseNumber ?? '') ||
        till != originalTill;
    if (!changed) return;
    await driverProvider.updateDriver(
      id: id,
      name: row.driverName,
      alternateMobile: alt.isEmpty ? '' : _normalizeMobile(alt),
      licenseNumber: license,
      licenseValidTill: till ?? '',
    );
  }

  Future<FleetImportRowResult> _createVehicleForRow({
    required int rowNum,
    required _FleetRow row,
    required String driverId,
    bool forceReassign = false,
  }) async {
    final normalizedNumber =
        Validators.normalizeIndianVehicleRegistration(row.vehicleNumber.text);
    final cargo = Validators.parseOptionalCargoWeightMt(row.cargoWeight.text);
    final vehicleData = buildVehicleCreatePayload(
      vehicleNumber: normalizedNumber,
      vehicleType: row.vehicleType!,
      driverId: driverId,
      cargoWeightMt: cargo,
      forceReassign: forceReassign,
    );
    final created = await _vehicleService.createVehicle(vehicleData);
    return FleetImportRowResult(
      row: rowNum,
      success: created != null,
      vehicleNumber: normalizedNumber,
      vehicleId: created?.vehicle.id,
      driverId: driverId,
      rcStatus: created?.verification?.status,
    );
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
        final driverId = await _resolveDriverId(row, driverProvider);
        if (driverId == null) {
          throw Exception('Driver is required');
        }
        results.add(await _createVehicleForRow(
          rowNum: rowNum,
          row: row,
          driverId: driverId,
          forceReassign: row.forceReassign,
        ));
      } on DriverAlreadyAssignedException catch (conflict) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        final move = await showDriverReassignDialog(
          context: context,
          conflict: conflict,
          newVehicleNumber: normalizedNumber,
        );
        if (!mounted) return;
        if (!move) {
          results.add(FleetImportRowResult(
            row: rowNum,
            success: false,
            vehicleNumber: normalizedNumber,
            error: 'Driver reassignment cancelled',
          ));
          setState(() => _isSaving = true);
          continue;
        }
        setState(() => _isSaving = true);
        try {
          final driverId = row.driverId ?? conflict.driverId;
          if (driverId == null) {
            throw Exception('Driver is required');
          }
          results.add(await _createVehicleForRow(
            rowNum: rowNum,
            row: row,
            driverId: driverId,
            forceReassign: true,
          ));
        } catch (e) {
          results.add(FleetImportRowResult(
            row: rowNum,
            success: false,
            vehicleNumber: normalizedNumber,
            error: _humanizeError(e),
          ));
        }
      } catch (e) {
        results.add(FleetImportRowResult(
          row: rowNum,
          success: false,
          vehicleNumber: normalizedNumber,
          error: _humanizeError(e),
        ));
      }
    }

    await vehicleProvider.loadVehicles(refresh: true);
    await driverProvider.loadDrivers(refresh: true);

    if (!mounted) return;
    setState(() => _isSaving = false);

    final succeeded = results.where((r) => r.success).length;
    final failed = results.length - succeeded;

    if (succeeded > 0 && failed == 0) {
      final warning = _rcWarning(results);
      showUserSuccessSnackBar(
        context,
        warning == null
            ? (succeeded == 1
                ? 'Vehicle created successfully'
                : '$succeeded vehicles added to your fleet')
            : (succeeded == 1
                ? 'Vehicle created successfully. $warning'
                : '$succeeded vehicles added to your fleet. $warning'),
      );
      Navigator.of(context).pop();
      return;
    }

    final summary = FleetImportResult(
      total: results.length,
      succeeded: succeeded,
      failed: failed,
      results: results,
    );
    await _showResultsDialog(summary, title: 'Save Fleet');

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

  String? _rcWarning(List<FleetImportRowResult> results) {
    final labels = <String>{};
    for (final result in results) {
      if (!result.success) continue;
      final status = result.rcStatus?.toLowerCase();
      if (status == null || status == 'verified') continue;
      final label = rcStatusLabel(status);
      if (label.startsWith('Vehicle saved. ')) {
        labels.add(label.substring('Vehicle saved. '.length));
      } else {
        labels.add(label);
      }
    }
    if (labels.isEmpty) return null;
    return labels.join(' ');
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
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          children: [
            _buildInfoBanner(
              icon: Icons.info_outline,
              text:
                  'Add your own vehicles and regular drivers. You can also add hired vehicles while creating a trip.',
            ),
            const SizedBox(height: 12.0),
            ...List.generate(_rows.length, (i) => _buildVehicleCard(i, textTheme)),
            _buildAddAnotherButton(textTheme),
            const SizedBox(height: 12.0),
            _buildInfoBanner(
              icon: Icons.verified_user_outlined,
              text:
                  'Drivers will be able to login to the Porttivo Driver App using their registered mobile number.',
              tone: _BannerTone.success,
            ),
            const SizedBox(height: 12.0),
            SizedBox(
              height: 48.0,
              child: ElevatedButton(
                onPressed: _isSaving || _isImporting ? null : _saveFleet,
                child: _isSaving
                    ? const SizedBox(
                        height: 20.0,
                        width: 20.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.background),
                        ),
                      )
                    : Text(
                        'Save Fleet Details',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(int index, TextTheme textTheme) {
    final row = _rows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.fromLTRB(12.0, 4.0, 8.0, 12.0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleRow(index),
            borderRadius: BorderRadius.circular(10.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Container(
                    width: 22.0,
                    height: 22.0,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Vehicle ${index + 1}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (row.expanded)
                    IconButton(
                      onPressed: () => _removeRow(index),
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      tooltip: 'Remove vehicle',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
                    )
                  else
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          if (row.expanded) ...[
            _sectionTitle('Vehicle Details', textTheme),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _vehicleNumberField(index, textTheme)),
                const SizedBox(width: 8.0),
                Expanded(child: _vehicleTypeField(index, textTheme)),
              ],
            ),
            _buildVerifyStatus(row, textTheme),
            const SizedBox(height: 8.0),
            _labeledField(
              textTheme,
              label: 'Cargo Weight (MT)',
              child: TextField(
                controller: row.cargoWeight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: _fieldTextStyle(textTheme),
                decoration: _compactDecoration(hint: 'Optional').copyWith(
                  suffixText: 'MT',
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            _sectionTitle('Driver Details', textTheme),
            _fieldLabel('Select Driver *', textTheme),
            Row(
              children: [
                Expanded(child: _buildDriverSelector(index, textTheme)),
                const SizedBox(width: 6.0),
                TextButton.icon(
                  onPressed: () => _addNewDriver(index),
                  icon: const Icon(Icons.person_add_alt, size: 16.0),
                  label: const Text('Add New Driver'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    minimumSize: const Size(0, 40.0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 14.0, color: AppColors.textSecondary),
                SizedBox(width: 6.0),
                Expanded(
                  child: Text(
                    'Driver details will auto-fill when you select a driver.',
                    style: TextStyle(
                      fontSize: 11.0,
                      height: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _labeledField(
                    textTheme,
                    label: 'Driver Mobile Number',
                    child: TextField(
                      controller: row.driverMobileController,
                      keyboardType: TextInputType.phone,
                      readOnly: row.driverId != null,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: _fieldTextStyle(textTheme),
                      decoration: _compactDecoration(
                        hint: 'Mobile number',
                        prefixIcon: Icons.phone_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: _labeledField(
                    textTheme,
                    label: 'Alternate Number (Optional)',
                    child: TextField(
                      controller: row.alternateMobile,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: _fieldTextStyle(textTheme),
                      decoration: _compactDecoration(
                        hint: 'Optional',
                        prefixIcon: Icons.phone_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _labeledField(
                    textTheme,
                    label: 'License Number (Optional)',
                    child: TextField(
                      controller: row.licenseNumber,
                      textCapitalization: TextCapitalization.characters,
                      style: _fieldTextStyle(textTheme),
                      decoration: _compactDecoration(
                        hint: 'Optional',
                        prefixIcon: Icons.badge_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: _labeledField(
                    textTheme,
                    label: 'License Valid Till (Optional)',
                    child: InkWell(
                      onTap: () => _pickLicenseDate(index),
                      borderRadius: BorderRadius.circular(8.0),
                      child: InputDecorator(
                        decoration: _compactDecoration(
                          prefixIcon: Icons.calendar_today_outlined,
                        ),
                        child: Text(
                          row.licenseValidTill == null
                              ? 'Select date'
                              : DateFormat('dd MMM yyyy').format(row.licenseValidTill!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _fieldTextStyle(textTheme).copyWith(
                            color: row.licenseValidTill == null
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _vehicleNumberField(int index, TextTheme textTheme) {
    final row = _rows[index];
    return _labeledField(
      textTheme,
      label: 'Vehicle Number *',
      child: TextField(
        controller: row.vehicleNumber,
        textCapitalization: TextCapitalization.characters,
        maxLength: 10,
        onChanged: (value) => _onVehicleNumberChanged(index, value),
        style: _fieldTextStyle(textTheme),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(10),
          TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(
                text: newValue.text.toUpperCase(),
                selection: newValue.selection,
              )),
        ],
        decoration: _compactDecoration(
          hint: 'MH12AB3434',
          suffixIcon: _buildVerifySuffixIcon(row),
        ),
      ),
    );
  }

  InputDecoration _compactDecoration({
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    const radius = BorderRadius.all(Radius.circular(8.0));
    const borderSide = BorderSide(color: AppColors.dividerGrey);
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 16.0, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 28.0, minHeight: 32.0),
      suffixIconConstraints: const BoxConstraints(minWidth: 28.0, minHeight: 32.0),
      border: const OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      enabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }

  Widget? _buildVerifySuffixIcon(_FleetRow row) {
    switch (row.verify) {
      case VerifyState.verifying:
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            height: 14.0,
            width: 14.0,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        );
      case VerifyState.verified:
        return const Icon(Icons.verified, size: 16.0, color: AppColors.success);
      case VerifyState.notVerified:
        return const Icon(Icons.error_outline, size: 16.0, color: AppColors.warning);
      case VerifyState.error:
        return const Icon(Icons.cloud_off_outlined, size: 16.0, color: AppColors.textMuted);
      case VerifyState.idle:
        return null;
    }
  }

  Widget _vehicleTypeField(int index, TextTheme textTheme) {
    final type = _rows[index].vehicleType?.trim();
    final hasType = type != null && type.isNotEmpty;
    return _labeledField(
      textTheme,
      label: 'Vehicle / Body Type *',
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          onTap: () => _pickVehicleType(index),
          borderRadius: BorderRadius.circular(8.0),
          child: InputDecorator(
            decoration: _compactDecoration().copyWith(
              prefixIcon: const Icon(
                Icons.local_shipping_outlined,
                size: 16.0,
                color: AppColors.textSecondary,
              ),
              suffixIcon: const Icon(
                Icons.chevron_right,
                size: 18.0,
                color: AppColors.textSecondary,
              ),
            ),
            child: Text(
              hasType ? type : 'Select vehicle type',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _fieldTextStyle(textTheme).copyWith(
                color: hasType ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: textTheme.titleSmall?.copyWith(
          fontSize: 13.0,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelSmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _labeledField(
    TextTheme textTheme, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, textTheme),
        child,
      ],
    );
  }

  TextStyle _fieldTextStyle(TextTheme textTheme) {
    return textTheme.bodySmall?.copyWith(
          fontSize: 12.0,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(fontSize: 12.0, color: AppColors.textPrimary);
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
      case VerifyState.error:
        text = 'RC check unavailable. You can still save.';
        color = AppColors.warning;
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

  Future<void> _pickLicenseDate(int index) async {
    final initial = _rows[index].licenseValidTill ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _rows[index].licenseValidTill = picked);
  }

  Widget _buildDriverSelector(int index, TextTheme textTheme) {
    final row = _rows[index];
    final label = row.driverLabel;
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8.0),
      child: InkWell(
        onTap: () => _selectDriver(index),
        borderRadius: BorderRadius.circular(8.0),
        child: InputDecorator(
          decoration: _compactDecoration(
            prefixIcon: Icons.person_outline,
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18.0,
              color: AppColors.textSecondary,
            ),
          ),
          child: Text(
            label ?? 'Select driver',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _fieldTextStyle(textTheme).copyWith(
              color: label == null ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddAnotherButton(TextTheme textTheme) {
    return InkWell(
      onTap: _addRow,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
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
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
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

/// Compact sheet to select a driver: search existing, import, or create new.
class _DriverSelectSheet extends StatefulWidget {
  const _DriverSelectSheet({
    required this.vehicleNumber,
    required this.newVehicleNumber,
  });

  final int vehicleNumber;
  final String newVehicleNumber;

  @override
  State<_DriverSelectSheet> createState() => _DriverSelectSheetState();
}

class _DriverSelectSheetState extends State<_DriverSelectSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

  Future<void> _pickExisting(DriverModel driver, VehicleModel? assignedVehicle) async {
    var forceReassign = false;
    if (assignedVehicle != null) {
      final move = await showDriverReassignDialog(
        context: context,
        conflict: DriverAlreadyAssignedException(
          driverId: driver.id,
          driverName: driver.name,
          driverMobile: driver.mobile,
          currentVehicleId: assignedVehicle.id,
          currentVehicleNumber: assignedVehicle.vehicleNumber,
          currentVehicleType: assignedVehicle.vehicleType,
          currentCargoWeightMt: assignedVehicle.cargoWeightMt,
        ),
        newVehicleNumber: widget.newVehicleNumber,
      );
      if (!move || !mounted) return;
      forceReassign = true;
    }
    Navigator.of(context).pop(
      _DriverSelection(
        driverId: driver.id,
        name: driver.name,
        mobile: driver.mobile,
        alternateMobile: driver.alternateMobile,
        licenseNumber: driver.licenseNumber,
        licenseValidTill: driver.licenseValidTill,
        forceReassign: forceReassign,
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final vehicles = context.watch<VehicleProvider>().vehicles;
    final assignedByDriverId = <String, VehicleModel>{};
    for (final v in vehicles) {
      final id = v.driverId;
      if (id != null && id.isNotEmpty) {
        assignedByDriverId[id] = v;
      }
    }
    final query = _search.text.trim().toLowerCase();
    final drivers = context.watch<DriverProvider>().drivers.where((d) {
      if (query.isEmpty) return true;
      final name = (d.name ?? '').toLowerCase();
      return name.contains(query) || d.mobile.contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Driver for Vehicle ${widget.vehicleNumber}',
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search name or mobile',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.import_contacts, color: AppColors.primary),
              title: const Text('Add from contacts'),
              onTap: _importFromContacts,
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_add_alt, color: AppColors.primary),
              title: const Text('Create new driver'),
              onTap: _enterManually,
            ),
            if (drivers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  query.isEmpty ? 'No drivers yet' : 'No matching drivers',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: drivers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final driver = drivers[i];
                    final assignedVehicle = assignedByDriverId[driver.id];
                    final name = (driver.name?.trim().isNotEmpty == true)
                        ? driver.name!.trim()
                        : 'Driver';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.offWhite,
                        child: Text(
                          _initials(name),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        assignedVehicle != null
                            ? '${driver.mobile}  ·  Assigned to ${assignedVehicle.vehicleNumber}'
                            : driver.mobile,
                      ),
                      trailing: assignedVehicle == null
                          ? TextButton(
                              onPressed: () => _pickExisting(driver, null),
                              child: const Text('Select'),
                            )
                          : TextButton(
                              onPressed: () => _pickExisting(driver, assignedVehicle),
                              child: const Text('Assigned'),
                            ),
                    );
                  },
                ),
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

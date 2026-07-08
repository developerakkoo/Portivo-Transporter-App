import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';

/// Editable route row on the Post/Edit Availability forms. A null rate with its
/// negotiable flag set means "Rate on Request" for that direction.
class RouteDraft {
  RouteDraft({
    required this.destination,
    this.exportRate,
    this.importRate,
  });

  String destination;
  num? exportRate;
  num? importRate;

  bool get exportNegotiable => exportRate == null;
  bool get importNegotiable => importRate == null;
}

/// Shows the add/edit route bottom sheet. Returns null if dismissed.
Future<RouteDraft?> showRouteRateEditor(
  BuildContext context, {
  RouteDraft? initial,
}) {
  return showModalBottomSheet<RouteDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => RouteRateEditorSheet(initial: initial),
  );
}

/// Bottom sheet to add or edit a route with per-direction (Export/Import) rates.
class RouteRateEditorSheet extends StatefulWidget {
  const RouteRateEditorSheet({super.key, this.initial});

  final RouteDraft? initial;

  @override
  State<RouteRateEditorSheet> createState() => _RouteRateEditorSheetState();
}

class _RouteRateEditorSheetState extends State<RouteRateEditorSheet> {
  final _sheetFormKey = GlobalKey<FormState>();
  late final TextEditingController _destCtrl;
  late final TextEditingController _exportCtrl;
  late final TextEditingController _importCtrl;
  late bool _exportNegotiable;
  late bool _importNegotiable;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _destCtrl = TextEditingController(text: init?.destination ?? '');
    _exportNegotiable = init?.exportNegotiable ?? false;
    _importNegotiable = init?.importNegotiable ?? false;
    _exportCtrl = TextEditingController(
      text: init?.exportRate?.toString() ?? '',
    );
    _importCtrl = TextEditingController(
      text: init?.importRate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _exportCtrl.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_sheetFormKey.currentState!.validate()) return;
    final dest = _destCtrl.text.trim();
    if (dest.isEmpty) return;
    num? exportRate;
    num? importRate;
    if (!_exportNegotiable) {
      exportRate = Validators.parseOptionalListingPriceInr(_exportCtrl.text);
    }
    if (!_importNegotiable) {
      importRate = Validators.parseOptionalListingPriceInr(_importCtrl.text);
    }
    Navigator.pop(
      context,
      RouteDraft(
        destination: dest,
        exportRate: exportRate,
        importRate: importRate,
      ),
    );
  }

  Widget _rateField({
    required String label,
    required TextEditingController controller,
    required bool negotiable,
    required ValueChanged<bool> onNegotiableChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g. 45000',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.validateOptionalListingPriceInr,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Negotiable'),
                Switch(
                  value: negotiable,
                  onChanged: onNegotiableChanged,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + bottomInset,
      ),
      child: Form(
        key: _sheetFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initial == null ? 'Add Route' : 'Edit Route',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _destCtrl,
              decoration: const InputDecoration(
                labelText: 'Destination *',
                hintText: 'City or delivery point',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a destination' : null,
            ),
            const SizedBox(height: 16),
            _rateField(
              label: 'Export Rate',
              controller: _exportCtrl,
              negotiable: _exportNegotiable,
              onNegotiableChanged: (v) => setState(() => _exportNegotiable = v),
            ),
            const SizedBox(height: 16),
            _rateField(
              label: 'Import Rate',
              controller: _importCtrl,
              negotiable: _importNegotiable,
              onNegotiableChanged: (v) => setState(() => _importNegotiable = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Route'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../providers/requirement_provider.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';

/// Reverse-marketplace "Post Inquiry" form. Prefilled from the network search
/// so a requester can broadcast their requirement to matching transporters.
class PostInquiryScreen extends StatefulWidget {
  const PostInquiryScreen({
    super.key,
    this.origin,
    this.destination,
    this.vehicleType,
    this.date,
  });

  final String? origin;
  final String? destination;
  final String? vehicleType;
  final DateTime? date;

  @override
  State<PostInquiryScreen> createState() => _PostInquiryScreenState();
}

class _PostInquiryScreenState extends State<PostInquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _originCtrl;
  late final TextEditingController _destCtrl;
  final _remarksCtrl = TextEditingController();
  final _vehiclesCtrl = TextEditingController(text: '1');

  String? _vehicleType;
  String _direction = 'EXPORT';
  DateTime? _requiredBy;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _originCtrl = TextEditingController(text: widget.origin ?? '');
    _destCtrl = TextEditingController(text: widget.destination ?? '');
    _vehicleType = widget.vehicleType;
    _requiredBy = widget.date;
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _remarksCtrl.dispose();
    _vehiclesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRequiredBy() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredBy ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _requiredBy = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehicleType == null || _vehicleType!.trim().isEmpty) {
      showUserErrorSnackBar(context, null, fallback: 'Select a vehicle type');
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<RequirementProvider>().create(
            origin: _originCtrl.text.trim(),
            destination: _destCtrl.text.trim(),
            vehicleType: _vehicleType!.trim(),
            direction: _direction,
            noOfVehicles: int.tryParse(_vehiclesCtrl.text.trim()) ?? 1,
            requiredBy: _requiredBy,
            remarks: _remarksCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showUserErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _requiredBy != null
        ? DateFormat('EEE, d MMM yyyy').format(_requiredBy!)
        : 'Any date';
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Post Inquiry'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: AppColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Transporters with matching vehicles on this route will be '
                      'notified and can send you quotes.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label('Pickup / Origin'),
            _field(_originCtrl, hint: 'e.g. Nhava Sheva Port', required: true),
            const SizedBox(height: 16),
            _label('Drop / Destination'),
            _field(_destCtrl, hint: 'e.g. Pune', required: true),
            const SizedBox(height: 16),
            _label('Vehicle Type'),
            SearchableVehicleTypePicker(
              value: _vehicleType,
              labelText: 'Vehicle Type *',
              onChanged: (v) => setState(() => _vehicleType = v),
            ),
            const SizedBox(height: 16),
            _label('Direction'),
            _directionSelector(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('No. of Vehicles'),
                      _field(
                        _vehiclesCtrl,
                        hint: '1',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Required By'),
                      InkWell(
                        onTap: _pickRequiredBy,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 15),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.dividerGrey),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _requiredBy != null
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Remarks (optional)'),
            _field(
              _remarksCtrl,
              hint: 'Any specific requirements, cargo details, timing…',
              maxLines: 3,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Post Inquiry',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _field(
    TextEditingController ctrl, {
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dividerGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dividerGrey),
        ),
      ),
    );
  }

  Widget _directionSelector() {
    const options = ['EXPORT', 'IMPORT', 'LOCAL'];
    return Row(
      children: [
        for (final o in options)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: o == 'LOCAL' ? 0 : 8),
              child: ChoiceChip(
                label: Text(o[0] + o.substring(1).toLowerCase()),
                selected: _direction == o,
                onSelected: (_) => setState(() => _direction = o),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _direction == o ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.dividerGrey),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

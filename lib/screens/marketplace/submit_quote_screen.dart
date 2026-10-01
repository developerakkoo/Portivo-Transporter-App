import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/requirement_model.dart';
import '../../services/quote_service.dart';

/// Transporter submits (or updates) a quote for an inquiry.
class SubmitQuoteScreen extends StatefulWidget {
  const SubmitQuoteScreen({
    super.key,
    required this.requirement,
    this.initialPrice,
  });

  final RequirementModel requirement;
  final num? initialPrice;

  @override
  State<SubmitQuoteScreen> createState() => _SubmitQuoteScreenState();
}

class _SubmitQuoteScreenState extends State<SubmitQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final QuoteService _service = QuoteService();
  late final TextEditingController _priceCtrl;
  final _messageCtrl = TextEditingController();

  String _availability = 'TODAY';
  DateTime? _customDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.initialPrice != null ? widget.initialPrice.toString() : '',
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _availability = 'CUSTOM';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_availability == 'CUSTOM' && _customDate == null) {
      showUserErrorSnackBar(context, null, fallback: 'Pick a custom date');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.submit(
        requirementId: widget.requirement.id,
        price: num.parse(_priceCtrl.text.trim()),
        availability: _availability,
        availabilityDate: _availability == 'CUSTOM' ? _customDate : null,
        message: _messageCtrl.text.trim(),
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
    final r = widget.requirement;
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Submit Quote'),
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
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dividerGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.origin}  →  ${r.destination}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.vehicleType} · ${r.direction} · ${r.noOfVehicles} vehicle(s)',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Price (₹)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a price';
                final n = num.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: 'e.g. 18000',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dividerGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dividerGrey),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Availability',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _availChip('TODAY', 'Today'),
                const SizedBox(width: 8),
                _availChip('TOMORROW', 'Tomorrow'),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickCustomDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _availability == 'CUSTOM'
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.dividerGrey),
                      ),
                      child: Text(
                        _availability == 'CUSTOM' && _customDate != null
                            ? DateFormat('d MMM').format(_customDate!)
                            : 'Custom',
                        style: TextStyle(
                          color: _availability == 'CUSTOM'
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Message (optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a note for the requester…',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dividerGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dividerGrey),
                ),
              ),
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
                        'Submit Quote',
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

  Widget _availChip(String value, String label) {
    final selected = _availability == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _availability = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.dividerGrey),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/vehicle_type_photo_catalog.dart';

/// Full-screen photo picker for a vehicle / body type.
///
/// Pops with the selected catalog [VehicleTypePhoto.name].
class SelectVehicleTypeScreen extends StatefulWidget {
  const SelectVehicleTypeScreen({super.key, this.selectedName});

  final String? selectedName;

  @override
  State<SelectVehicleTypeScreen> createState() => _SelectVehicleTypeScreenState();
}

class _SelectVehicleTypeScreenState extends State<SelectVehicleTypeScreen> {
  final TextEditingController _search = TextEditingController();
  VehiclePhotoCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<VehicleTypePhoto> get _visible {
    final query = _search.text.trim().toLowerCase();
    return vehicleTypePhotos.where((photo) {
      if (_category != null && photo.category != _category) return false;
      return photo.matches(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visible = _visible;
    final sections = VehiclePhotoCategory.values
        .map((category) {
          final items = visible.where((p) => p.category == category).toList();
          return (category: category, items: items);
        })
        .where((section) => section.items.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Vehicle Type'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search vehicle type (e.g. 40 ft, reefer, axle)',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip(label: 'All', selected: _category == null, onTap: () {
                  setState(() => _category = null);
                }),
                for (final category in VehiclePhotoCategory.values)
                  _chip(
                    label: category.label,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sections.isEmpty
                ? Center(
                    child: Text(
                      'No vehicle types match',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final section in sections) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 10),
                          child: Text(
                            '${section.category.label} (${section.items.length})',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: section.items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                          itemBuilder: (context, index) {
                            return _TypeCard(
                              photo: section.items[index],
                              selected:
                                  section.items[index].name == widget.selectedName,
                              onTap: () => Navigator.of(context)
                                  .pop(section.items[index].name),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.background : AppColors.textPrimary,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.background,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.dividerGrey,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.photo,
    required this.selected,
    required this.onTap,
  });

  final VehicleTypePhoto photo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.dividerGrey,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: AppColors.offWhite,
                  child: Image.asset(
                    photo.asset,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                photo.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                photo.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

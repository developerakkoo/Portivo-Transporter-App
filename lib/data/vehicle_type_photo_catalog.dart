/// Photo catalog for the Add Fleet vehicle-type picker.
///
/// [name] is the exact string saved as `vehicleType` and must exist in the
/// API vehicle-type catalog.
enum VehiclePhotoCategory { container, truck }

extension VehiclePhotoCategoryX on VehiclePhotoCategory {
  String get label {
    switch (this) {
      case VehiclePhotoCategory.container:
        return 'Container';
      case VehiclePhotoCategory.truck:
        return 'Truck';
    }
  }
}

class VehicleTypePhoto {
  final String name;
  final String title;
  final String subtitle;
  final String asset;
  final VehiclePhotoCategory category;

  const VehicleTypePhoto({
    required this.name,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.category,
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final haystack = '$name $title $subtitle ${category.label}'.toLowerCase();
    return haystack.contains(query);
  }
}

const List<VehicleTypePhoto> vehicleTypePhotos = [
  VehicleTypePhoto(
    name: '20 FT Container 2 Axle',
    title: '20 FT Container',
    subtitle: '2 Axle',
    asset: 'assets/vehicle_types/20ft_container_2_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '20 FT Container 3 Axle',
    title: '20 FT Container',
    subtitle: '3 Axle',
    asset: 'assets/vehicle_types/20ft_container_3_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '40 FT Container 2 Axle',
    title: '40 FT Container',
    subtitle: '2 Axle',
    asset: 'assets/vehicle_types/40ft_container_2_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '40 FT Container 3 Axle',
    title: '40 FT Container',
    subtitle: '3 Axle',
    asset: 'assets/vehicle_types/40ft_container_3_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '20 FT Reefer 2 Axle',
    title: '20 FT Reefer',
    subtitle: '2 Axle',
    asset: 'assets/vehicle_types/20ft_reefer_2_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '20 FT Reefer 3 Axle',
    title: '20 FT Reefer',
    subtitle: '3 Axle',
    asset: 'assets/vehicle_types/20ft_reefer_3_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '40 FT Reefer 2 Axle',
    title: '40 FT Reefer',
    subtitle: '2 Axle',
    asset: 'assets/vehicle_types/40ft_reefer_2_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '40 FT Reefer 3 Axle',
    title: '40 FT Reefer',
    subtitle: '3 Axle',
    asset: 'assets/vehicle_types/40ft_reefer_3_axle.jpg',
    category: VehiclePhotoCategory.container,
  ),
  VehicleTypePhoto(
    name: '20 FT Closed Body Single Axle',
    title: '20 FT Closed Body',
    subtitle: 'Single Axle',
    asset: 'assets/vehicle_types/20ft_closed_body_single_axle.jpg',
    category: VehiclePhotoCategory.truck,
  ),
  VehicleTypePhoto(
    name: '20 FT Closed Body 2 Axle',
    title: '20 FT Closed Body',
    subtitle: '2 Axle',
    asset: 'assets/vehicle_types/20ft_closed_body_2_axle.jpg',
    category: VehiclePhotoCategory.truck,
  ),
  VehicleTypePhoto(
    name: '20 FT Closed Body 3 Axle',
    title: '20 FT Closed Body',
    subtitle: '3 Axle',
    asset: 'assets/vehicle_types/20ft_closed_body_3_axle.jpg',
    category: VehiclePhotoCategory.truck,
  ),
];

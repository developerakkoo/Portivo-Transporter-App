/// Label for extra vehicles beyond the first plate shown on a trip card.
String extraVehiclesLabel(int extraCount) {
  if (extraCount <= 0) return '';
  if (extraCount == 1) return '+1 more vehicle';
  return '+$extraCount more vehicles';
}

class VehicleOverflow {
  const VehicleOverflow({this.primary, this.extraCount = 0});

  final String? primary;
  final int extraCount;

  String? get extraLabel => extraVehiclesLabel(extraCount);
}

/// Unique vehicle plates on a single trip document (primary + assignments).
VehicleOverflow vehicleOverflowFromPlates(Iterable<String?> plates) {
  final unique = <String>[];
  for (final raw in plates) {
    final plate = raw?.trim() ?? '';
    if (plate.isEmpty) continue;
    if (!unique.contains(plate)) unique.add(plate);
  }
  if (unique.isEmpty) return const VehicleOverflow();
  return VehicleOverflow(
    primary: unique.first,
    extraCount: unique.length - 1,
  );
}

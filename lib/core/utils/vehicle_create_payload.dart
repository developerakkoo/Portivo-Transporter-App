/// Builds POST /api/vehicles bodies. [forceReassign] is omitted unless true.
Map<String, dynamic> buildVehicleCreatePayload({
  required String vehicleNumber,
  required String vehicleType,
  required String driverId,
  String ownerType = 'OWN',
  num? cargoWeightMt,
  bool forceReassign = false,
  String? trailerType,
}) {
  return <String, dynamic>{
    'vehicleNumber': vehicleNumber,
    'vehicleType': vehicleType,
    'driverId': driverId,
    'ownerType': ownerType,
    if (cargoWeightMt != null) 'cargoWeightMt': cargoWeightMt,
    if (trailerType != null && trailerType.trim().isNotEmpty)
      'trailerType': trailerType.trim(),
    if (forceReassign) 'forceReassign': true,
  };
}

String? formatLicenseValidTill(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

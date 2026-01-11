enum DriverStatus {
  active,
  notInstalled,
  pending,
}

class Driver {
  final String id;
  final String name;
  final String phone;
  final DriverStatus status;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
  });

  String get statusLabel {
    switch (status) {
      case DriverStatus.active:
        return 'Active';
      case DriverStatus.notInstalled:
        return 'Not Installed';
      case DriverStatus.pending:
        return 'Pending';
    }
  }
}


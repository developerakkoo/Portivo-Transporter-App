class AppConstants {
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String transporterIdKey = 'transporter_id';
  
  // Trip Status (aligned with backend TRIP_STATUS)
  static const String tripStatusBooked = 'BOOKED';
  static const String tripStatusAccepted = 'ACCEPTED';
  static const String tripStatusPlanned = 'PLANNED';
  static const String tripStatusActive = 'ACTIVE';
  static const String tripStatusCompleted = 'COMPLETED';
  static const String tripStatusPodPending = 'POD_PENDING';
  static const String tripStatusClosedWithPOD = 'CLOSED_WITH_POD';
  static const String tripStatusClosedWithoutPOD = 'CLOSED_WITHOUT_POD';
  static const String tripStatusCancelled = 'CANCELLED';

  /// Trips tab key: marketplace list (customer offers), not the same as DB status [tripStatusBooked]
  static const String tripTabMarketplace = 'TRIP_TAB_MARKETPLACE';

  /// Statuses that belong in the Completed tab (backend uses CLOSED_WITH_POD, not COMPLETED)
  static const List<String> tripStatusesCompleted = [
    tripStatusCompleted,
    tripStatusClosedWithPOD,
    tripStatusClosedWithoutPOD,
  ];
  
  // Trip Types
  static const String tripTypeImport = 'IMPORT';
  static const String tripTypeExport = 'EXPORT';
  static const String tripTypeLocal = 'LOCAL';
  
  // Vehicle Owner Types
  static const String vehicleOwnerOwn = 'OWN';
  static const String vehicleOwnerHired = 'HIRED';
  
  // Driver Status
  static const String driverStatusPending = 'pending';
  static const String driverStatusActive = 'active';
  static const String driverStatusInactive = 'inactive';
  static const String driverStatusBlocked = 'blocked';
  
  // Fuel Card Status
  static const String fuelCardStatusActive = 'active';
  static const String fuelCardStatusInactive = 'inactive';
  static const String fuelCardStatusBlocked = 'blocked';
  static const String fuelCardStatusExpired = 'expired';
  
  // Transaction Status
  static const String transactionStatusPending = 'pending';
  static const String transactionStatusConfirmed = 'confirmed';
  static const String transactionStatusCompleted = 'completed';
  static const String transactionStatusCancelled = 'cancelled';
  static const String transactionStatusFlagged = 'flagged';
}

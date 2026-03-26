class ApiConfig {
  // Base URL - Update this to your backend server URL
  static const String baseUrl = 'https://api.port.porttivo.com/api';
  // static const String baseUrl = 'http://192.168.1.15:3000/api';

  /// Socket.IO server origin (no path). If empty, derived from [baseUrl] by removing `/api`.
  /// Set this when real-time runs on a different host than REST (e.g. `https://ws.example.com`).
  static const String socketBaseUrlOverride = '';

  /// Socket.IO path (must match server; default is `/socket.io`).
  static const String socketPath = '/socket.io';
  
  // API Endpoints
  static const String register = '/auth/register';
  static const String sendOTP = '/auth/send-otp';
  static const String pinLogin = '/auth/pin-login';
  static const String companyUserLogin = '/auth/company-user-login';
  static const String refreshToken = '/auth/refresh';
  
  // Transporter endpoints
  static const String transporterProfile = '/transporters/profile';
  static const String transporterSetPin = '/transporters/set-pin';
  static const String transporterDashboard = '/transporters/dashboard';
  
  // Driver endpoints
  static const String drivers = '/drivers';
  static String driverById(String id) => '/drivers/$id';
  static String getDriversByTransporter(String transporterId) => '/drivers/transporter/$transporterId';
  static const String driverProfile = '/drivers/profile';
  static const String driverLanguage = '/drivers/language';
  
  // Vehicle endpoints
  static const String vehicles = '/vehicles';
  static String vehicleById(String id) => '/vehicles/$id';
  static String vehicleAvailability(String id) => '/vehicles/$id/availability';
  static String vehicleDocuments(String id) => '/vehicles/$id/documents';
  
  // Trip endpoints
  static const String trips = '/trips';
  static String tripById(String id) => '/trips/$id';
  static String updateTrip(String id) => '/trips/$id';
  static String tripCancel(String id) => '/trips/$id/cancel';
  static String tripStart(String id) => '/trips/$id/start';
  static String tripComplete(String id) => '/trips/$id/complete';
  static String tripMilestone(String id, int milestoneNumber) => '/trips/$id/milestones/$milestoneNumber';
  static String tripCurrentMilestone(String id) => '/trips/$id/current-milestone';
  static String tripTimeline(String id) => '/trips/$id/timeline';
  static String tripPOD(String id) => '/trips/$id/pod';
  static String tripPODApprove(String id) => '/trips/$id/pod/approve';
  static String tripCloseWithoutPOD(String id) => '/trips/$id/close-without-pod';
  static String tripShare(String id) => '/trips/$id/share';
  static const String tripsSearch = '/trips/search';
  static const String tripsActive = '/trips/active';
  static const String tripsPendingPOD = '/trips/pending-pod';
  static const String tripsCustomerAvailable = '/trips/customer/available';
  static String tripAccept(String id) => '/trips/$id/accept';
  static String tripReject(String id) => '/trips/$id/reject';
  static String tripAssignVehicle(String id) => '/trips/$id/assign-vehicle';
  static String tripAssignDriver(String id) => '/trips/$id/assign-driver';
  static String tripsByStatus(String status) => '/trips/status/$status';
  static String sharedTrip(String token) => '/trips/shared/$token';
  
  // Fuel Card endpoints
  static const String fuelCards = '/fuel-cards';
  static String fuelCardById(String id) => '/fuel-cards/$id';
  static String fuelCardAssign(String id) => '/fuel-cards/$id/assign';
  static const String fuelCardAssigned = '/fuel-cards/assigned';
  static String fuelCardTransactions(String id) => '/fuel-cards/$id/transactions';
  
  // Fuel Transaction endpoints
  static const String fuelGenerateQR = '/fuel/generate-qr';
  static const String fuelValidateQR = '/fuel/validate-qr';
  static const String fuelScanQR = '/fuel/scan-qr';
  static const String fuelConfirm = '/fuel/confirm';
  static const String fuelCancel = '/fuel/cancel';
  static const String fuelSubmit = '/fuel/submit';
  static const String fuelTransactions = '/fuel/transactions';
  static String fuelTransactionById(String id) => '/fuel/transactions/$id';
  static String fuelTransactionReceipt(String id) => '/fuel/transactions/$id/receipt';
  static String fuelReceipt(String id) => '/fuel/receipt/$id';
  
  // Company User endpoints
  static const String companyUsers = '/company-users';
  static String companyUserById(String id) => '/company-users/$id';
  static String companyUserSetPin(String id) => '/company-users/$id/set-pin';
  static String companyUserToggleAccess(String id) => '/company-users/$id/toggle-access';
  
  // Notification endpoints
  static const String notifications = '/notifications';
  static String notificationMarkRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';

  // Wallet endpoints
  static const String walletBalance = '/wallets/balance';
  static const String walletAddMoney = '/wallets/add-money';
  static const String walletTransactions = '/wallets/transactions';
  static const String walletTransfer = '/wallets/transfer';
  static const String walletBanks = '/wallets/banks';
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Origin for Socket.IO (scheme + host + port), no trailing slash.
  static String get effectiveSocketBaseUrl {
    final o = socketBaseUrlOverride.trim();
    if (o.isNotEmpty) {
      return o.replaceAll(RegExp(r'/+$'), '');
    }
    return baseUrl.replaceAll('/api', '').replaceAll(RegExp(r'/+$'), '');
  }
}

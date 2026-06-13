import 'package:flutter/material.dart';

/// Support ticket category codes — keep in sync with Porttivo-API constants.
enum SupportTicketCategory {
  appIssue('APP_ISSUE', 'App Related Issue'),
  tripIssue('TRIP_ISSUE', 'Trip Related Issue'),
  paymentIssue('PAYMENT_ISSUE', 'Payment Related Issue'),
  vehicleIssue('VEHICLE_ISSUE', 'Vehicle Related Issue'),
  otherIssue('OTHER_ISSUE', 'Other Issue'),
  complaintDriver('COMPLAINT_DRIVER', 'Driver Complaints'),
  complaintTransporter('COMPLAINT_TRANSPORTER', 'Transporter Complaints'),
  complaintCustomer('COMPLAINT_CUSTOMER', 'Customer Complaints');

  const SupportTicketCategory(this.code, this.label);

  final String code;
  final String label;

  bool get isComplaint =>
      this == complaintDriver ||
      this == complaintTransporter ||
      this == complaintCustomer;

  bool get requiresDetail => this == otherIssue;

  Color get badgeColor {
    switch (this) {
      case SupportTicketCategory.appIssue:
        return const Color(0xFF2563EB);
      case SupportTicketCategory.tripIssue:
        return const Color(0xFF0D9488);
      case SupportTicketCategory.paymentIssue:
        return const Color(0xFFD97706);
      case SupportTicketCategory.vehicleIssue:
        return const Color(0xFF7C3AED);
      case SupportTicketCategory.otherIssue:
        return const Color(0xFF6B7280);
      case SupportTicketCategory.complaintDriver:
      case SupportTicketCategory.complaintTransporter:
      case SupportTicketCategory.complaintCustomer:
        return const Color(0xFFE11D48);
    }
  }

  static SupportTicketCategory? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final c in SupportTicketCategory.values) {
      if (c.code == code) return c;
    }
    return null;
  }

  static String labelForCode(String? code) {
    final c = fromCode(code);
    if (c != null) return c.label;
    if (code == null || code.isEmpty) return 'Uncategorized';
    return code;
  }

  static Color colorForCode(String? code) {
    final c = fromCode(code);
    if (c != null) return c.badgeColor;
    return const Color(0xFF9CA3AF);
  }

  static const List<SupportTicketCategory> topLevelIssues = [
    appIssue,
    tripIssue,
    paymentIssue,
    vehicleIssue,
    otherIssue,
  ];

  static const List<SupportTicketCategory> complaintTypes = [
    complaintDriver,
    complaintTransporter,
    complaintCustomer,
  ];
}

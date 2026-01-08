import 'package:flutter/material.dart';

/// Centralized color tokens for the logistics platform theme system.
/// 
/// This class provides all color constants used across User App, Driver App,
/// and Transporter App. Colors are defined as static const properties to
/// ensure consistency and enable tree-shaking.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary Colors
  static const Color primary = Color(0xFF000000); // Black
  static const Color background = Color(0xFFFFFFFF); // White
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color card = Color(0xFFFFFFFF); // White

  // Neutral Colors
  static const Color offWhite = Color(0xFFF7F7F7);
  static const Color dividerGrey = Color(0xFFE5E5E5);

  // Text Colors
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF9E9E9E);

  // State Colors
  static const Color success = Color(0xFF1DB954);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2563EB);
}


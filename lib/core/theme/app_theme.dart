import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized theme configuration for the logistics platform.
/// 
/// Provides a minimalist, high-contrast theme with black primary color
/// and white background following Material 3 design guidelines.
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // Border radius constants
  static const double _borderRadiusSmall = 12.0;
  static const double _borderRadiusMedium = 16.0;

  /// Returns the light theme configuration for the app.
  /// 
  /// This theme uses Material 3 design tokens with a minimalist
  /// black-and-white color scheme optimized for high contrast and
  /// accessibility.
  static ThemeData lightTheme() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.background,
      background: AppColors.background,
      onBackground: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceVariant: AppColors.offWhite,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.error,
      onError: AppColors.background,
      outline: AppColors.dividerGrey,
      outlineVariant: AppColors.dividerGrey,
      shadow: AppColors.primary,
      scrim: AppColors.primary,
      inverseSurface: AppColors.primary,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: AppColors.primary,
          size: 24.0,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.primary,
          size: 24.0,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(_borderRadiusMedium),
            bottomRight: Radius.circular(_borderRadiusMedium),
          ),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 57.0,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          height: 1.12,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 45.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.0,
          height: 1.16,
        ),
        displaySmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 36.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.0,
          height: 1.22,
        ),
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.0,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.0,
          height: 1.29,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.0,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.0,
          height: 1.27,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          height: 1.43,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          height: 1.33,
        ),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        labelMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.33,
        ),
        labelSmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.45,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 12.0,
          ),
          textStyle: const TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.offWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 16.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
        helperStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(_borderRadiusMedium),
            topRight: Radius.circular(_borderRadiusMedium),
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerGrey,
        thickness: 1.0,
        space: 1.0,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
        ),
        margin: const EdgeInsets.all(8.0),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        elevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24.0,
      ),

      // Primary Icon Theme
      primaryIconTheme: const IconThemeData(
        color: AppColors.primary,
        size: 24.0,
      ),
    );
  }
}


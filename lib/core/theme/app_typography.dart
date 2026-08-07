import 'package:flutter/material.dart';

/// Builds the app's [TextTheme] on top of the platform default font
/// (San Francisco on iOS, Roboto on Android) with tighter tracking and a
/// clearer weight hierarchy than Material's defaults — closer to the
/// dense, confident type scale of premium fintech products.
TextTheme buildAppTextTheme(Color primaryColor, Color secondaryColor) {
  return TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: primaryColor,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: primaryColor,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: primaryColor,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: primaryColor,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: primaryColor,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: primaryColor,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: primaryColor,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: primaryColor,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: primaryColor,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: secondaryColor,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: primaryColor,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: secondaryColor,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: secondaryColor,
    ),
  );
}

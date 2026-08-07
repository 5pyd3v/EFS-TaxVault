import 'package:flutter/material.dart';

/// Builds the app's [TextTheme] on top of the platform default font
/// (San Francisco on iOS, Roboto on Android). Sizes run smaller/denser
/// than Material defaults — a fintech ledger reads a lot of numbers per
/// screen — while weight stays high (titleSmall, used for row titles and
/// money figures throughout, is bold) so data still reads as prominent
/// rather than small-and-quiet.
TextTheme buildAppTextTheme(Color primaryColor, Color secondaryColor) {
  return TextTheme(
    displaySmall: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: primaryColor,
    ),
    headlineLarge: TextStyle(
      fontSize: 24,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: primaryColor,
    ),
    headlineMedium: TextStyle(
      fontSize: 21,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: primaryColor,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: primaryColor,
    ),
    titleLarge: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: primaryColor,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: primaryColor,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: primaryColor,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: primaryColor,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: primaryColor,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: secondaryColor,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: primaryColor,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: secondaryColor,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: secondaryColor,
    ),
  );
}

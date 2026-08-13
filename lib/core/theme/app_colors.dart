import 'package:flutter/material.dart';

/// Raw brand palette. Prefer `Theme.of(context).colorScheme` and
/// `Theme.of(context).extension<AppSemanticColors>()` in widgets — this
/// class exists to define those, not to be referenced directly outside
/// `core/theme`.
abstract final class AppColors {
  // Brand — a confident, restrained blue. Purple/indigo gradients read as
  // generic "AI app" template at this point; blue plus a varied categorical
  // chip palette (see AppChipColors below) reads as an intentional product
  // instead of a single mood color painted over everything.
  static const Color brand = Color(0xFF1D5FE0);
  static const Color brandLight = Color(0xFF3D7DFA);
  static const Color brandDark = Color(0xFF13389B);

  // Light surfaces
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF1F3F6);
  static const Color lightBorder = Color(0xFFE4E7EC);
  static const Color lightTextPrimary = Color(0xFF101828);
  static const Color lightTextSecondary = Color(0xFF475467);
  static const Color lightTextTertiary = Color(0xFF98A2B3);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF0B0E14);
  static const Color darkSurface = Color(0xFF12151C);
  static const Color darkSurfaceMuted = Color(0xFF171B24);
  static const Color darkBorder = Color(0xFF262B38);
  static const Color darkTextPrimary = Color(0xFFF2F4F7);
  static const Color darkTextSecondary = Color(0xFF9AA1B1);
  static const Color darkTextTertiary = Color(0xFF667085);

  // Semantic — status/tax intelligence signals
  static const Color success = Color(0xFF16A34A);
  static const Color successContainerLight = Color(0xFFDCFCE7);
  static const Color successContainerDark = Color(0xFF14311F);

  static const Color warning = Color(0xFFD97706);
  static const Color warningContainerLight = Color(0xFFFEF3C7);
  static const Color warningContainerDark = Color(0xFF3A2A0E);

  static const Color info = Color(0xFF2563EB);
  static const Color infoContainerLight = Color(0xFFDBEAFE);
  static const Color infoContainerDark = Color(0xFF162745);

  static const Color error = Color(0xFFDC2626);
  static const Color errorContainerLight = Color(0xFFFEE2E2);
  static const Color errorContainerDark = Color(0xFF3B1616);

  // Categorical chip colors — assigned deterministically per supplier/
  // document type (see AppChipColors.forKey) so list rows read like a real
  // fintech ledger (Ramp/Brex-style merchant icon variety) instead of every
  // row using the same brand tint.
  static const Color chipTeal = Color(0xFF0F9D8C);
  static const Color chipTealContainerLight = Color(0xFFDBF3EF);
  static const Color chipTealContainerDark = Color(0xFF0E2E29);

  static const Color chipCoral = Color(0xFFE0603D);
  static const Color chipCoralContainerLight = Color(0xFFFCE4DC);
  static const Color chipCoralContainerDark = Color(0xFF3A1D13);

  static const Color chipGreen = Color(0xFF15803D);
  static const Color chipGreenContainerLight = Color(0xFFDCFCE7);
  static const Color chipGreenContainerDark = Color(0xFF14301F);

  static const Color chipAmber = Color(0xFFB45309);
  static const Color chipAmberContainerLight = Color(0xFFFEF0D8);
  static const Color chipAmberContainerDark = Color(0xFF34230A);

  static const Color chipPurple = Color(0xFF7C3AED);
  static const Color chipPurpleContainerLight = Color(0xFFEDE4FD);
  static const Color chipPurpleContainerDark = Color(0xFF241F52);
}

class ChipPalette {
  const ChipPalette(this.foreground, this.container);
  final Color foreground;
  final Color container;
}

/// Deterministic supplier/category → color mapping. Same key always maps
/// to the same chip color within a session, without needing to persist a
/// color choice anywhere.
abstract final class AppChipColors {
  static const _palette = [
    (
      AppColors.chipTeal,
      AppColors.chipTealContainerLight,
      AppColors.chipTealContainerDark,
    ),
    (
      AppColors.chipCoral,
      AppColors.chipCoralContainerLight,
      AppColors.chipCoralContainerDark,
    ),
    (
      AppColors.chipGreen,
      AppColors.chipGreenContainerLight,
      AppColors.chipGreenContainerDark,
    ),
    (
      AppColors.chipAmber,
      AppColors.chipAmberContainerLight,
      AppColors.chipAmberContainerDark,
    ),
    (
      AppColors.chipPurple,
      AppColors.chipPurpleContainerLight,
      AppColors.chipPurpleContainerDark,
    ),
  ];

  static ChipPalette forKey(String key, {required bool isDark}) {
    final index = key.isEmpty
        ? 0
        : key.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length;
    final (fg, lightContainer, darkContainer) = _palette[index];
    return ChipPalette(fg, isDark ? darkContainer : lightContainer);
  }
}

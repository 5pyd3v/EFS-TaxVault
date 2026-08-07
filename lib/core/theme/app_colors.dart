import 'package:flutter/material.dart';

/// Raw brand palette. Prefer `Theme.of(context).colorScheme` and
/// `Theme.of(context).extension<AppSemanticColors>()` in widgets — this
/// class exists to define those, not to be referenced directly outside
/// `core/theme`.
abstract final class AppColors {
  // Brand — deep indigo, chosen over the more clichéd finance-green to read
  // as software/security-forward rather than generic "money app".
  static const Color brand = Color(0xFF4338CA);
  static const Color brandLight = Color(0xFF6D5CE8);
  static const Color brandDark = Color(0xFF312A9E);

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
}

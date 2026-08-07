import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/theme/app_colors.dart';

/// Status colors Material's [ColorScheme] doesn't model on its own
/// (success/warning/info), used across verification badges, tax-intelligence
/// warnings, and FBR submission states.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;

  static const light = AppSemanticColors(
    success: AppColors.success,
    successContainer: AppColors.successContainerLight,
    warning: AppColors.warning,
    warningContainer: AppColors.warningContainerLight,
    info: AppColors.info,
    infoContainer: AppColors.infoContainerLight,
  );

  static const dark = AppSemanticColors(
    success: AppColors.success,
    successContainer: AppColors.successContainerDark,
    warning: AppColors.warning,
    warningContainer: AppColors.warningContainerDark,
    info: AppColors.info,
    infoContainer: AppColors.infoContainerDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/theme/app_colors.dart';

/// A rounded-square colored icon container — the merchant/category glyph
/// used in list rows and stat tiles. Color is either fixed (semantic, e.g.
/// warning) or derived deterministically from [colorKey] so the same
/// supplier always gets the same color without persisting anything.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.colorKey,
    this.color,
    this.size = 34,
  });

  final IconData icon;
  final String? colorKey;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = colorKey != null
        ? AppChipColors.forKey(colorKey!, isDark: isDark)
        : ChipPalette(
            color ?? Theme.of(context).colorScheme.primary,
            (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: isDark ? 0.22 : 0.12),
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.container,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: palette.foreground, size: size * 0.46),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';

/// A bento-grid metric tile. Pass [gradient] for a bold filled card (white
/// text/icon) — used for the dashboard's stat grid so it reads as colorful
/// rather than a wall of bordered boxes. Omit it for a quieter bordered
/// variant (Reports, denser lists).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.caption,
    this.iconColor,
    this.gradient,
    this.glowColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final Color? iconColor;
  final String? caption;
  final Gradient? gradient;

  /// Tints the tile's shadow to match [gradient] — casts a soft colored
  /// glow under filled tiles instead of a flat drop shadow.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filled = gradient != null;
    final onFill = Colors.white;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: filled ? null : theme.colorScheme.surface,
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (filled && glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: isDark ? 0.35 : 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            )
          else
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : const Color(0xFF16213E).withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            filled
                ? Icon(icon, color: onFill, size: 18)
                : IconChip(icon: icon!, color: iconColor, size: 28),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: filled ? onFill : valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: filled
                  ? onFill.withValues(alpha: 0.85)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: filled
                    ? onFill.withValues(alpha: 0.85)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

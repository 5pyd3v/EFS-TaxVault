import 'package:flutter/material.dart';

/// The app's one card primitive — soft ambient shadow instead of a hairline
/// border, so surfaces read as lifted off the background (Cash App/Revolut
/// style) rather than outlined boxes. Used everywhere a list row, summary,
/// or grouped section needs a "card" — Vault rows, Reports rows, Dashboard
/// tiles, Profile groups, the FBR card.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF16213E).withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF16213E).withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    // AppCard is the list-row primitive used throughout Vault/Reports/
    // Dashboard — its blurred shadow is the most expensive part to
    // rasterize, so it gets its own compositor layer. During a scroll,
    // Flutter can then reuse each card's cached layer instead of
    // re-rasterizing the shadow blur on every frame.
    final boundedCard = RepaintBoundary(child: card);

    if (onTap == null) return boundedCard;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: boundedCard,
      ),
    );
  }
}

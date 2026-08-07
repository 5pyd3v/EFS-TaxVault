import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/theme/app_gradients.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';

class HeroMetricStat {
  const HeroMetricStat({required this.label, required this.value});
  final String label;
  final String value;
}

/// The dashboard's headline number — a bold blue-teal gradient (never
/// purple, see AppGradients) so it reads as colorful and alive rather than
/// a flat bordered box.
class HeroMetricCard extends StatelessWidget {
  const HeroMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.stats = const [],
    this.gradient = AppGradients.blue,
  });

  final String label;
  final String value;
  final List<HeroMetricStat> stats;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                for (final stat in stats) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.value,
                        style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  if (stat != stats.last) const SizedBox(width: AppSpacing.xxl),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

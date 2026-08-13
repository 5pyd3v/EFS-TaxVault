import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';

/// Placeholder rows shown while a list loads — reads as "content is on its
/// way" rather than a bare spinner. Static blocks, not an animated
/// shimmer, matching the rest of the app's flat, no-extra-dependency style.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rowCount = 6, this.rowHeight = 88});

  final int rowCount;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rowCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => Container(
        height: rowHeight,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

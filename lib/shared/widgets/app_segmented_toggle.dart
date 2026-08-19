import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/theme/app_colors.dart';

class AppToggleSegment<T> {
  const AppToggleSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A rounded pill toggle with a solid-fill active segment — the primary,
/// most prominent choice on a screen (e.g. which dataset to show). Solid
/// brand color rather than a gradient: a two-hue gradient squeezed into a
/// small pill reads busy/dated, where a single solid fill reads clean and
/// deliberate — gradients are reserved for large surfaces (hero cards,
/// stat tiles) elsewhere in the app. Pair with [AppTabToggle] for a
/// secondary choice nested under this one, so the two read as a clear
/// hierarchy instead of two competing bars.
class AppSegmentedToggle<T> extends StatelessWidget {
  const AppSegmentedToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppToggleSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.lightSurfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _PillSegment<T>(
                segment: segment,
                isSelected: segment.value == selected,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillSegment<T> extends StatelessWidget {
  const _PillSegment({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final AppToggleSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (segment.icon != null) ...[
              Icon(
                segment.icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                segment.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet underline-tab toggle for a secondary choice nested under an
/// [AppSegmentedToggle] (e.g. how to group the selected dataset) — no
/// filled background at rest or when selected, just a colored underline
/// and label weight/color change, so it visibly reads as "lighter" than
/// the pill control above it rather than a second competing bar.
class AppTabToggle<T> extends StatelessWidget {
  const AppTabToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppToggleSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final segment in segments)
          Padding(
            padding: const EdgeInsets.only(right: AppTabToggle._gap),
            child: _TabSegment<T>(
              segment: segment,
              isSelected: segment.value == selected,
              onTap: () => onChanged(segment.value),
            ),
          ),
      ],
    );
  }

  static const _gap = 4.0;
}

class _TabSegment<T> extends StatelessWidget {
  const _TabSegment({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final AppToggleSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (segment.icon != null) ...[
              Icon(
                segment.icon,
                size: 15,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              segment.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

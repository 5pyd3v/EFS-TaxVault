import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/theme/app_gradients.dart';

/// Floating, pill-shaped bottom nav — inset from the edges with a soft
/// shadow, and a raised gradient Scan button breaking the top edge, rather
/// than a flush stock Material bar. Reads as a considered fintech product
/// (Cash App/Revolut/Mercury-style) instead of an off-the-shelf shell.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: SizedBox(
        height: 80,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            RepaintBoundary(
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.5)
                          : const Color(0xFF16213E).withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                      index: 0,
                      currentIndex: currentIndex,
                      onSelect: onSelect,
                    ),
                    _NavItem(
                      icon: Icons.folder_outlined,
                      selectedIcon: Icons.folder_rounded,
                      label: 'Vault',
                      index: 1,
                      currentIndex: currentIndex,
                      onSelect: onSelect,
                    ),
                    const Expanded(child: SizedBox()),
                    _NavItem(
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      index: 3,
                      currentIndex: currentIndex,
                      onSelect: onSelect,
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      label: 'Profile',
                      index: 4,
                      currentIndex: currentIndex,
                      onSelect: onSelect,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(top: 0, child: _ScanButton(onTap: () => onSelect(2))),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onSelect,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = index == currentIndex;
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => onSelect(index),
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppGradients.blue,
          shape: BoxShape.circle,
          border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF2E7CF6,
              ).withValues(alpha: isDark ? 0.55 : 0.4),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
          ],
        ),
        child: const Icon(
          Icons.document_scanner_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_gradients.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';
import 'package:fbr_taxvault/features/dashboard/presentation/dashboard_providers.dart';
import 'package:fbr_taxvault/features/notifications/presentation/notifications_providers.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';
import 'package:fbr_taxvault/shared/widgets/section_header.dart';
import 'package:fbr_taxvault/shared/widgets/sparkline_chart.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 0,
);
final _dateFormat = DateFormat('d MMM');

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      _Avatar(name: user?.displayName),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.displayName ?? '',
                              style: theme.textTheme.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const _NotificationBell(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: AsyncValueView<DashboardSummary>(
                    value: summaryAsync,
                    onRetry: () => ref.invalidate(dashboardSummaryProvider),
                    loading: (_) => const _DashboardSkeleton(),
                    data: (summary) => _DashboardContent(summary: summary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name?.trim() ?? '';
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AppGradients.blue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7CF6).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlyTaxTrendProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CurvedHeroCard(
              summary: summary,
              trend: trendAsync.valueOrNull ?? const [],
            ),
            Positioned(
              left: AppSpacing.xxl,
              right: AppSpacing.xxl,
              bottom: -32,
              child: const _QuickActionsBar(),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InsightsCard(summary: summary),
              const SizedBox(height: AppSpacing.xxxl),
              SectionHeader(
                title: 'Recent invoices',
                actionLabel: summary.totalInvoices == 0 ? null : 'See all',
                onAction: summary.totalInvoices == 0
                    ? null
                    : () => context.go(AppRoutes.vault),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (summary.totalInvoices == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No invoices yet',
                    message:
                        'Scan your first invoice and TaxVault will organize the rest.',
                  ),
                )
              else
                const _RecentInvoicesList(),
              const SizedBox(height: AppSpacing.giant),
            ],
          ),
        ),
      ],
    );
  }
}

/// The dashboard's headline — an organic wave-bottom silhouette instead of a
/// plain rounded rectangle, carrying the month's tax number, a
/// month-over-month trend badge, and a 6-month sparkline. This is the one
/// shape in the app that isn't just a rounded box, on purpose.
class _CurvedHeroCard extends StatelessWidget {
  const _CurvedHeroCard({required this.summary, required this.trend});

  final DashboardSummary summary;
  final List<PeriodSummary> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = trend.map((e) => e.taxTotal).toList();

    double? changePct;
    if (values.length >= 2 && values[values.length - 2] > 0) {
      final previous = values[values.length - 2];
      changePct = ((values.last - previous) / previous) * 100;
    }

    return RepaintBoundary(
      child: ClipPath(
        clipper: const _WaveBottomClipper(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.giant,
          ),
          decoration: const BoxDecoration(gradient: AppGradients.blue),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tax exposure this month',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _currencyFormat.format(summary.currentMonthTaxAmount),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (changePct != null) ...[
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _TrendBadge(changePct: changePct),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xxl),
                child: SparklineChart(
                  values: values,
                  lineColor: Colors.white,
                  height: 44,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.changePct});

  final double changePct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = changePct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            '${changePct.abs().toStringAsFixed(0)}%',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WaveBottomClipper extends CustomClipper<Path> {
  const _WaveBottomClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 36)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 14,
        size.width,
        size.height - 36,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Floats over the hero's bottom edge — a considered layering trick (Cash
/// App/Revolut do this with their primary shortcuts) rather than a single
/// full-width CTA button.
class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.document_scanner_rounded,
              label: 'Scan',
              emphasized: true,
              onTap: () => context.go(AppRoutes.scan),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.folder_rounded,
              label: 'Vault',
              onTap: () => context.go(AppRoutes.vault),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              onTap: () => context.go(AppRoutes.reports),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: emphasized ? AppGradients.blue : null,
                color: emphasized
                    ? null
                    : theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                boxShadow: emphasized
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF2E7CF6,
                          ).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: emphasized ? Colors.white : theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the old two-square-tile layout with one card, two tappable
/// rows — denser, more like a real "things that need you" list than a
/// wall of boxes.
class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InsightRow(
            icon: Icons.fact_check_outlined,
            iconColor: summary.pendingVerification > 0
                ? semantic.warning
                : theme.colorScheme.onSurfaceVariant,
            label: 'Pending verification',
            count: summary.pendingVerification,
            onTap: () => context.go(AppRoutes.vault),
          ),
          Divider(
            height: 1,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
            color: theme.colorScheme.outline,
          ),
          _InsightRow(
            icon: Icons.error_outline_rounded,
            iconColor: summary.potentialIssues > 0
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            label: 'Potential issues',
            count: summary.potentialIssues,
            onTap: () => context.go(AppRoutes.vault),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            IconChip(icon: icon, color: iconColor, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              '$count',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: count > 0
                    ? iconColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentInvoicesList extends ConsumerWidget {
  const _RecentInvoicesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentInvoicesProvider);
    final theme = Theme.of(context);

    return AsyncValueView<List<InvoiceSummary>>(
      value: recentAsync,
      loading: (_) => const SizedBox.shrink(),
      data: (invoices) => Column(
        children: [
          for (final invoice in invoices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => context.push(AppRoutes.invoiceReview(invoice.id)),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    IconChip(
                      icon: Icons.storefront_outlined,
                      colorKey: invoice.supplierName,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.supplierName,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _relativeLabel(invoice.invoiceDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat.format(invoice.totalAmount),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _relativeLabel(DateTime? date) {
    if (date == null) return 'Undated';
    final today = DateTime.now();
    final diff = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return '$diff days ago';
    return _dateFormat.format(date);
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: AppSpacing.giant),
          Container(
            height: 108,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadAsync = ref.watch(unreadNotificationsCountProvider);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => context.push(AppRoutes.notifications),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16213E).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onError,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

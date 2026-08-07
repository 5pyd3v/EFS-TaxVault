import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_gradients.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';
import 'package:fbr_taxvault/features/dashboard/presentation/dashboard_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/hero_metric_card.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';
import 'package:fbr_taxvault/shared/widgets/section_header.dart';
import 'package:fbr_taxvault/shared/widgets/stat_tile.dart';

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                          ),
                        ],
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Icon(
                          Icons.notifications_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
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

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final filedRate = summary.totalInvoices == 0
        ? 0
        : (((summary.totalInvoices - summary.pendingVerification) /
                      summary.totalInvoices) *
                  100)
              .round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroMetricCard(
          label: 'Tax exposure this month',
          value: _currencyFormat.format(summary.currentMonthTaxAmount),
          stats: [
            HeroMetricStat(
              label: 'Invoices',
              value: '${summary.totalInvoices}',
            ),
            HeroMetricStat(
              label: 'This month',
              value: '${summary.currentMonthInvoices}',
            ),
            HeroMetricStat(label: 'Filed', value: '$filedRate%'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go(AppRoutes.scan),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan invoice'),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Pending verification',
                value: '${summary.pendingVerification}',
                icon: Icons.fact_check_outlined,
                gradient: AppGradients.amber,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Potential issues',
                value: '${summary.potentialIssues}',
                icon: Icons.error_outline_rounded,
                gradient: AppGradients.coral,
              ),
            ),
          ],
        ),
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
      ],
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
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(AppRoutes.invoiceReview(invoice.id)),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                              invoice.invoiceDate != null
                                  ? _dateFormat.format(invoice.invoiceDate!)
                                  : 'Undated',
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
            ),
        ],
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 168,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
